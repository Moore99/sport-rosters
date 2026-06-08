/**
 * Count real users in Firestore.
 * Excludes: systemAdmin role, soft-deleted accounts, names containing "Test" (case-insensitive).
 *
 * Usage:
 *   cd functions
 *   $env:GOOGLE_APPLICATION_CREDENTIALS="path\to\serviceAccount.json"
 *   node count_users.js
 *
 * Or if already logged in with Firebase CLI (firebase login):
 *   node count_users.js
 */

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'sports-rostering' });
const db = admin.firestore();

async function countUsers() {
  const snapshot = await db.collection('users').get();

  const all = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  const excluded = [];
  const real = all.filter(u => {
    if (u.deleted === true) { excluded.push(`${u.name} <${u.email}> [deleted]`); return false; }
    if (u.role === 'systemAdmin') { excluded.push(`${u.name} <${u.email}> [systemAdmin]`); return false; }
    if ((u.name || '').toLowerCase().includes('test')) { excluded.push(`${u.name} <${u.email}> [test name]`); return false; }
    if ((u.email || '').toLowerCase().includes('test')) { excluded.push(`${u.name} <${u.email}> [test email]`); return false; }
    return true;
  });

  console.log(`\nTotal docs:     ${all.length}`);
  console.log(`Excluded:       ${excluded.length}`);
  excluded.forEach(e => console.log(`  - ${e}`));
  console.log(`\nReal users:     ${real.length}`);
  real.forEach(u => console.log(`  ${u.name} <${u.email}>`));

  const appleRelays = real.filter(u => u.email.includes('privaterelay.appleid.com'));
  console.log('\n--- Apple relay accounts (full detail) ---');
  appleRelays.forEach(u => {
    console.log(`\nName:      ${u.name}`);
    console.log(`Email:     ${u.email}`);
    console.log(`Role:      ${u.role}`);
    console.log(`Created:   ${u.createdAt?.toDate ? u.createdAt.toDate().toISOString() : u.createdAt}`);
    console.log(`Teams:     ${JSON.stringify(u.teams)}`);
    console.log(`adFree:    ${u.adFree}`);
  });
}

countUsers().catch(err => { console.error(err); process.exit(1); });
