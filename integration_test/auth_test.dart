/// Integration tests for auth flows - UI only, no Firebase.
///
/// Running:
///   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/auth_test.dart --no-build
// ignore_for_file: avoid_relative_lib_imports
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initTestFirebase);

  testWidgets('shows login screen when signed out', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Router redirects to login when signed out
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('login form has required fields', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Email and password fields exist
    expect(find.byKey(const Key('field_email')), findsOneWidget);
    expect(find.byKey(const Key('field_password')), findsOneWidget);
    expect(find.byKey(const Key('btn_sign_in')), findsOneWidget);
  });
}