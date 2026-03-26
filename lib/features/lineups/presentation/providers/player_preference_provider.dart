import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_preference_repository.dart';
import '../../domain/player_preference.dart';

/// Current user's preferences for a specific team.
final myPreferenceProvider = StreamProvider.family<PlayerPreference?,
    ({String teamId, String userId})>((ref, args) {
  return ref
      .read(playerPreferenceRepositoryProvider)
      .watchPreference(args.teamId, args.userId);
});

/// All preferences for a team → map of userId → PlayerPreference.
/// Used by the lineup generator.
final teamPreferencesMapProvider =
    StreamProvider.family<Map<String, PlayerPreference>, String>(
        (ref, teamId) {
  return ref
      .read(playerPreferenceRepositoryProvider)
      .watchTeamPreferences(teamId)
      .map((list) => {for (final p in list) p.userId: p});
});
