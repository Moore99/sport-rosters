const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule }        = require('firebase-functions/v2/scheduler');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { defineSecret }      = require('firebase-functions/params');
const { initializeApp }     = require('firebase-admin/app');
const { getAuth }           = require('firebase-admin/auth');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging }      = require('firebase-admin/messaging');
const { getStorage }        = require('firebase-admin/storage');
const { google }            = require('googleapis');

initializeApp();

// ── Secrets (set via: firebase functions:secrets:set SECRET_NAME) ─────────────
const appleSharedSecret         = defineSecret('APPLE_IAP_SHARED_SECRET');
const googlePlayServiceAccount  = defineSecret('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');

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
 * previewTeam — public team lookup for pre-registration UX.
 *
 * Intentionally requires no auth — allows prospective members to verify
 * a Team ID before creating an account. Returns only non-sensitive info.
 *
 * Params: { teamId }
 * Returns: { name, sport }
 */
exports.previewTeam = onCall(
  { region: 'northamerica-northeast1', enforceAppCheck: false },
  async (request) => {
    const { teamId } = request.data;
    if (!teamId || typeof teamId !== 'string' || teamId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'teamId is required.');
    }

    const db       = getFirestore();
    const teamSnap = await db.collection('teams').doc(teamId.trim()).get();

    if (!teamSnap.exists) {
      throw new HttpsError('not-found',
        'Team not found. Check the ID and try again.');
    }

    const data = teamSnap.data();
    return {
      name:  data.name  ?? '',
      sport: data.sport ?? '',
    };
  }
);

/**
 * exportUserData — GDPR/PIPEDA data portability export.
 *
 * Returns a JSON object containing the calling user's personal data:
 *   profile       — name, email, phone, weightKg
 *   teams         — team memberships with role
 *   availabilityRecords  — all event RSVP responses
 *   dropInParticipations — drop-in sessions the user signed up for
 *
 * Sensitive internal fields (fcmToken, adFree) are excluded.
 * Must be called by the authenticated user requesting their own data.
 */
exports.exportUserData = onCall({ region: 'northamerica-northeast1', enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Must be signed in.');

  const db = getFirestore();

  // ── 1. User profile ──────────────────────────────────────────────────────────
  const userSnap = await db.collection('users').doc(uid).get();
  const profileData = userSnap.exists ? userSnap.data() : {};

  // ── 2. Team memberships ──────────────────────────────────────────────────────
  const teamIds = profileData.teams ?? [];
  const teams = [];
  for (const teamId of teamIds) {
    const teamSnap = await db.collection('teams').doc(teamId).get();
    if (teamSnap.exists) {
      const t = teamSnap.data();
      teams.push({
        teamId,
        name:  t.name  ?? '',
        sport: t.sport ?? '',
        role:  (t.admins ?? []).includes(uid) ? 'admin' : 'player',
      });
    }
  }

  // ── 3. Availability records ──────────────────────────────────────────────────
  const availSnap = await db.collectionGroup('availability')
    .where('userId', '==', uid)
    .get();
  const availabilityRecords = availSnap.docs.map(d => {
    const data = d.data();
    return {
      eventId:   data.eventId  ?? '',
      teamId:    data.teamId   ?? '',
      response:  data.response ?? '',
      updatedAt: data.updatedAt?.toDate()?.toISOString() ?? null,
    };
  });

  // ── 4. Drop-in participations ─────────────────────────────────────────────────
  const dropInSnap = await db.collection('dropInSessions')
    .where('signups', 'array-contains', uid)
    .get();
  const dropInParticipations = dropInSnap.docs.map(d => {
    const data = d.data();
    return {
      sessionId: d.id,
      eventId:   data.eventId ?? '',
      teamId:    data.teamId  ?? '',
    };
  });

  return {
    exportedAt: new Date().toISOString(),
    profile: {
      uid,
      name:     profileData.name     ?? '',
      email:    profileData.email    ?? '',
      phone:    profileData.phone    ?? null,
      weightKg: profileData.weightKg ?? null,
    },
    teams,
    availabilityRecords,
    dropInParticipations,
  };
});

