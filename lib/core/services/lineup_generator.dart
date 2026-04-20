import 'dart:math';

import '../../features/lineups/domain/player_preference.dart';
import '../../features/rankings/domain/ranking.dart';

/// Greedy position-assignment algorithm.
///
/// Priority order for assigning a player to a position:
///   0 — exact position match in player's preferences
///   1 — category match  (e.g. "Any Forward" covers "Left Wing")
///   2 — "Any" wildcard preference
///   3 — no preferences set (willing to play anywhere)
///
/// Within the same priority, higher-ranked players are preferred.
/// Positions are filled most-constrained-first (fewest eligible players).
class LineupGenerator {
  LineupGenerator._();

  /// Returns a position → userId map.
  /// Positions that couldn't be filled are mapped to ''.
  static Map<String, String> generate({
    required List<String>                       positions,
    required List<String>                       availableUids,
    required Map<String, Ranking>               rankings,
    required Map<String, PlayerPreference>      preferences,
    required Map<String, List<String>>          sportCategories,
    // sport param retained for call-site compatibility but no longer used
    String sport = '',
  }) {
    // Build eligibility list for each position
    final eligibility = <String, List<_Candidate>>{};

    for (final pos in positions) {
      eligibility[pos] = [];
      for (final uid in availableUids) {
        final pref  = preferences[uid];
        final score = rankings[uid]?.score ?? 5.0;

        int priority;
        if (pref == null || !pref.hasPreferences) {
          priority = 3; // no preferences — can play anywhere, lowest priority
        } else {
          priority = _matchPriority(pos, pref.preferredPositions, sportCategories);
          if (priority < 0) continue; // player not willing to play this position
        }
        eligibility[pos]!.add(_Candidate(uid, priority, score));
      }
      // Sort: priority asc (0 = best), then ranking score desc
      eligibility[pos]!.sort((a, b) {
        if (a.priority != b.priority) return a.priority.compareTo(b.priority);
        return b.score.compareTo(a.score);
      });
    }

    // Fill most-constrained positions first
    final sortedPositions = [...positions]
      ..sort((a, b) =>
          eligibility[a]!.length.compareTo(eligibility[b]!.length));

    // Greedy assignment
    final assignments = <String, String>{};
    final used        = <String>{};

    for (final pos in sortedPositions) {
      String assigned = '';
      for (final candidate in eligibility[pos]!) {
        if (!used.contains(candidate.uid)) {
          assigned = candidate.uid;
          used.add(candidate.uid);
          break;
        }
      }
      assignments[pos] = assigned;
    }

    return assignments;
  }

  /// Splits [availableUids] into [numSubTeams] balanced sub-teams via snake
  /// draft ordered by ranking score with random tie-breaking.
  ///
  /// For sports with a goalie position ('Goalie', 'Goalkeeper', or 'Keeper'),
  /// one eligible goalie is pre-assigned per team before the draft begins.
  ///
  /// Returns a list of [numSubTeams] position→userId maps.
  static List<Map<String, String>> generateSubTeams({
    required int                                numSubTeams,
    required List<String>                       positions,
    required List<String>                       availableUids,
    required Map<String, Ranking>               rankings,
    required Map<String, PlayerPreference>      preferences,
    required Map<String, List<String>>          sportCategories,
    String sport = '',
  }) {
    if (numSubTeams <= 1) {
      return [generate(
        positions: positions, availableUids: availableUids,
        rankings: rankings, preferences: preferences,
        sportCategories: sportCategories,
      )];
    }

    final rng = Random();

    // Group by score, shuffle within each group (random tie-breaking),
    // then concatenate high→low.
    final grouped = <double, List<String>>{};
    for (final uid in availableUids) {
      final s = rankings[uid]?.score ?? 5.0;
      (grouped[s] ??= []).add(uid);
    }
    final pool = <String>[];
    for (final score in (grouped.keys.toList()..sort((a, b) => b.compareTo(a)))) {
      pool.addAll(grouped[score]!..shuffle(rng));
    }

    // Identify goalie position for this sport
    final goaliePos = _goaliePositionForSport(positions);
    final nonGoalieSlotsPerTeam =
        positions.length - (goaliePos != null ? 1 : 0);

    final rosters = List.generate(numSubTeams, (_) => <String>[]);
    final goalies = List<String?>.filled(numSubTeams, null);

    // Pre-assign one goalie per team from the front of the rating-sorted pool
    if (goaliePos != null) {
      for (int t = 0; t < numSubTeams; t++) {
        for (int i = 0; i < pool.length; i++) {
          if (_willingToPlayGoalie(pool[i], goaliePos, preferences, sportCategories)) {
            goalies[t] = pool.removeAt(i);
            break;
          }
        }
      }
    }

    // Snake-draft remaining players into team rosters
    var forward = true;
    while (pool.isNotEmpty &&
        rosters.any((r) => r.length < nonGoalieSlotsPerTeam)) {
      final order = forward
          ? List.generate(numSubTeams, (i) => i)
          : List.generate(numSubTeams, (i) => numSubTeams - 1 - i);
      forward = !forward;
      for (final t in order) {
        if (rosters[t].length >= nonGoalieSlotsPerTeam) continue;
        if (pool.isEmpty) break;
        rosters[t].add(pool.removeAt(0));
      }
    }

    // Assign positions within each team using the preference-aware algorithm
    return List.generate(numSubTeams, (t) {
      final teamUids = [...rosters[t], if (goalies[t] != null) goalies[t]!];
      return generate(
        positions:      positions,
        availableUids:  teamUids,
        rankings:       rankings,
        preferences:    preferences,
        sportCategories: sportCategories,
        sport:          sport,
      );
    });
  }

  static String? _goaliePositionForSport(List<String> positions) {
    const names = ['Goalie', 'Goalkeeper', 'Keeper'];
    for (final n in names) {
      if (positions.contains(n)) return n;
    }
    return null;
  }

  static bool _willingToPlayGoalie(String uid, String goaliePos,
      Map<String, PlayerPreference> preferences,
      Map<String, List<String>> sportCategories) {
    final pref = preferences[uid];
    if (pref == null || !pref.hasPreferences) return true;
    return pref.preferredPositions.any((p) =>
        p == 'Any' ||
        p == goaliePos ||
        (sportCategories[p]?.contains(goaliePos) ?? false));
  }

  /// Returns match priority (0=exact, 1=category, 2=Any) or -1 if no match.
  static int _matchPriority(
      String position, List<String> prefs,
      Map<String, List<String>> sportCategories) {
    var best = -1;
    for (final pref in prefs) {
      if (pref == 'Any') {
        if (best < 0) best = 2;
      } else if (pref == position) {
        return 0; // exact match — can't do better
      } else {
        final cats = sportCategories[pref];
        if (cats != null && cats.contains(position)) {
          if (best < 0 || best > 1) best = 1;
        }
      }
    }
    return best;
  }
}

class _Candidate {
  final String uid;
  final int    priority;
  final double score;
  _Candidate(this.uid, this.priority, this.score);
}
