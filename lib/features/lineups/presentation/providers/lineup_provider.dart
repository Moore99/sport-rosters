import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lineup_repository.dart';
import '../../domain/lineup.dart';

final lineupProvider =
    StreamProvider.family<Lineup?, String>((ref, eventId) {
  return ref.read(lineupRepositoryProvider).watchLineup(eventId);
});
