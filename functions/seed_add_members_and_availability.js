/**
 * seed_add_members_and_availability.js
 *
 * 1. Finds every @test.com user in Firestore.
 * 2. Adds them all to Test Blades as players (Alice stays admin, duplicates ignored).
 * 3. Updates each user's `teams` array.
 * 4. Re-seeds availability for all upcoming events:
 *      Test Blades  — first 22 yes, rest no
 *      Test Dragons — all except last 2 yes, last 2 no
 *
 * Run from the functions directory:
 *   cd functions
 *   node seed_add_members_and_availability.js
 */

const { initializeApp, cert, getApps }              = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue }        = require('firebase-admin/firestore');
const path = require('path');
const fs   = require('fs');

// ── Init ──────────────────────────────────────────────────────────────────────

const keyPath = path.join(__dirname, '..', 'service-account-key.json');
if (!getApps().length) {
  fs.existsSync(keyPath)
    ? initializeApp({ credential: cert(keyPath) })
    : initializeApp();
}
const db = getFirestore();

// ── Constants ─────────────────────────────────────────────────────────────────

const HOCKEY_TEAM_ID = 'test-team-hockey';
const DRAGON_TEAM_ID = 'test-team-dragon';

// ── Step 1 & 2: Add all test users to Test Blades ────────────────────────────

async function addAllTestUsersToBlades() {
  console.log('━'.repeat(60));
  console.log('  Step 1 — Adding all @test.com users to Test Blades');
  console.log('━'.repeat(60));

  // Get all test users from Firestore
  const snap = await db.collection('users')
    .where('email', '>=', '@test.com')
    .where('email', '<=', '@test.com\uf8ff')
    .get();

  // email field isn't indexed with that trick reliably; query all and filter
  const allSnap = await db.collection('users').get();
  const testUsers = allSnap.docs
    .filter(d => (d.data().email ?? '').endsWith('@test.com'))
    .map(d => ({ uid: d.id, ...d.data() }));

  console.log(`  Found ${testUsers.length} @test.com users\n`);

  // Load current team to know existing admins
  const teamDoc  = await db.collection('teams').doc(HOCKEY_TEAM_ID).get();
  if (!teamDoc.exists) {
    console.error(`  ✗ Team ${HOCKEY_TEAM_ID} not found — run seed_test_users.js first.`);
    process.exit(1);
  }
  const team       = teamDoc.data();
  const adminSet   = new Set(team.admins ?? []);
  const playerSet  = new Set(team.players ?? []);

  // Determine which UIDs to add as players (admins stay admins, not re-added as players)
  const toAdd = testUsers.filter(u => !adminSet.has(u.uid) && !playerSet.has(u.uid));

  if (toAdd.length === 0) {
    console.log('  All test users already on the team — nothing to add.\n');
  } else {
    console.log(`  Adding ${toAdd.length} new players:`);
    for (const u of toAdd) console.log(`    + ${u.name} (${u.email})`);

    // Batch: update team players array + each user's teams array
    // Firestore batch limit = 500 ops; we're well under that
    const batch = db.batch();

    batch.update(db.collection('teams').doc(HOCKEY_TEAM_ID), {
      players: FieldValue.arrayUnion(...toAdd.map(u => u.uid)),
    });

    for (const u of toAdd) {
      batch.update(db.collection('users').doc(u.uid), {
        teams: FieldValue.arrayUnion(HOCKEY_TEAM_ID),
      });
    }

    await batch.commit();
    console.log('\n  ✅  Team updated.\n');
  }

  // Return fresh member list
  const freshTeam = (await db.collection('teams').doc(HOCKEY_TEAM_ID).get()).data();
  const allAdmins  = freshTeam.admins  ?? [];
  const allPlayers = freshTeam.players ?? [];
  return { admins: allAdmins, players: allPlayers };
}

// ── Step 3: Seed availability ─────────────────────────────────────────────────

async function seedAvailability(teamId, admins, players, yesCount) {
  const allMembers = [...admins, ...players];
  const totalNo    = Math.max(0, allMembers.length - yesCount);

  // Last N players get "no" (never admins)
  const noUids  = new Set(players.slice(-totalNo));
  const yesUids = allMembers.filter(uid => !noUids.has(uid));

  // Resolve names
  const userDocs = await Promise.all(allMembers.map(uid => db.collection('users').doc(uid).get()));
  const nameMap  = {};
  for (const d of userDocs) {
    if (d.exists) nameMap[d.id] = d.data().name ?? d.id;
  }

  // Find all upcoming events
  const eventsSnap = await db.collection('events')
    .where('teamId', '==', teamId)
    .where('date', '>=', Timestamp.fromDate(new Date()))
    .orderBy('date', 'asc')
    .get();

  if (eventsSnap.empty) {
    console.log(`  ⚠️  No upcoming events for ${teamId} — create events in the app first.\n`);
    return;
  }

  const teamDoc  = await db.collection('teams').doc(teamId).get();
  const teamName = teamDoc.data()?.name ?? teamId;
  console.log(`\n${'━'.repeat(60)}`);
  console.log(`  ${teamName}  (${allMembers.length} members — ${yesUids.length} yes / ${noUids.size} no)`);
  console.log('━'.repeat(60));
  console.log(`  ✅ Yes: ${yesUids.map(u => nameMap[u] ?? u).join(', ')}`);
  console.log(`  ❌ No:  ${[...noUids].map(u => nameMap[u] ?? u).join(', ')}\n`);

  for (const eventDoc of eventsSnap.docs) {
    const event    = eventDoc.data();
    const eventId  = eventDoc.id;
    const dateStr  = event.date.toDate().toLocaleDateString('en-CA');
    console.log(`  📅  ${event.type.toUpperCase()}  ${dateStr}  (${eventId})`);

    const batch    = db.batch();
    const availRef = uid =>
      db.collection('events').doc(eventId).collection('availability').doc(uid);

    for (const uid of yesUids) {
      batch.set(availRef(uid), { eventId, teamId, response: 'yes', updatedAt: Timestamp.now() });
    }
    for (const uid of noUids) {
      batch.set(availRef(uid), { eventId, teamId, response: 'no',  updatedAt: Timestamp.now() });
    }
    await batch.commit();
    console.log(`       ✅ ${yesUids.length} yes  ❌ ${noUids.size} no  — written`);
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('\nSeeding members + availability...\n');

  // Test Blades — add all test users, then 22 yes
  const { admins, players } = await addAllTestUsersToBlades();
  await seedAvailability(HOCKEY_TEAM_ID, admins, players, 22);

  // Test Dragons — load existing roster, all except last 2 yes
  console.log(`\n${'━'.repeat(60)}`);
  console.log('  Step 2 — Test Dragons availability');
  const dragonTeamDoc = await db.collection('teams').doc(DRAGON_TEAM_ID).get();
  if (!dragonTeamDoc.exists) {
    console.log('  ⚠️  Test Dragons team not found.\n');
  } else {
    const dt = dragonTeamDoc.data();
    await seedAvailability(DRAGON_TEAM_ID, dt.admins ?? [], dt.players ?? [], (dt.admins?.length ?? 0) + (dt.players?.length ?? 0) - 2);
  }

  console.log('\n\nDone ✅\n');
}

main().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
