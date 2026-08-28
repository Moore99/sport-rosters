import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ranking.dart';

/// Persistence for coach-private player rankings — admin use only.
abstract class RankingRepository {
  /// All rankings for a team — admin use only.
  Stream<List<Ranking>> watchTeamRankings(String teamId);

  /// One player's ranking — admin use only.
  Future<Ranking?> getRanking(String teamId, String userId);

  /// Create or overwrite a player's ranking.
  Future<void> setRanking(Ranking ranking);

  Future<void> deleteRanking(String teamId, String userId);
}

class FirestoreRankingRepository implements RankingRepository {
  final FirebaseFirestore _db;
  FirestoreRankingRepository(this._db);

  CollectionReference<Map<String, dynamic>> _rankings(String teamId) =>
      _db.collection('teams').doc(teamId).collection('rankings');

  @override
  Stream<List<Ranking>> watchTeamRankings(String teamId) => _rankings(teamId)
      .orderBy('score', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Ranking.fromFirestore(d, teamId)).toList());

  @override
  Future<Ranking?> getRanking(String teamId, String userId) async {
    final doc = await _rankings(teamId).doc(userId).get();
    return doc.exists ? Ranking.fromFirestore(doc, teamId) : null;
  }

  @override
  Future<void> setRanking(Ranking ranking) =>
      _rankings(ranking.teamId).doc(ranking.userId).set(ranking.toFirestore());

  @override
  Future<void> deleteRanking(String teamId, String userId) =>
      _rankings(teamId).doc(userId).delete();
}

final rankingRepositoryProvider = Provider<RankingRepository>(
  (ref) => FirestoreRankingRepository(FirebaseFirestore.instance),
);
