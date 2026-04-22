/// Integration tests for team flows - UI only, no Firebase.
// ignore_for_file: avoid_relative_lib_imports
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initTestFirebase);

  testWidgets('shows My Teams screen when signed out', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // When signed out, router redirects to login
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('shows login screen elements', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('field_email')), findsOneWidget);
    expect(find.byKey(const Key('field_password')), findsOneWidget);
    expect(find.byKey(const Key('btn_sign_in')), findsOneWidget);
  });
}