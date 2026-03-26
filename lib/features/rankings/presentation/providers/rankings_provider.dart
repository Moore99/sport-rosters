import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ranking_repository.dart';
import '../../domain/ranking.dart';

final teamRankingsProvider =
    StreamProvider.family<List<Ranking>, String>((ref, teamId) {
  return ref.read(rankingRepositoryProvider).watchTeamRankings(teamId);
});
