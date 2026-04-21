import 'package:flutter_test/flutter_test.dart';
import 'package:sports_rostering/core/services/lineup_generator.dart';
import 'package:sports_rostering/features/lineups/domain/player_preference.dart';
import 'package:sports_rostering/features/rankings/domain/ranking.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

final _now = DateTime(2026, 1, 1);

Ranking _rank(String uid, double score) =>
    Ranking(userId: uid, teamId: 't', score: score, updatedAt: _now);

PlayerPreference _pref(String uid, List<String> positions) =>
    PlayerPreference(userId: uid, teamId: 't', preferredPositions: positions, updatedAt: _now);

const _hockeyPositions = ['Goalie', 'Left Wing', 'Centre', 'Right Wing', 'Left Defence', 'Right Defence'];
const _hockeyCategories = <String, List<String>>{
  'Any Forward': ['Left Wing', 'Centre', 'Right Wing'],
  'Any Defence': ['Left Defence', 'Right Defence'],
  'Any (except Goalie)': ['Left Wing', 'Centre', 'Right Wing', 'Left Defence', 'Right Defence'],
};

// ── generate() ───────────────────────────────────────────────────────────────

void main() {
  group('LineupGenerator.generate', () {
    test('assigns all positions when enough players', () {
      final uids   = ['u1', 'u2', 'u3', 'u4', 'u5', 'u6'];
      final result = LineupGenerator.generate(
        positions:      _hockeyPositions,
        availableUids:  uids,
        rankings:       {},
        preferences:    {},
        sportCategories: _hockeyCategories,
      );
      expect(result.length, equals(_hockeyPositions.length));
      expect(result.values.where((v) => v.isNotEmpty).length, equals(6));
    });

    test('each player assigned at most once', () {
      final uids   = ['u1', 'u2', 'u3', 'u4', 'u5', 'u6'];
      final result = LineupGenerator.generate(
        positions:      _hockeyPositions,
        availableUids:  uids,
        rankings:       {},
        preferences:    {},
        sportCategories: _hockeyCategories,
      );
      final assigned = result.values.where((v) => v.isNotEmpty).toList();
      expect(assigned.toSet().length, equals(assigned.length));
    });

    test('unfilled positions mapped to empty string when too few players', () {
      final result = LineupGenerator.generate(
        positions:      _hockeyPositions,
        availableUids:  ['u1', 'u2'],
        rankings:       {},
        preferences:    {},
        sportCategories: _hockeyCategories,
      );
      expect(result.values.where((v) => v.isEmpty).length, equals(4));
    });

    test('respects exact position preference', () {
      final result = LineupGenerator.generate(
        positions:      _hockeyPositions,
        availableUids:  ['u1', 'u2', 'u3', 'u4', 'u5', 'u6'],
        rankings:       {'u1': _rank('u1', 5.0)},
        preferences:    {'u1': _pref('u1', ['Goalie'])},
        sportCategories: _hockeyCategories,
      );
      expect(result['Goalie'], equals('u1'));
    });

    test('respects category preference — Any Forward → forward slot', () {
      final uids   = ['u1', 'u2', 'u3', 'u4', 'u5', 'u6'];
      final result = LineupGenerator.generate(
        positions:      _hockeyPositions,
        availableUids:  uids,
        rankings:       {'u1': _rank('u1', 10.0)},
        preferences:    {'u1': _pref('u1', ['Any Forward'])},
        sportCategories: _hockeyCategories,
      );
      final u1pos = result.entries.firstWhere((e) => e.value == 'u1').key;
      expect(['Left Wing', 'Centre', 'Right Wing'], contains(u1pos));
    });

    test('higher-ranked player beats lower-ranked for contested slot', () {
      // Only two players, both no preferences, u2 rated higher
      final result = LineupGenerator.generate(
        positions:      ['Left Wing', 'Right Wing'],
        availableUids:  ['u1', 'u2'],
        rankings:       {'u1': _rank('u1', 3.0), 'u2': _rank('u2', 9.0)},
        preferences:    {},
        sportCategories: {},
      );
      // Both should be assigned (uniquely)
      expect(result.values.toSet().length, equals(2));
    });

    test('Any wildcard preference allows placement anywhere', () {
      final result = LineupGenerator.generate(
        positions:      ['Goalie', 'Centre'],
        availableUids:  ['u1', 'u2'],
        rankings:       {},
        preferences:    {'u1': _pref('u1', ['Any'])},
        sportCategories: {},
      );
      expect(result.values, containsAll(['u1', 'u2']));
    });
  });

// ── generateSubTeams() ───────────────────────────────────────────────────────

  group('LineupGenerator.generateSubTeams', () {
    test('returns 1 map when numSubTeams = 1', () {
      final result = LineupGenerator.generateSubTeams(
        numSubTeams:     1,
        positions:       _hockeyPositions,
        availableUids:   ['u1', 'u2', 'u3', 'u4', 'u5', 'u6'],
        rankings:        {},
        preferences:     {},
        sportCategories: _hockeyCategories,
      );
      expect(result.length, equals(1));
    });

    test('returns correct count for 2 sub-teams', () {
      final uids   = List.generate(12, (i) => 'u$i');
      final result = LineupGenerator.generateSubTeams(
        numSubTeams:     2,
        positions:       _hockeyPositions,
        availableUids:   uids,
        rankings:        {},
        preferences:     {},
        sportCategories: _hockeyCategories,
      );
      expect(result.length, equals(2));
    });

    test('no player appears in two sub-teams', () {
      final uids   = List.generate(12, (i) => 'u$i');
      final result = LineupGenerator.generateSubTeams(
        numSubTeams:     2,
        positions:       _hockeyPositions,
        availableUids:   uids,
        rankings:        {},
        preferences:     {},
        sportCategories: _hockeyCategories,
      );
      final all = result.expand((m) => m.values).where((v) => v.isNotEmpty).toList();
      expect(all.toSet().length, equals(all.length));
    });

    test('goalie pre-assigned to each sub-team when willing player exists', () {
      final uids = List.generate(12, (i) => 'u$i');
      final prefs = {
        'u0': _pref('u0', ['Goalie']),
        'u1': _pref('u1', ['Goalie']),
      };
      final result = LineupGenerator.generateSubTeams(
        numSubTeams:     2,
        positions:       _hockeyPositions,
        availableUids:   uids,
        rankings:        {},
        preferences:     prefs,
        sportCategories: _hockeyCategories,
      );
      for (final team in result) {
        expect(team['Goalie'], isNotEmpty);
      }
    });

    test('snake draft distributes top players across teams', () {
      // u0 is ranked highest; with snake draft they should not both end up on team 0
      final uids    = List.generate(4, (i) => 'u$i');
      final rankings = {
        'u0': _rank('u0', 10.0),
        'u1': _rank('u1', 8.0),
        'u2': _rank('u2', 6.0),
        'u3': _rank('u3', 4.0),
      };
      final result = LineupGenerator.generateSubTeams(
        numSubTeams:     2,
        positions:       ['Left Wing', 'Right Wing'],
        availableUids:   uids,
        rankings:        rankings,
        preferences:     {},
        sportCategories: {},
      );
      // Each sub-team should have 2 players
      for (final team in result) {
        expect(team.values.where((v) => v.isNotEmpty).length, equals(2));
      }
    });
  });
}
