import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_rostering/features/lineups/data/player_preference_repository.dart';
import 'package:sports_rostering/features/lineups/domain/player_preference.dart';
import 'package:sports_rostering/features/lineups/presentation/providers/player_preference_provider.dart';

/// In-memory [PlayerPreferenceRepository] — the injection pattern for future
/// repo-backed unit tests. Overriding `playerPreferenceRepositoryProvider` with
/// this needs no Firebase.
class FakePlayerPreferenceRepository implements PlayerPreferenceRepository {
  final Map<String, List<PlayerPreference>> _byTeam;
  FakePlayerPreferenceRepository(this._byTeam);

  @override
  Stream<PlayerPreference?> watchPreference(String teamId, String userId) {
    final matches =
        _byTeam[teamId]?.where((p) => p.userId == userId) ?? const [];
    return Stream.value(matches.isEmpty ? null : matches.first);
  }

  @override
  Stream<List<PlayerPreference>> watchTeamPreferences(String teamId) =>
      Stream.value(_byTeam[teamId] ?? const []);

  @override
  Future<void> savePreference(PlayerPreference pref) async {
    // Upsert — mirrors the real repository's doc `.set` (one doc per userId).
    final list = _byTeam.putIfAbsent(pref.teamId, () => []);
    list.removeWhere((p) => p.userId == pref.userId);
    list.add(pref);
  }
}

void main() {
  test('teamPreferencesMapProvider reads from an injected fake repository',
      () async {
    final pref = PlayerPreference(
      userId: 'p1',
      teamId: 't1',
      preferredPositions: const ['Centre'],
      updatedAt: DateTime(2026, 1, 1),
    );

    final container = ProviderContainer(
      overrides: [
        playerPreferenceRepositoryProvider.overrideWithValue(
          FakePlayerPreferenceRepository({
            't1': [pref],
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    final map = await container.read(teamPreferencesMapProvider('t1').future);

    expect(map.keys, ['p1']);
    expect(map['p1']!.preferredPositions, ['Centre']);
  });
}
