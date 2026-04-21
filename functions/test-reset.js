const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Test the resetTestPasswords function
async function resetAll() {
  const request = {
    auth: { uid: 'test-admin-uid' },
    data: { resetAll: true }
  };
  
  try {
    const result = await exports.resetTestPasswords(request);
    console.log('Result:', JSON.stringify(result, null, 2));
  } catch (e) {
    console.error('Error:', e.message);
  }
}

resetAll();