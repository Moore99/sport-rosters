/// Shared setup for integration tests.
///
/// Run against Firebase emulators:
///   firebase emulators:start --only auth,firestore,functions
///
/// Then in a separate terminal (Android emulator):
///   flutter test integration_test/ --dart-define=EMULATOR_HOST=10.0.2.2
///
/// Physical device: replace EMULATOR_HOST with your machine's LAN IP.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lib/firebase_options.dart';
import '../../lib/core/router/app_router.dart';
import '../../lib/core/theme/app_theme.dart';
import '../../lib/core/theme/theme_provider.dart';

// Android emulator host for Firebase emulators running on the host machine.
// Override via --dart-define=EMULATOR_HOST=<ip> for physical devices.
const _emulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

bool _initialized = false;

/// Call once in setUpAll before pumping the app widget.
Future<void> initTestFirebase() async {
  if (_initialized) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  _initialized = true;
}

/// Sign out and clear emulator state between tests.
Future<void> resetAuth() async {
  await FirebaseAuth.instance.signOut();
}

/// Pump a minimal test app (no AdMob, no App Check, no Crashlytics).
Widget buildTestApp() => const ProviderScope(child: _TestApp());

class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title:                    'Sport Rosters Test',
      theme:                    AppTheme.light(),
      darkTheme:                AppTheme.dark(),
      themeMode:                themeMode,
      routerConfig:             router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// ── Common test helpers ───────────────────────────────────────────────────────

const _testEmail    = 'testuser@example.com';
const _testPassword = 'Test123!';
const _testName     = 'Test User';

String get testEmail    => _testEmail;
String get testPassword => _testPassword;
String get testName     => _testName;
