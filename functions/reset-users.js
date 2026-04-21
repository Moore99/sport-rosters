process.env.GOOGLE_CLOUD_PROJECT = 'sports-rostering';
process.env.GCLOUD_PROJECT = 'sports-rostering';

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

async function resetTestUsers() {
  console.log('Fetching users from Firebase Auth...');
  const users = await auth.listUsers();
  
  const testUsers = users.users.filter(u => u.email && u.email.endsWith('@test.com'));
  console.log(`Found ${testUsers.length} test users`);
  
  // Map of old uid -> user data for recreation
  const userDataMap = {};
  
  // 1. Get Firestore user data before deleting
  for (const user of testUsers) {
    try {
      const userDoc = await db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        userDataMap[user.email] = userDoc.data();
        console.log('Saved Firestore data for:', user.email);
      }
    } catch (e) {
      console.log('No Firestore data for:', user.email);
    }
  }
  
  // 2. Delete users
  console.log('\nDeleting users...');
  for (const user of testUsers) {
    await auth.deleteUser(user.uid);
    console.log('Deleted:', user.email);
  }
  
  // 3. Recreate users with new password
  console.log('\nRecreating users with testpass123...');
  const createdUsers = [];
  
  for (const user of testUsers) {
    const email = user.email;
    const data = userDataMap[email];
    
    // Create user
    const newUser = await auth.createUser({
      email: email,
      password: 'testpass123',
      displayName: data?.name || email.split('@')[0]
    });
    
    console.log('Created:', email, '-> uid:', newUser.uid);
    
    // Restore Firestore data
    await db.collection('users').doc(newUser.uid).set({
      ...data,
      // Keep the new UID
    });
    
    // Restore team memberships (need to update teams with new uid)
    if (data?.teams && data.teams.length > 0) {
      for (const teamId of data.teams) {
        try {
          const teamRef = db.collection('teams').doc(teamId);
          const teamDoc = await teamRef.get();
          if (teamDoc.exists) {
            const teamData = teamDoc.data();
            
            // Update players array
            const players = teamData.players || [];
            const idx = players.indexOf(user.uid);
            if (idx > -1) {
              players[idx] = newUser.uid;
              await teamRef.update({ players: players });
            }
            
            // Update admins array
            const admins = teamData.admins || [];
            const adminIdx = admins.indexOf(user.uid);
            if (adminIdx > -1) {
              admins[adminIdx] = newUser.uid;
              await teamRef.update({ admins: admins });
            }
          }
        } catch (e) {
          console.log('Error updating team', teamId, ':', e.message);
        }
      }
    }
    
    createdUsers.push({ email, newUid: newUser.uid });
  }
  
  console.log('\n✅ Done! Reset', createdUsers.length, 'users');
  createdUsers.forEach(u => console.log(`  ${u.email} -> ${u.newUid}`));
}

resetTestUsers().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});