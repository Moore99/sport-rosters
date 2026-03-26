import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_preference.dart';

class PlayerPreferenceRepository {
  final FirebaseFirestore _db;
  PlayerPreferenceRepository(this._db);

  CollectionReference<Map<String, dynamic>> _prefs(String teamId) =>
      _db.collection('teams').doc(teamId).collection('playerPreferences');

  Stream<PlayerPreference?> watchPreference(String teamId, String userId) =>
      _prefs(teamId).doc(userId).snapshots().map(
        (doc) => doc.exists
            ? PlayerPreference.fromFirestore(doc, teamId)
            : null,
      );

  /// All preferences for a team — used by the lineup generator.
  Stream<List<PlayerPreference>> watchTeamPreferences(String teamId) =>
      _prefs(teamId).snapshots().map(
        (s) => s.docs
            .map((doc) => PlayerPreference.fromFirestore(doc, teamId))
            .toList(),
      );

  Future<void> savePreference(PlayerPreference pref) =>
      _prefs(pref.teamId).doc(pref.userId).set(pref.toFirestore());
}

final playerPreferenceRepositoryProvider =
    Provider<PlayerPreferenceRepository>(
  (ref) => PlayerPreferenceRepository(FirebaseFirestore.instance),
);
