// Firebase Messaging Service Worker
// Handles background push notifications on web.
// Keep Firebase config in sync with lib/firebase_options.dart (web block).

importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey:            'AIzaSyBkRZZVCLprvRmOFdE55Vy0-VRGJGJRnDQ',
  authDomain:        'sports-rostering.firebaseapp.com',
  projectId:         'sports-rostering',
  storageBucket:     'sports-rostering.firebasestorage.app',
  messagingSenderId: '363898653310',
  appId:             '1:363898653310:web:6e150d09b188a6e75ce62f',
});

const messaging = firebase.messaging();

// Show notification when app is in background / closed.
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'Sports Rostering';
  const body  = payload.notification?.body  ?? '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  });
});
