import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/spares_repository.dart';
import '../../domain/spares.dart';

final teamSparesProvider =
    StreamProvider.family<List<TeamSpare>, String>((ref, teamId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(sparesRepositoryProvider).watchSpares(teamId);
});

final sparesCountProvider = Provider.family<int, String>((ref, teamId) {
  final sparesAsync = ref.watch(teamSparesProvider(teamId));
  return sparesAsync.when(
    data: (spares) => spares.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