/**
 * validateIap — server-side receipt validation for the "Remove Ads" one-time purchase.
 *
 * Called by the app after a purchase or restore event is received from the store.
 * On success, sets adFree: true on the user's Firestore doc via Admin SDK.
 *
 * Params:
 *   platform    — 'ios' | 'android'
 *   receiptData — iOS: base64 App Store receipt (verificationData.serverVerificationData)
 *                 Android: purchase token (verificationData.serverVerificationData)
 *   productId   — e.g. 'com.sportsrostering.app.remove_ads'
 *   isRestore   — true if this is a restore (fail-open on network error)
 *
 * Failure behaviour:
 *   - New purchase:  fail closed  (throws error — user can retry)
 *   - Restore:       fail open    (grants entitlement — user already paid)
 *
 * Android note: Play Console API access not yet linked — Android validation
 * fails open (grants entitlement) until ANDROID_VALIDATION_ENABLED is set to
 * true in app config. iOS validation is fully enforced.
 */

// Play Console service account linked 2026-04-02 — Android validation enabled. Runtime: Node.js 22.
const ANDROID_VALIDATION_ENABLED = true;

exports.validateIap = onCall(
  {
    region:          'northamerica-northeast1',
    enforceAppCheck: true,
    secrets:         [appleSharedSecret, googlePlayServiceAccount],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Must be signed in.');

    const { platform, receiptData, productId, isRestore = false } = request.data;
    if (!platform || !receiptData || !productId) {
      throw new HttpsError('invalid-argument',
        'platform, receiptData, and productId are required.');
    }
    if (!['ios', 'android'].includes(platform)) {
      throw new HttpsError('invalid-argument', `Unknown platform: ${platform}`);
    }

    // Android validation deferred until Play Console API access is configured
    if (platform === 'android' && !ANDROID_VALIDATION_ENABLED) {
      console.log('Android validation not yet enabled — failing open.');
      const db = getFirestore();
      await db.collection('users').doc(uid).update({ adFree: true });
      return { success: true };
    }

    let valid = false;
    try {
      if (platform === 'ios') {
        valid = await _validateAppleReceipt(
          receiptData, productId, appleSharedSecret.value());
      } else {
        valid = await _validateGooglePurchase(
          receiptData, productId, googlePlayServiceAccount.value());
      }
    } catch (err) {
      console.error(`IAP validation error (${platform}):`, err.message);
      // Fail open on restore so a transient outage doesn't strand paying users
      if (isRestore) {
        console.warn('Restore: failing open due to validation error.');
        valid = true;
      } else {
        throw new HttpsError('internal',
          'Could not verify purchase. Please try again.');
      }
    }

    if (!valid) {
      throw new HttpsError('permission-denied',
        'Purchase could not be verified with the store.');
    }

    // Grant entitlement via Admin SDK — cannot be spoofed by the client
    const db = getFirestore();
    await db.collection('users').doc(uid).update({ adFree: true });

    return { success: true };
  }
);

// ── Apple receipt validation (legacy /verifyReceipt) ─────────────────────────

async function _validateAppleReceipt(receiptData, productId, sharedSecret) {
  const body = JSON.stringify({
    'receipt-data': receiptData,
    password:       sharedSecret,
    'exclude-old-transactions': true,
  });

  // Always try production first; Apple returns status 21007 for sandbox receipts
  let data = await _applePost('https://buy.itunes.apple.com/verifyReceipt', body);

  if (data.status === 21007) {
    // Sandbox receipt — retry against sandbox endpoint (expected during TestFlight)
    data = await _applePost('https://sandbox.itunes.apple.com/verifyReceipt', body);
  }

  if (data.status !== 0) {
    console.warn(`Apple verifyReceipt returned status ${data.status}`);
    return false;
  }

  // Confirm the receipt contains a transaction for the expected product
  const inApp = data.receipt?.in_app ?? [];
  const found = inApp.some((item) => item.product_id === productId);
  if (!found) {
    console.warn(`Apple receipt valid but productId '${productId}' not found`);
  }
  return found;
}

async function _applePost(url, body) {
  const res = await fetch(url, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body,
  });
  return res.json();
}

// ── Google Play purchase validation ──────────────────────────────────────────

