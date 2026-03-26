/**
 * seed_test_users.js
 *
 * Creates test users in Firebase Auth + Firestore, plus a test team.
 * Run from the project root:
 *
 *   node scripts/seed_test_users.js
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS to point to a service account key,
 * OR run from inside the functions directory after `firebase login`.
 *
 * Easiest approach — use the Firebase Admin SDK with application default credentials:
 *   firebase login
 *   node scripts/seed_test_users.js
 */

const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getAuth }      = require('firebase-admin/auth');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const path = require('path');
const fs   = require('fs');

// ── Init ──────────────────────────────────────────────────────────────────────

// Try service account key first, fall back to application default credentials
const keyPath = path.join(__dirname, '..', 'service-account-key.json');

if (!getApps().length) {
  if (fs.existsSync(keyPath)) {
    initializeApp({ credential: cert(keyPath) });
  } else {
    initializeApp(); // uses GOOGLE_APPLICATION_CREDENTIALS or gcloud auth
  }
}

const auth = getAuth();
const db   = getFirestore();

// ── Test users ────────────────────────────────────────────────────────────────

const TEST_PASSWORD = 'TestPass123!';

const USERS = [
  // Coaches (indices 0 and 1 — used as team admins below)
  { name: 'Alice Coach',    email: 'alice.coach@test.com',    role: 'player', weightKg: 68 },
  { name: 'Brian Coach',    email: 'brian.coach@test.com',    role: 'player', weightKg: 80 },
  // Players
  { name: 'Carol Adams',    email: 'carol.adams@test.com',    role: 'player', weightKg: 61 },
  { name: 'Dave Baker',     email: 'dave.baker@test.com',     role: 'player', weightKg: 90 },
  { name: 'Eve Carter',     email: 'eve.carter@test.com',     role: 'player', weightKg: 57 },
  { name: 'Frank Davis',    email: 'frank.davis@test.com',    role: 'player', weightKg: 78 },
  { name: 'Grace Evans',    email: 'grace.evans@test.com',    role: 'player', weightKg: 65 },
  { name: 'Henry Ford',     email: 'henry.ford@test.com',     role: 'player', weightKg: 85 },
  { name: 'Iris Green',     email: 'iris.green@test.com',     role: 'player', weightKg: 59 },
  { name: 'Jack Hill',      email: 'jack.hill@test.com',      role: 'player', weightKg: 76 },
  { name: 'Karen Irving',   email: 'karen.irving@test.com',   role: 'player', weightKg: 63 },
  { name: 'Liam Jones',     email: 'liam.jones@test.com',     role: 'player', weightKg: 83 },
  { name: 'Maya King',      email: 'maya.king@test.com',      role: 'player', weightKg: 55 },
  { name: 'Noah Lee',       email: 'noah.lee@test.com',       role: 'player', weightKg: 88 },
  { name: 'Olivia Moore',   email: 'olivia.moore@test.com',   role: 'player', weightKg: 60 },
  { name: 'Paul Nelson',    email: 'paul.nelson@test.com',    role: 'player', weightKg: 92 },
  { name: 'Quinn Owens',    email: 'quinn.owens@test.com',    role: 'player', weightKg: 70 },
  { name: 'Rachel Park',    email: 'rachel.park@test.com',    role: 'player', weightKg: 58 },
  { name: 'Sam Quinn',      email: 'sam.quinn@test.com',      role: 'player', weightKg: 75 },
  { name: 'Tina Reed',      email: 'tina.reed@test.com',      role: 'player', weightKg: 62 },
  { name: 'Uma Scott',      email: 'uma.scott@test.com',      role: 'player', weightKg: 54 },
  { name: 'Victor Tang',    email: 'victor.tang@test.com',    role: 'player', weightKg: 86 },
  { name: 'Wendy Upton',    email: 'wendy.upton@test.com',    role: 'player', weightKg: 67 },
  { name: 'Xander Vance',   email: 'xander.vance@test.com',   role: 'player', weightKg: 79 },
  { name: 'Yara Walsh',     email: 'yara.walsh@test.com',     role: 'player', weightKg: 56 },
  { name: 'Zach Xavier',    email: 'zach.xavier@test.com',    role: 'player', weightKg: 81 },
  { name: 'Amy Young',      email: 'amy.young@test.com',      role: 'player', weightKg: 64 },
  { name: 'Ben Zhang',      email: 'ben.zhang@test.com',      role: 'player', weightKg: 74 },
  { name: 'Clara Abbott',   email: 'clara.abbott@test.com',   role: 'player', weightKg: 66 },
  { name: 'Dylan Brooks',   email: 'dylan.brooks@test.com',   role: 'player', weightKg: 87 },
];

