import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../data/sport_repository.dart';
import '../../domain/sport.dart';

export '../../domain/sport.dart';

Sport? _findByName(List<Sport> sports, String name) {
  final matches = sports.where((s) => s.name == name);
  return matches.isEmpty ? null : matches.first;
}

/// Live list of sports from Firestore, ordered by name.
final sportsProvider = StreamProvider<List<Sport>>((ref) {
  return ref.read(sportRepositoryProvider).watchSports();
});

/// Names only — used for dropdown pickers.
/// Falls back to AppConfig while Firestore is loading.
final sportNamesProvider = Provider<List<String>>((ref) {
  final sports = ref.watch(sportsProvider).valueOrNull;
  if (sports != null && sports.isNotEmpty) {
    return sports.map((s) => s.name).toList();
  }
  return AppConfig.defaultSports;
});

/// Position list for a given sport name.
/// Falls back to AppConfig while Firestore is loading.
final positionsForSportProvider = Provider.family<List<String>, String>((ref, sportName) {
  final sport = _findByName(ref.watch(sportsProvider).valueOrNull ?? [], sportName);
  return sport?.positions ?? AppConfig.positionsForSport(sportName);
});

/// Category map for a given sport name.
/// Falls back to AppConfig while Firestore is loading.
final categoriesForSportProvider =
    Provider.family<Map<String, List<String>>, String>((ref, sportName) {
  final sport = _findByName(ref.watch(sportsProvider).valueOrNull ?? [], sportName);
  return sport?.categories ?? AppConfig.sportPositionCategories[sportName] ?? {};
});