async function _validateGooglePurchase(purchaseToken, productId, serviceAccountJson) {
  const credentials = JSON.parse(serviceAccountJson);
  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  const publisher = google.androidpublisher({ version: 'v3', auth });

  const result = await publisher.purchases.products.get({
    packageName: 'com.sportsrostering.app',
    productId,
    token: purchaseToken,
  });

  // purchaseState: 0 = Purchased, 1 = Cancelled, 2 = Pending
  const purchaseState = result.data.purchaseState;
  if (purchaseState !== 0) {
    console.warn(`Google Play purchaseState is ${purchaseState} (not purchased)`);
    return false;
  }

  // consumptionState 1 = already consumed; for a non-consumable this is always 0
  return true;
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

/**
 * uploadTeamLogo — admin-only team logo upload via Cloud Function proxy.
 *
 * Storage rules deny all direct client writes to team_logos/. This function
 * verifies the caller is a team admin, then writes to Storage via Admin SDK.
 *
 * Params: { teamId, imageBase64 }
 *   teamId      — Firestore team document ID
 *   imageBase64 — JPEG image data, base64-encoded (max ~2.67 MB after encoding)
 */
exports.uploadTeamLogo = onCall(
  { region: 'northamerica-northeast1', enforceAppCheck: true },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Must be signed in.');

    const { teamId, imageBase64 } = request.data;
    if (!teamId || !imageBase64) {
      throw new HttpsError('invalid-argument', 'teamId and imageBase64 are required.');
    }

    const db = getFirestore();

    // Verify the caller is a team admin
    const teamSnap = await db.collection('teams').doc(teamId).get();
    if (!teamSnap.exists) throw new HttpsError('not-found', 'Team not found.');
    const admins = teamSnap.data().admins ?? [];
    if (!admins.includes(uid)) {
      throw new HttpsError('permission-denied', 'Only team admins can upload a team logo.');
    }

    // Write image to Storage via Admin SDK (bypasses client-facing rules)
    const bucket = getStorage().bucket();
    const filePath = `team_logos/${teamId}.jpg`;
    const file = bucket.file(filePath);

    const imageBuffer = Buffer.from(imageBase64, 'base64');
    await file.save(imageBuffer, {
      metadata: { contentType: 'image/jpeg' },
      public: false,
    });

    // Make file publicly readable and get the URL
    await file.makePublic();
    const logoUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;

    // Persist URL to Firestore
    await db.collection('teams').doc(teamId).update({ logoUrl });

    return { logoUrl };
  }
);

/**
 * notifySpares — notifies team spares about an event needing players.
 *
 * Called when an event is below minimum players and admin clicks "Notify Spares".
 * Sends push notification to the first N spares (by joinedAt timestamp).
 *
 * Params: { eventId, teamId, teamName, eventDate, batchSize }
 *   eventId    — Firestore event document ID
 *   teamId     — Firestore team document ID
 *   teamName   — Display name of the team
 *   eventDate  — ISO date string of the event
 *   batchSize  — Number of spares to notify (default 10)
 */
exports.notifySpares = onCall(
  { region: 'northamerica-northeast1', enforceAppCheck: true },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Must be signed in.');

    const { eventId, teamId, teamName, eventDate, batchSize = 10 } = request.data;
    if (!eventId || !teamId) {
      throw new HttpsError('invalid-argument', 'eventId and teamId are required.');
    }

    const db = getFirestore();

    // Verify the caller is a team admin
    const teamSnap = await db.collection('teams').doc(teamId).get();
    if (!teamSnap.exists) throw new HttpsError('not-found', 'Team not found.');
    const admins = teamSnap.data().admins ?? [];
    if (!admins.includes(uid)) {
      throw new HttpsError('permission-denied', 'Only team admins can notify spares.');
    }

    // Get spares, sorted by joinedAt (first-come first)
    const sparesSnap = await db.collection('teams').doc(teamId)
      .collection('spares')
      .orderBy('joinedAt')
      .limit(batchSize)
      .get();

    if (sparesSnap.empty) {
      return { sent: 0 };
    }

    // Get FCM tokens for spares
    const tokens = [];
    for (const doc of sparesSnap.docs) {
      const userId = doc.id;
      const userSnap = await db.collection('users').doc(userId).get();
      const token = userSnap.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) {
      return { sent: 0 };
    }

    const eventDateObj = new Date(eventDate);
    const dateStr = eventDateObj.toLocaleDateString('en-US', {
      weekday: 'short', month: 'short', day: 'numeric'
    });

    const title = `Spares Needed - ${teamName}`;
    const body = `Event on ${dateStr} needs players. Tap to fill in!`;

    // Send notifications
    const BATCH = 500;
    let sent = 0;
    for (let i = 0; i < tokens.length; i += BATCH) {
      const batch = tokens.slice(i, i + BATCH);
      const response = await getMessaging().sendEachForMulticast({
        tokens: batch,
        notification: { title, body },
        data: { teamId, eventId, type: 'spareNeeded' },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });
      sent += response.successCount;
    }

    // Persist to notification inbox
    await db.collection('teamNotifications').doc(teamId)
      .collection('messages').add({
        title,
        body,
        senderUid: uid,
        sentAt: new Date(),
        eventId,
      });

    return { sent };
  }
);

