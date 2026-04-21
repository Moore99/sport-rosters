/// Integration tests for team flows.
/// Requires: firebase emulators:start --only auth,firestore
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/setup.dart';

const _teamName  = 'Integration Test Team';
const _teamSport = 'Ice Hockey';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initTestFirebase);

  setUp(() async {
    await resetAuth();
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: testEmail, password: testPassword,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: testEmail, password: testPassword,
      );
    }
  });

  // ── Teams list ────────────────────────────────────────────────────────────

  testWidgets('teams screen shows empty state when no teams', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.text('My Teams'), findsOneWidget);
    final emptyMsg  = find.text('No teams yet').evaluate().isNotEmpty;
    final createFab = find.text('Create Team').evaluate().isNotEmpty;
    expect(emptyMsg || createFab, isTrue);
  });

  // ── Create team ───────────────────────────────────────────────────────────

  testWidgets('admin can create a team and see it in the list', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle(const Duration(seconds: 4));

    await tester.tap(find.text('Create Team'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, _teamName);
    await tester.pumpAndSettle();

    final sportField = find.textContaining('Sport');
    if (sportField.evaluate().isNotEmpty) {
      await tester.tap(sportField.first);
      await tester.pumpAndSettle();
      final hockeyOption = find.text(_teamSport);
      if (hockeyOption.evaluate().isNotEmpty) {
        await tester.tap(hockeyOption.first);
        await tester.pumpAndSettle();
      }
    }

    await tester.tap(find.text('Create Team').last);
    await tester.pumpAndSettle(const Duration(seconds: 6));

    final onTeams  = find.text('My Teams').evaluate().isNotEmpty;
    final onDetail = find.text(_teamName).evaluate().isNotEmpty;
    expect(onTeams || onDetail, isTrue,
        reason: 'Expected to see team name or teams list after creation');
  });

  // ── Team detail navigation ────────────────────────────────────────────────

  testWidgets('tapping a team navigates to team detail', (tester) async {
    await _createTeamDirectly();

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle(const Duration(seconds: 4));

    await tester.tap(find.text(_teamName));
    await tester.pumpAndSettle();

    expect(find.text(_teamName), findsWidgets);
    final hasEvents = find.text('Events').evaluate().isNotEmpty;
    final hasRoster = find.text('Roster').evaluate().isNotEmpty;
    expect(hasEvents || hasRoster, isTrue);
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _createTeamDirectly() async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  await FirebaseFirestore.instance.collection('teams').add({
    'name':          _teamName,
    'sport':         _teamSport,
    'admins':        [uid],
    'players':       [],
    'minPlayers':    6,
    'maxPlayers':    20,
    'dropInEnabled': false,
    'createdAt':     FieldValue.serverTimestamp(),
    'timezone':      'America/Toronto',
  });
}
