/**
 * setup_test_teams.js
 *
 * For the team "test-team-hockey":
 *   1. Accepts all pending join requests.
 *   2. Marks every member's email as verified (Firebase Auth + Firestore).
 *
 * Then creates a duplicate team "Dragon Boat Test" (Dragon Boating sport):
 *   - alice.coach@test.com as the sole admin/coach.
 *   - All other current members of test-team-hockey added as players.
 *   - All their emails also marked verified.
 *
 * Run from the functions/ directory:
 *   node setup_test_teams.js
 *
 * Requires service-account-key.json at repo root, or GOOGLE_APPLICATION_CREDENTIALS.
 */

const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const path = require('path');
const fs = require('fs');

// ── Init ──────────────────────────────────────────────────────────────────────

const keyPath = path.join(__dirname, '..', 'service-account-key.json');

if (!getApps().length) {
  if (fs.existsSync(keyPath)) {
    initializeApp({ credential: cert(keyPath) });
  } else {
    initializeApp();
  }
}

const auth = getAuth();
const db = getFirestore();

const SOURCE_TEAM_ID = 'test-team-hockey';
const NEW_TEAM_ID    = 'dragon-boat-test';
const NEW_TEAM_NAME  = 'Dragon Boat Test';
const NEW_TEAM_SPORT = 'Dragon Boating';
const COACH_EMAIL    = 'alice.coach@test.com';

// ── Helpers ───────────────────────────────────────────────────────────────────

async function markEmailVerified(uid, email) {
  try {
    await auth.updateUser(uid, { emailVerified: true });
    await db.collection('users').doc(uid).set(
      { emailVerified: true },
      { merge: true }
    );
    console.log(`  ✓  Verified email for ${email} (${uid})`);
  } catch (err) {
    console.error(`  ✗  Failed to verify ${email}: ${err.message}`);
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  // ── 1. Load source team ───────────────────────────────────────────────────

  const sourceDoc = await db.collection('teams').doc(SOURCE_TEAM_ID).get();
  if (!sourceDoc.exists) {
    console.error(`Team "${SOURCE_TEAM_ID}" not found. Aborting.`);
    process.exit(1);
  }

  const sourceData = sourceDoc.data();
  const sourceAdmins  = Array.from(sourceData.admins  ?? []);
  const sourcePlayers = Array.from(sourceData.players ?? []);
  const allSourceMembers = [...new Set([...sourceAdmins, ...sourcePlayers])];

  console.log(`\nSource team "${sourceData.name}" (${SOURCE_TEAM_ID})`);
  console.log(`  Admins:  ${sourceAdmins.length}`);
  console.log(`  Players: ${sourcePlayers.length}`);

  // ── 2. Accept all pending join requests ───────────────────────────────────

  console.log('\n─── Accepting pending join requests ─────────────────────────');

  const pendingSnap = await db
    .collection('teams').doc(SOURCE_TEAM_ID)
    .collection('joinRequests')
    .where('status', '==', 'pending')
    .get();

  if (pendingSnap.empty) {
    console.log('  (no pending requests)');
  }

  for (const reqDoc of pendingSnap.docs) {
    const req = reqDoc.data();
    const userId = req.userId || reqDoc.id;

    const batch = db.batch();
    batch.update(db.collection('teams').doc(SOURCE_TEAM_ID), {
      players: FieldValue.arrayUnion(userId),
    });
    batch.update(db.collection('users').doc(userId), {
      teams: FieldValue.arrayUnion(SOURCE_TEAM_ID),
    });
    batch.update(
      db.collection('teams').doc(SOURCE_TEAM_ID).collection('joinRequests').doc(reqDoc.id),
      { status: 'approved' }
    );
    await batch.commit();

    // Add to our working member list if not already present
    if (!allSourceMembers.includes(userId)) {
      allSourceMembers.push(userId);
      sourcePlayers.push(userId);
    }

    console.log(`  ✓  Approved ${req.userEmail ?? userId}`);
  }

  // ── 3. Mark all source-team members as email-verified ─────────────────────

  console.log('\n─── Marking source team member emails verified ───────────────');

  const memberProfiles = [];

  for (const uid of allSourceMembers) {
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    memberProfiles.push({ uid, email: userData.email ?? '(unknown)', name: userData.name ?? uid, data: userData });
    await markEmailVerified(uid, userData.email ?? uid);
  }

  // ── 4. Resolve alice.coach UID ────────────────────────────────────────────

  let coachUid;
  try {
    const coachRecord = await auth.getUserByEmail(COACH_EMAIL);
    coachUid = coachRecord.uid;
    console.log(`\nCoach ${COACH_EMAIL} → uid: ${coachUid}`);
  } catch (err) {
    console.error(`\nCould not find ${COACH_EMAIL} in Firebase Auth: ${err.message}`);
    process.exit(1);
  }

  // ── 5. Build new team member lists ───────────────────────────────────────

  // Coach is admin; everyone else is a player (excluding coach from players list)
  const newAdmins  = [coachUid];
  const newPlayers = allSourceMembers.filter(uid => uid !== coachUid);

  // ── 6. Upsert the Dragon Boat Test team ──────────────────────────────────

  console.log(`\n─── Creating/updating team "${NEW_TEAM_NAME}" (${NEW_TEAM_ID}) ────`);

  await db.collection('teams').doc(NEW_TEAM_ID).set({
    name:          NEW_TEAM_NAME,
    sport:         NEW_TEAM_SPORT,
    admins:        newAdmins,
    players:       newPlayers,
    minPlayers:    sourceData.minPlayers  ?? 1,
    maxPlayers:    sourceData.maxPlayers  ?? 20,
    dropInEnabled: sourceData.dropInEnabled ?? false,
    createdAt:     Timestamp.now(),
  }, { merge: false });

  console.log(`  ✓  Team doc written`);
  console.log(`       Admin:   ${COACH_EMAIL} (${coachUid})`);
  console.log(`       Players: ${newPlayers.length}`);

  // Add NEW_TEAM_ID to every member's teams array
  const allNewMembers = [...new Set([...newAdmins, ...newPlayers])];
  for (const uid of allNewMembers) {
    await db.collection('users').doc(uid).update({
      teams: FieldValue.arrayUnion(NEW_TEAM_ID),
    });
  }
  console.log(`  ✓  Updated users.teams for ${allNewMembers.length} members`);

  // ── 7. Mark new team members as email-verified ────────────────────────────

  console.log('\n─── Marking new team member emails verified ──────────────────');

  for (const uid of allNewMembers) {
    const existing = memberProfiles.find(p => p.uid === uid);
    const email = existing?.email ?? uid;
    await markEmailVerified(uid, email);
  }

  // ── 8. Summary ────────────────────────────────────────────────────────────

  console.log('\n══════════════════════════════════════════════════════════════');
  console.log('Done.');
  console.log(`  Source team "${sourceData.name}" — ${pendingSnap.size} request(s) approved.`);
  console.log(`  New team "${NEW_TEAM_NAME}" created with ${allNewMembers.length} members.`);
  console.log(`  All ${allSourceMembers.length} source members + new team members → email verified.`);
  console.log('══════════════════════════════════════════════════════════════\n');
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
