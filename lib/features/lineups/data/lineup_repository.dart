import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/lineup.dart';

/// Persistence for event lineups and per-team lineup templates.
abstract class LineupRepository {
  /// One active lineup per event — doc ID = eventId for simplicity.
  Stream<Lineup?> watchLineup(String eventId);

  Future<void> saveLineup(Lineup lineup);

  Future<void> deleteLineup(String eventId);

  /// Saves the current draft as the reusable template for this team + sport.
  Future<void> saveTemplate(
      String teamId, String sport, Map<String, String> assignments);

  /// Returns the saved template assignments, or null if none exists.
  Future<Map<String, String>?> loadTemplate(String teamId, String sport);
}

class FirestoreLineupRepository implements LineupRepository {
  final FirebaseFirestore _db;
  FirestoreLineupRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _lineups =>
      _db.collection('lineups');

  CollectionReference<Map<String, dynamic>> get _templates =>
      _db.collection('lineupTemplates');

  /// Doc ID encodes team + sport so each team has one template per sport.
  String _templateId(String teamId, String sport) =>
      '${teamId}__${sport.replaceAll(RegExp(r'[^\w]'), '_')}';

  @override
  Stream<Lineup?> watchLineup(String eventId) =>
      _lineups.doc(eventId).snapshots().map(
            (doc) => doc.exists ? Lineup.fromFirestore(doc) : null,
          );

  @override
  Future<void> saveLineup(Lineup lineup) =>
      _lineups.doc(lineup.eventId).set(lineup.toFirestore());

  @override
  Future<void> deleteLineup(String eventId) => _lineups.doc(eventId).delete();

  @override
  Future<void> saveTemplate(
          String teamId, String sport, Map<String, String> assignments) =>
      _templates.doc(_templateId(teamId, sport)).set({
        'teamId': teamId,
        'sport': sport,
        'assignments': assignments,
        'savedAt': Timestamp.fromDate(DateTime.now()),
      });

  @override
  Future<Map<String, String>?> loadTemplate(String teamId, String sport) async {
    final doc = await _templates.doc(_templateId(teamId, sport)).get();
    if (!doc.exists) return null;
    final raw = doc.data()?['assignments'] as Map<dynamic, dynamic>?;
    if (raw == null) return null;
    return raw.map((k, v) => MapEntry(k as String, v as String));
  }
}

final lineupRepositoryProvider = Provider<LineupRepository>(
  (ref) => FirestoreLineupRepository(FirebaseFirestore.instance),
);
