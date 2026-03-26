// ─────────────────────────────────────────────────────────────────────────────
// firebase_options.dart — GENERATED FILE
//
// DO NOT edit manually. Regenerate with:
//   flutterfire configure
//
// Prerequisites:
//   dart pub global activate flutterfire_cli
//   firebase login
//   flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
//
// This generates DefaultFirebaseOptions for Android, iOS, and Web.
// ─────────────────────────────────────────────────────────────────────────────
//
// Placeholder — replace with generated output from `flutterfire configure`

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBkRZZVCLprvRmOFdE55Vy0-VRGJGJRnDQ',
    appId: '1:363898653310:web:6e150d09b188a6e75ce62f',
    messagingSenderId: '363898653310',
    projectId: 'sports-rostering',
    authDomain: 'sports-rostering.firebaseapp.com',
    storageBucket: 'sports-rostering.firebasestorage.app',
  );

  // Replace all values below with output from `flutterfire configure`

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfj7g2--iAf0CDKBcFyRv7Ia7KIuoH_D4',
    appId: '1:363898653310:android:cd50ad3a75acb8c95ce62f',
    messagingSenderId: '363898653310',
    projectId: 'sports-rostering',
    storageBucket: 'sports-rostering.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAMppXMvnrjJPuu7WFyYQN8RvZxDFxUJC4',
    appId: '1:363898653310:ios:075d70dc074aa36b5ce62f',
    messagingSenderId: '363898653310',
    projectId: 'sports-rostering',
    storageBucket: 'sports-rostering.firebasestorage.app',
    iosBundleId: 'com.sportsrostering.app',
  );

}