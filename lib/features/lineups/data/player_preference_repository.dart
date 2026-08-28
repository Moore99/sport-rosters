import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_preference.dart';

/// Persistence for per-team player position preferences.
abstract class PlayerPreferenceRepository {
  Stream<PlayerPreference?> watchPreference(String teamId, String userId);

  /// All preferences for a team — used by the lineup generator.
  Stream<List<PlayerPreference>> watchTeamPreferences(String teamId);

  Future<void> savePreference(PlayerPreference pref);
}

class FirestorePlayerPreferenceRepository
    implements PlayerPreferenceRepository {
  final FirebaseFirestore _db;
  FirestorePlayerPreferenceRepository(this._db);

  CollectionReference<Map<String, dynamic>> _prefs(String teamId) =>
      _db.collection('teams').doc(teamId).collection('playerPreferences');

  @override
  Stream<PlayerPreference?> watchPreference(String teamId, String userId) =>
      _prefs(teamId).doc(userId).snapshots().map(
            (doc) =>
                doc.exists ? PlayerPreference.fromFirestore(doc, teamId) : null,
          );

  @override
  Stream<List<PlayerPreference>> watchTeamPreferences(String teamId) =>
      _prefs(teamId).snapshots().map(
            (s) => s.docs
                .map((doc) => PlayerPreference.fromFirestore(doc, teamId))
                .toList(),
          );

  @override
  Future<void> savePreference(PlayerPreference pref) =>
      _prefs(pref.teamId).doc(pref.userId).set(pref.toFirestore());
}

final playerPreferenceRepositoryProvider = Provider<PlayerPreferenceRepository>(
  (ref) => FirestorePlayerPreferenceRepository(FirebaseFirestore.instance),
);
