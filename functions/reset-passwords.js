process.env.GOOGLE_CLOUD_PROJECT = 'sports-rostering';
process.env.GCLOUD_PROJECT = 'sports-rostering';

const admin = require('firebase-admin');
admin.initializeApp();

const auth = admin.auth();

async function reset() {
  console.log('Fetching users...');
  const users = await auth.listUsers();
  
  const testUsers = users.users.filter(u => u.email && u.email.endsWith('@test.com'));
  console.log('Found', testUsers.length, 'test users');
  
  for (const user of testUsers) {
    await auth.updateUser(user.uid, { password: 'testpass123' });
    console.log('Reset:', user.email);
  }
  console.log('All done!');
}

reset().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});