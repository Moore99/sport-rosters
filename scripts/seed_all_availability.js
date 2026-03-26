/**
 * seed_all_availability.js
 *
 * Seeds RSVPs for ALL upcoming events across Test Blades and Test Dragons.
 *
 * Test Blades  — all members yes, last 2 players no (for each upcoming event)
 * Test Dragons — all members yes, last 2 players no (for each upcoming event)
 *
 * Run from the functions directory (where firebase-admin is installed):
 *   cd functions
 *   node ../scripts/seed_all_availability.js
 */

const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp }       = require('firebase-admin/firestore');
const path = require('path');
const fs   = require('fs');

// ── Init ──────────────────────────────────────────────────────────────────────

const keyPath = path.join(__dirname, '..', 'service-account-key.json');

if (!getApps().length) {
  if (fs.existsSync(keyPath)) {
    initializeApp({ credential: cert(keyPath) });
  } else {
    initializeApp();
  }
}

const db = getFirestore();

// ── Config ────────────────────────────────────────────────────────────────────

const TEAMS = [
  { id: 'test-team-hockey', label: 'Test Blades',  noCount: 2 },
  { id: 'test-team-dragon', label: 'Test Dragons', noCount: 2 },
];

// ── Helpers ───────────────────────────────────────────────────────────────────

async function getTeam(teamId) {
  const doc = await db.collection('teams').doc(teamId).get();
  if (!doc.exists) throw new Error(`Team ${teamId} not found`);
  return doc.data();
}

async function getUpcomingEvents(teamId) {
  const snap = await db.collection('events')
    .where('teamId', '==', teamId)
    .where('date', '>=', Timestamp.fromDate(new Date()))
    .orderBy('date', 'asc')
    .get();
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

async function resolveNames(uids) {
  const docs = await Promise.all(uids.map(uid => db.collection('users').doc(uid).get()));
  const map  = {};
  for (const d of docs) {
    if (d.exists) map[d.id] = d.data().name ?? d.id;
  }
  return map;
}

async function seedTeamEvents(teamId, label, noCount) {
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`  ${label}  (${teamId})`);
  console.log('═'.repeat(60));

  const team       = await getTeam(teamId);
  const allMembers = [...(team.admins ?? []), ...(team.players ?? [])];
  const nameMap    = await resolveNames(allMembers);

  console.log(`  Members: ${allMembers.length}`);

  // Last N players respond "no" (not the admins)
  const players  = team.players ?? [];
  const noUids   = new Set(players.slice(-noCount));
  const yesUids  = allMembers.filter(uid => !noUids.has(uid));

  console.log(`  Yes: ${yesUids.length}   No: ${noUids.size}\n`);

  const events = await getUpcomingEvents(teamId);
  if (events.length === 0) {
    console.log('  ⚠️  No upcoming events found — create events in the app first.\n');
    return;
  }

  for (const event of events) {
    const eventDate = event.date.toDate().toLocaleDateString('en-CA');
    console.log(`  📅  ${event.type.toUpperCase()}  ${eventDate}  (${event.id})`);

    const batch   = db.batch();
    const availRef = uid =>
      db.collection('events').doc(event.id).collection('availability').doc(uid);

    for (const uid of yesUids) {
      batch.set(availRef(uid), {
        eventId:   event.id,
        teamId,
        response:  'yes',
        updatedAt: Timestamp.now(),
      });
    }
    for (const uid of noUids) {
      batch.set(availRef(uid), {
        eventId:   event.id,
        teamId,
        response:  'no',
        updatedAt: Timestamp.now(),
      });
    }

    await batch.commit();

    console.log(`       ✅ Yes (${yesUids.length}): ${yesUids.map(u => nameMap[u] ?? u).join(', ')}`);
    console.log(`       ❌ No  (${noUids.size}): ${[...noUids].map(u => nameMap[u] ?? u).join(', ')}`);
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('\nSeeding availability for all upcoming events...\n');

  for (const { id, label, noCount } of TEAMS) {
    await seedTeamEvents(id, label, noCount);
  }

  console.log('\n\nDone ✅\n');
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
