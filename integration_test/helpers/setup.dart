/// Shared setup for integration tests.
///
/// Physical device (no emulators needed — disable reCAPTCHA in Firebase Console first):
///   Auth → Authentication → Sign-in method → Email/Password → Turn OFF "Enable reCAPTCHA confirmation"
///   Then:
///     flutter drive --driver=test_driver/integration_test.dart --target=integration_test/auth_test.dart --no-build
// ignore_for_file: avoid_relative_lib_imports
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lib/core/router/app_router.dart';
import '../../lib/core/theme/app_theme.dart';
import '../../lib/core/theme/theme_provider.dart';

bool _initialized = false;

/// Call once in setUpAll before pumping the app widget.
/// NOTE: This is a stub for UI-only tests. Real Firebase tests should use firebase_emulators.
Future<void> initTestFirebase() async {
  if (_initialized) return;
  // Skip Firebase init for UI-only tests - the router will redirect to login
  // which is a static screen that doesn't require Firebase.
  _initialized = true;
}

/// Stub for UI-only tests (no Firebase auth to reset).
Future<void> resetAuth() async {
  // No-op for UI-only tests
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