// ── Test teams ────────────────────────────────────────────────────────────────
// Each team gets a slice of the players list (indices into USERS array).
// Indices 0 and 1 are the two coaches.

const TEAMS = [
  {
    id:           'test-team-hockey',
    name:         'Test Blades',
    sport:        'Ice Hockey',
    adminIndices: [0],           // Alice coaches
    playerIndices: [2,3,4,5,6,7,8,9,10,11,12], // 11 players
  },
  {
    id:           'test-team-dragon',
    name:         'Test Dragons',
    sport:        'Dragon Boating',
    adminIndices: [1],           // Brian coaches
    playerIndices: [13,14,15,16,17,18,19,20,21,22,23,24], // 12 players
  },
  {
    id:           'test-team-soccer',
    name:         'Test United',
    sport:        'Football/Soccer',
    adminIndices: [0, 1],        // Both coaches (co-admin test)
    playerIndices: [25,26,27,28,29,2,3,4,5], // 9 players, some overlap
  },
];

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('Creating test users...\n');

  const createdUids = [];

  for (const u of USERS) {
    try {
      // Check if user already exists
      let uid;
      try {
        const existing = await auth.getUserByEmail(u.email);
        uid = existing.uid;
        console.log(`  ⚠  ${u.email} already exists (${uid}) — skipping Auth`);
      } catch {
        const record = await auth.createUser({
          email:         u.email,
          password:      TEST_PASSWORD,
          displayName:   u.name,
          emailVerified: true,
        });
        uid = record.uid;
        console.log(`  ✓  Created Auth user: ${u.email} (${uid})`);
      }

      createdUids.push({ ...u, uid });

      // Upsert Firestore profile
      await db.collection('users').doc(uid).set({
        name:      u.name,
        email:     u.email,
        role:      u.role,
        weightKg:  u.weightKg,
        teams:     [],
        adFree:    false,
        deleted:   false,
        createdAt: Timestamp.now(),
      }, { merge: true });

    } catch (err) {
      console.error(`  ✗  Failed for ${u.email}:`, err.message);
    }
  }

  console.log('\nCreating test teams...\n');

  for (const team of TEAMS) {
    const adminUids  = team.adminIndices.map(i => createdUids[i]?.uid).filter(Boolean);
    const playerUids = team.playerIndices.map(i => createdUids[i]?.uid).filter(Boolean);
    const allMembers = [...new Set([...adminUids, ...playerUids])];

    await db.collection('teams').doc(team.id).set({
      name:      team.name,
      sport:     team.sport,
      admins:    adminUids,
      players:   playerUids,
      createdAt: Timestamp.now(),
    }, { merge: true });

    // Update teams array on each member's profile
    for (const uid of allMembers) {
      await db.collection('users').doc(uid).update({
        teams: FieldValue.arrayUnion(team.id),
      });
    }

    const adminNames = team.adminIndices.map(i => createdUids[i]?.name).join(', ');
    console.log(`  ✓  Team "${team.name}" (${team.sport})`);
    console.log(`       Admins:  ${adminNames}`);
    console.log(`       Players: ${playerUids.length}`);
  }

  console.log('\n─────────────────────────────────────────');
  console.log('Test credentials (all same password):');
  console.log(`  Password: ${TEST_PASSWORD}`);
  console.log('');
  for (const u of createdUids) {
    console.log(`  ${u.email.padEnd(30)} ${u.name}`);
  }
  console.log('─────────────────────────────────────────\n');
  console.log('Done.\n');
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
