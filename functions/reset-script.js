const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const { getAuth } = require('firebase-admin/auth');

exports.resetTestPasswords = functions.https.onCall(async (request) => {
  const { resetAll, email, newPassword } = request.data;
  const defaultPassword = newPassword || 'testpass123';
  
  const uid = request.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
  }

  const auth = getAuth();

  try {
    if (resetAll) {
      const users = await auth.listUsers();
      const testUsers = users.users.filter(u => u.email?.endsWith('@test.com'));
      
      const results = [];
      for (const user of testUsers) {
        await auth.updateUser(user.uid, { password: defaultPassword });
        results.push({ email: user.email, uid: user.uid });
      }
      return { reset: results.length, users: results };
    }
  } catch (e) {
    throw new functions.https.HttpsError('internal', e.message);
  }
});

async function run() {
  // Simulate a call
  const mockRequest = {
    auth: { uid: 'V0Qv5C0JrVT0YqrUoI3zoMp3i2s1' }, // johnhmoore01@gmail.com
    data: { resetAll: true }
  };
  
  const result = await exports.resetTestPasswords(mockRequest);
  console.log('Result:', JSON.stringify(result, null, 2));
}

run().catch(console.error);