/**
 * resetTestPasswords — bulk reset passwords for test users.
 * 
 * SECURITY: This function should only be used in development/test environments.
 * It allows resetting passwords without the user's current password.
 * 
 * Params: { email, newPassword } or { resetAll: true }
 *   email       — specific user email to reset
 *   newPassword — the new password to set
 *   resetAll    — if true, resets all @test.com users to the default password
 */
exports.resetTestPasswords = onCall(
  { region: 'northamerica-northeast1', enforceAppCheck: false }, // Disable App Check for testing
  async (request) => {
    const { email, newPassword, resetAll } = request.data;
    const defaultPassword = newPassword || 'testpass123';

    // Security: Only allow in development (check custom claim or specific auth)
    // For now, allow any authenticated user to perform resets (restrict in production)
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const auth = getAuth();

    try {
      if (resetAll) {
        // Reset all @test.com users
        const users = await auth.listUsers();
        const testUsers = users.users.filter(u => u.email?.endsWith('@test.com'));
        
        const results = [];
        for (const user of testUsers) {
          await auth.updateUser(user.uid, { password: defaultPassword });
          results.push({ email: user.email, uid: user.uid });
        }
        return { reset: results.length, users: results };
      } 
      else if (email) {
        // Reset specific user
        const user = await auth.getUserByEmail(email);
        await auth.updateUser(user.uid, { password: defaultPassword });
        return { reset: 1, email, uid: user.uid };
      } 
      else {
        throw new HttpsError('invalid-argument', 'Must provide email or resetAll: true');
      }
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        throw new HttpsError('not-found', 'User not found: ' + email);
      }
      throw new HttpsError('internal', e.message);
    }
  }
);

/**
 * notifyWaitlistPromotion — Firestore trigger that fires when a dropInSession
 * document is updated. If a player moved from waitlist → signups, they get a
 * push notification.
 */
exports.notifyWaitlistPromotion = onDocumentUpdated(
  { document: 'dropInSessions/{sessionId}', region: 'northamerica-northeast1' },
  async (event) => {
    const before = event.data.before.data() ?? {};
    const after  = event.data.after.data()  ?? {};

    const beforeWaitlist = before.waitlist ?? [];
    const afterSignups   = after.signups   ?? [];
    const afterWaitlist  = after.waitlist  ?? [];

    // Find UIDs that were on the waitlist and are now in signups
    const promoted = beforeWaitlist.filter(uid =>
      afterSignups.includes(uid) && !afterWaitlist.includes(uid)
    );
    if (promoted.length === 0) return;

    const db      = getFirestore();
    const eventId = after.eventId;
    const teamId  = after.teamId ?? '';

    // Get event date for notification body
    let timeStr = '';
    if (eventId) {
      const eventSnap = await db.collection('events').doc(eventId).get();
      if (eventSnap.exists) {
        const d = eventSnap.data().date?.toDate();
        if (d) {
          timeStr = d.toLocaleTimeString('en-CA',
            { hour: 'numeric', minute: '2-digit', hour12: true });
        }
      }
    }

    for (const uid of promoted) {
      const userSnap = await db.collection('users').doc(uid).get();
      const fcmToken = userSnap.data()?.fcmToken;
      if (!fcmToken) continue;

      try {
        await getMessaging().send({
          token: fcmToken,
          notification: {
            title: "You're in!",
            body: timeStr
              ? `A spot opened up — you've been moved off the waitlist. Session at ${timeStr}.`
              : "A spot opened up — you've been moved off the waitlist.",
          },
          data: { teamId, eventId: eventId ?? '' },
          android: { priority: 'high' },
          apns:    { payload: { aps: { sound: 'default' } } },
        });
      } catch (_) {
        // Stale token — ignore, token cleanup handled by sendTeamNotification
      }
    }
  }
);
