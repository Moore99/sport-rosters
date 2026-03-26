import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ranking.dart';

class RankingRepository {
  final FirebaseFirestore _db;
  RankingRepository(this._db);

  CollectionReference<Map<String, dynamic>> _rankings(String teamId) =>
      _db.collection('teams').doc(teamId).collection('rankings');

  /// All rankings for a team — admin use only.
  Stream<List<Ranking>> watchTeamRankings(String teamId) =>
      _rankings(teamId)
          .orderBy('score', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => Ranking.fromFirestore(d, teamId))
              .toList());

  /// One player's ranking — admin use only.
  Future<Ranking?> getRanking(String teamId, String userId) async {
    final doc = await _rankings(teamId).doc(userId).get();
    return doc.exists ? Ranking.fromFirestore(doc, teamId) : null;
  }

  /// Create or overwrite a player's ranking.
  Future<void> setRanking(Ranking ranking) =>
      _rankings(ranking.teamId).doc(ranking.userId).set(ranking.toFirestore());

  Future<void> deleteRanking(String teamId, String userId) =>
      _rankings(teamId).doc(userId).delete();
}

final rankingRepositoryProvider = Provider<RankingRepository>(
  (ref) => RankingRepository(FirebaseFirestore.instance),
);
