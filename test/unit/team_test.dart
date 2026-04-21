import 'package:flutter_test/flutter_test.dart';
import 'package:sports_rostering/features/teams/domain/team.dart';

void main() {
  final _now = DateTime(2026, 1, 1);

  Team _make({
    List<String> admins  = const ['admin1'],
    List<String> players = const ['player1', 'player2'],
    bool archived        = false,
  }) =>
      Team(
        teamId:       'team1',
        name:         'Test Team',
        sport:        'Ice Hockey',
        admins:       admins,
        players:      players,
        minPlayers:   1,
        maxPlayers:   20,
        dropInEnabled: false,
        createdAt:    _now,
        archived:     archived,
      );

  group('Team.isAdmin', () {
    test('true for admin uid', () => expect(_make().isAdmin('admin1'), isTrue));
    test('false for player uid', () => expect(_make().isAdmin('player1'), isFalse));
    test('false for unknown uid', () => expect(_make().isAdmin('nobody'), isFalse));
  });

  group('Team.isMember', () {
    test('true for admin', () => expect(_make().isMember('admin1'), isTrue));
    test('true for player', () => expect(_make().isMember('player1'), isTrue));
    test('false for unknown', () => expect(_make().isMember('nobody'), isFalse));
  });

  group('Team.totalMembers', () {
    test('counts admins + players', () => expect(_make().totalMembers, equals(3)));
    test('handles empty', () => expect(_make(admins: [], players: []).totalMembers, equals(0)));
    test('admin-only', () => expect(_make(players: []).totalMembers, equals(1)));
  });

  group('Team.archived', () {
    test('defaults false', () => expect(_make().archived, isFalse));
    test('can be true',    () => expect(_make(archived: true).archived, isTrue));
  });
}
