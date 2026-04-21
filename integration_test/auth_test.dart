/// Integration tests for auth flows.
/// Requires: firebase emulators:start --only auth,firestore
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initTestFirebase);
  setUp(resetAuth);

  // ── Register ──────────────────────────────────────────────────────────────

  testWidgets('user can register with email and password', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Should land on login screen
    expect(find.text('Sign In'), findsOneWidget);

    // Navigate to register
    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsWidgets);

    // Fill in the form
    await tester.enterText(find.byKey(const Key('field_name')),     testName);
    await tester.enterText(find.byKey(const Key('field_email')),    testEmail);
    await tester.enterText(find.byKey(const Key('field_password')), testPassword);
    await tester.enterText(find.byKey(const Key('field_confirm_password')), testPassword);

    // Accept terms
    await tester.tap(find.byKey(const Key('chk_terms')));
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.byKey(const Key('btn_create_account')));
    await tester.pumpAndSettle(const Duration(seconds: 8));

    // Should land on Teams screen (or email verify screen)
    final onTeams  = find.text('My Teams').evaluate().isNotEmpty;
    final onVerify = find.textContaining('verify').evaluate().isNotEmpty ||
                     find.textContaining('Verify').evaluate().isNotEmpty;
    expect(onTeams || onVerify, isTrue,
        reason: 'Expected Teams or email-verify screen after registration');
  });

  // ── Sign in ───────────────────────────────────────────────────────────────

  testWidgets('registered user can sign in', (tester) async {
    // Pre-create account in emulator
    await _createTestAccount();

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field_email')),    testEmail);
    await tester.enterText(find.byKey(const Key('field_password')), testPassword);
    await tester.tap(find.byKey(const Key('btn_sign_in')));
    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(find.text('My Teams'), findsOneWidget);
  });

  // ── Sign out ──────────────────────────────────────────────────────────────

  testWidgets('signed-in user can sign out', (tester) async {
    await _createTestAccount();
    await _signInTestAccount();

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Navigate to Profile
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    // Scroll to and tap Sign Out
    await tester.scrollUntilVisible(find.text('Sign Out'), 300);
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    // Confirm dialog
    await tester.tap(find.text('Sign Out').last);
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.text('Sign In'), findsOneWidget);
  });

  // ── Invalid credentials ───────────────────────────────────────────────────

  testWidgets('wrong password shows error snackbar', (tester) async {
    await _createTestAccount();

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field_email')),    testEmail);
    await tester.enterText(find.byKey(const Key('field_password')), 'WrongPass!');
    await tester.tap(find.byKey(const Key('btn_sign_in')));
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // Still on login screen
    expect(find.text('Sign In'), findsOneWidget);
    // Error shown (snackbar or inline)
    final hasError = find.textContaining('failed').evaluate().isNotEmpty ||
                     find.textContaining('invalid').evaluate().isNotEmpty ||
                     find.textContaining('wrong').evaluate().isNotEmpty ||
                     find.textContaining('Login').evaluate().isNotEmpty;
    expect(hasError, isTrue, reason: 'Expected an error message on bad credentials');
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';

Future<void> _createTestAccount() async {
  try {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email:    testEmail,
      password: testPassword,
    );
    await FirebaseAuth.instance.signOut();
  } on FirebaseAuthException catch (e) {
    if (e.code != 'email-already-in-use') rethrow;
  }
}

Future<void> _signInTestAccount() async {
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email:    testEmail,
    password: testPassword,
  );
}
