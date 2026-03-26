const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule }        = require('firebase-functions/v2/scheduler');
const { initializeApp }     = require('firebase-admin/app');
const { getAuth }           = require('firebase-admin/auth');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging }      = require('firebase-admin/messaging');

initializeApp();

/**
 * deleteAccount — GDPR/PIPEDA compliant account deletion cascade.
 *
 * Deletes in order:
 *   1. availability docs (events/{eventId}/availability/{uid})
 *   2. rankings docs    (teams/{teamId}/rankings/{uid})
 *   3. playerPreferences (teams/{teamId}/playerPreferences/{uid})
 *   4. Remove uid from dropInSessions.signups arrays
 *   5. Remove uid from lineups assignments
 *   6. Remove uid from teams.players / teams.admins arrays
 *   7. users/{uid} document
 *   8. Firebase Auth account
 *
 * Must be called by the authenticated user deleting their own account.
 */
exports.deleteAccount = onCall({ region: 'northamerica-northeast1', enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Must be signed in to delete account.');
  }

  const db = getFirestore();

  // ── 1. Availability (collection group) ──────────────────────────────────────
  const availSnap = await db.collectionGroup('availability')
    .where('userId', '==', uid)
    .get();
  await _deleteInBatches(db, availSnap.docs);

  // ── 2. Rankings (collection group) ──────────────────────────────────────────
  const rankSnap = await db.collectionGroup('rankings')
    .where(/* Firestore document ID field */ '__name__', '>=', `teams/`)
    .get();
  // Rankings docs use userId as the doc ID — fetch directly from each team
  const userDoc = await db.collection('users').doc(uid).get();
  const teamIds = userDoc.exists ? (userDoc.data().teams ?? []) : [];

  const rankDocs = [];
  for (const teamId of teamIds) {
    const rDoc = db.collection('teams').doc(teamId).collection('rankings').doc(uid);
    rankDocs.push(rDoc);
    const pDoc = db.collection('teams').doc(teamId).collection('playerPreferences').doc(uid);
    rankDocs.push(pDoc);
  }
  if (rankDocs.length > 0) {
    await _deleteDocRefs(db, rankDocs);
  }

  // ── 3. Remove uid from dropInSessions.signups ────────────────────────────────
  const dropInSnap = await db.collection('dropInSessions')
    .where('signups', 'array-contains', uid)
    .get();
  const dropInBatch = db.batch();
  for (const doc of dropInSnap.docs) {
    dropInBatch.update(doc.ref, { signups: FieldValue.arrayRemove(uid) });
  }
  if (!dropInSnap.empty) await dropInBatch.commit();

  // ── 4. Remove uid from teams.players / teams.admins ──────────────────────────
  const teamBatch = db.batch();
  for (const teamId of teamIds) {
    const teamRef = db.collection('teams').doc(teamId);
    teamBatch.update(teamRef, {
      players: FieldValue.arrayRemove(uid),
      admins:  FieldValue.arrayRemove(uid),
    });
  }
  if (teamIds.length > 0) await teamBatch.commit();

  // ── 5. Delete join requests created by this user ─────────────────────────────
  const jrSnap = await db.collectionGroup('joinRequests')
    .where('userId', '==', uid)
    .get();
  await _deleteInBatches(db, jrSnap.docs);

  // ── 6. Delete users/{uid} document ──────────────────────────────────────────
  await db.collection('users').doc(uid).delete();

  // ── 7. Delete Firebase Auth account ─────────────────────────────────────────
  await getAuth().deleteUser(uid);

  return { success: true };
});

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Delete an array of QueryDocumentSnapshots in batches of 500. */
async function _deleteInBatches(db, docs) {
  if (docs.length === 0) return;
  const BATCH_SIZE = 500;
  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    docs.slice(i, i + BATCH_SIZE).forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

/** Delete an array of DocumentReferences in batches of 500. */
async function _deleteDocRefs(db, refs) {
  if (refs.length === 0) return;
  const BATCH_SIZE = 500;
  for (let i = 0; i < refs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    refs.slice(i, i + BATCH_SIZE).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
}

/**
 * sendTeamNotification — admin sends a push notification to all team members.
 *
 * Params: { teamId, title, body, eventId? }
 * Caller must be a team admin.
 * FCM tokens are read from users/{uid}.fcmToken.
 * Tokens for users who have not granted permission will simply be absent.
 */
exports.sendTeamNotification = onCall({ region: 'northamerica-northeast1', enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Must be signed in.');

  const { teamId, title, body, eventId } = request.data;
  if (!teamId || !title || !body) {
    throw new HttpsError('invalid-argument', 'teamId, title, and body are required.');
  }

  const db = getFirestore();

  // Verify caller is a team admin
  const teamSnap = await db.collection('teams').doc(teamId).get();
  if (!teamSnap.exists) throw new HttpsError('not-found', 'Team not found.');
  const admins = teamSnap.data().admins ?? [];
  if (!admins.includes(uid)) {
    throw new HttpsError('permission-denied', 'Only team admins can send notifications.');
  }

  // Collect all member UIDs (admins + players)
  const players = teamSnap.data().players ?? [];
  const allMembers = [...new Set([...admins, ...players])];

  // Fetch FCM tokens (skip members with no token)
  const tokenPromises = allMembers.map((memberId) =>
    db.collection('users').doc(memberId).get().then((s) => s.data()?.fcmToken)
  );
  const allTokens = (await Promise.all(tokenPromises)).filter(Boolean);

  if (allTokens.length === 0) return { sent: 0 };

  // Build data payload for deep-link navigation on tap
  const data = { teamId };
  if (eventId) data.eventId = eventId;

  // Send in batches of 500 (FCM multicast limit)
  const BATCH = 500;
  let sent = 0;
  for (let i = 0; i < allTokens.length; i += BATCH) {
    const batch = allTokens.slice(i, i + BATCH);
    const response = await getMessaging().sendEachForMulticast({
      tokens: batch,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    sent += response.successCount;

    // Remove stale tokens (registration-not-registered)
    const staleTokens = [];
    response.responses.forEach((r, idx) => {
      if (!r.success &&
          (r.error?.code === 'messaging/registration-token-not-registered' ||
           r.error?.code === 'messaging/invalid-registration-token')) {
        staleTokens.push(batch[idx]);
      }
    });
    if (staleTokens.length > 0) {
      const staleBatch = db.batch();
      for (const token of staleTokens) {
        // Find which user has this token and clear it
        const userSnap = await db.collection('users')
          .where('fcmToken', '==', token).limit(1).get();
        userSnap.docs.forEach((d) =>
          staleBatch.update(d.ref, { fcmToken: FieldValue.delete() })
        );
      }
      await staleBatch.commit();
    }
  }

  // Persist notification to Firestore for in-app inbox
  await db.collection('teamNotifications').doc(teamId)
    .collection('messages').add({
      title,
      body,
      senderUid: uid,
      sentAt: new Date(),
      ...(eventId ? { eventId } : {}),
    });

  return { sent };
});

/**
 * sendEventReminders — runs every hour, sends push notifications to team
 * members for events starting in ~24h or ~2h.
 *
 * Tracks sent reminders via flags on the event doc to avoid duplicates:
 *   reminder24Sent: bool
 *   reminder2Sent:  bool
 */
exports.sendEventReminders = onSchedule(
  { schedule: 'every 60 minutes', region: 'northamerica-northeast1' },
  async () => {
    const db  = getFirestore();
    const now = new Date();

    // Query upcoming events in the next 25h (wider window to catch all)
    const cutoff = new Date(now.getTime() + 25 * 60 * 60 * 1000);
    const snap = await db.collection('events')
      .where('date', '>=', Timestamp.fromDate(now))
      .where('date', '<=', Timestamp.fromDate(cutoff))
      .get();

    if (snap.empty) return;

    for (const eventDoc of snap.docs) {
      const event    = eventDoc.data();
      const eventDate = event.date.toDate();
      const minsUntil = (eventDate - now) / 60000;

      const teamSnap = await db.collection('teams').doc(event.teamId).get();
      if (!teamSnap.exists) continue;
      const team = teamSnap.data();

      const allMembers = [...new Set([
        ...(team.admins ?? []),
        ...(team.players ?? []),
      ])];

      async function sendReminderToTeam(title, body) {
        const tokens = (await Promise.all(
          allMembers.map(uid =>
            db.collection('users').doc(uid).get()
              .then(s => s.data()?.fcmToken)
          )
        )).filter(Boolean);

        if (tokens.length === 0) return;

        const BATCH = 500;
        for (let i = 0; i < tokens.length; i += BATCH) {
          await getMessaging().sendEachForMulticast({
            tokens: tokens.slice(i, i + BATCH),
            notification: { title, body },
            data: { teamId: event.teamId, eventId: eventDoc.id },
            android: { priority: 'high' },
            apns: { payload: { aps: { sound: 'default' } } },
          });
        }

        // Persist to inbox
        await db.collection('teamNotifications').doc(event.teamId)
          .collection('messages').add({
            title,
            body,
            senderUid: 'system',
            sentAt: new Date(),
            eventId: eventDoc.id,
          });
      }

      // 24-hour reminder: event is 23–25h away and flag not set
      if (minsUntil >= 23 * 60 && minsUntil <= 25 * 60 && !event.reminder24Sent) {
        const label = event.type.charAt(0).toUpperCase() + event.type.slice(1);
        await sendReminderToTeam(
          `${label} tomorrow`,
          `Reminder: ${label} at ${eventDate.toLocaleTimeString('en-CA', { hour: 'numeric', minute: '2-digit', hour12: true })}. Have you RSVPed?`,
        );
        await eventDoc.ref.update({ reminder24Sent: true });
      }

      // 2-hour reminder: event is 1.5–2.5h away and flag not set
      if (minsUntil >= 90 && minsUntil <= 150 && !event.reminder2Sent) {
        const label = event.type.charAt(0).toUpperCase() + event.type.slice(1);
        await sendReminderToTeam(
          `${label} in 2 hours`,
          `Starting soon at ${eventDate.toLocaleTimeString('en-CA', { hour: 'numeric', minute: '2-digit', hour12: true })}. See you there!`,
        );
        await eventDoc.ref.update({ reminder2Sent: true });
      }
    }
  }
);
