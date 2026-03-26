/**
 * seed_availability.js
 *
 * Sets availability RSVPs for Test Blades (test-team-hockey).
 * All members except two (Maya King + Liam Jones) respond "yes".
 * Those two respond "no".
 *
 * Run from the functions directory (where firebase-admin is installed):
 *   node seed_availability.js
 */

const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
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

const TEAM_ID = 'test-team-hockey';

async function main() {
  // 1. Load the team to get member UIDs
  const teamDoc = await db.collection('teams').doc(TEAM_ID).get();
  if (!teamDoc.exists) {
    console.error(`Team ${TEAM_ID} not found.`);
    process.exit(1);
  }
  const team = teamDoc.data();
  const allMembers = [...(team.admins || []), ...(team.players || [])];
  console.log(`Team "${team.name}" — ${allMembers.length} members\n`);

  // 2. Find the next upcoming event for this team
  const now = new Date();
  const eventsSnap = await db.collection('events')
    .where('teamId', '==', TEAM_ID)
    .where('date', '>=', Timestamp.fromDate(now))
    .orderBy('date', 'asc')
    .limit(1)
    .get();

  if (eventsSnap.empty) {
    console.error('No upcoming events found for Test Blades.');
    console.log('Create an event for this team in the app first, then rerun.');
    process.exit(1);
  }

  const eventDoc = eventsSnap.docs[0];
  const event    = eventDoc.data();
  const eventId  = eventDoc.id;
  const eventDate = event.date.toDate().toLocaleDateString();
  console.log(`Event: "${event.type}" on ${eventDate} (${eventId})\n`);

  // 3. Pick two members to respond "no" — last two in the players list
  const noUids  = new Set(team.players.slice(-2));
  const yesUids = allMembers.filter(uid => !noUids.has(uid));

  // 4. Resolve names for display
  const userDocs = await Promise.all(
    allMembers.map(uid => db.collection('users').doc(uid).get())
  );
  const nameMap = {};
  for (const doc of userDocs) {
    if (doc.exists) nameMap[doc.id] = doc.data().name;
  }

  // 5. Write availability docs
  const batch = db.batch();
  const availRef = (uid) =>
    db.collection('events').doc(eventId).collection('availability').doc(uid);

  for (const uid of yesUids) {
    batch.set(availRef(uid), {
      eventId,
      teamId:    TEAM_ID,
      response:  'yes',
      updatedAt: Timestamp.now(),
    });
  }
  for (const uid of noUids) {
    batch.set(availRef(uid), {
      eventId,
      teamId:    TEAM_ID,
      response:  'no',
      updatedAt: Timestamp.now(),
    });
  }

  await batch.commit();

  console.log('✅  Yes:');
  for (const uid of yesUids) {
    console.log(`     ${(nameMap[uid] || uid).padEnd(25)}`);
  }
  console.log('\n❌  No (2 players left out):');
  for (const uid of noUids) {
    console.log(`     ${(nameMap[uid] || uid).padEnd(25)}`);
  }
  console.log('\nDone.');
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
