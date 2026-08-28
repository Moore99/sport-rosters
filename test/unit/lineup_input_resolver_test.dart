import 'package:flutter_test/flutter_test.dart';
import 'package:sports_rostering/features/events/domain/availability.dart';
import 'package:sports_rostering/features/lineups/application/lineup_input_resolver.dart';
import 'package:sports_rostering/features/teams/domain/admin_role.dart';

final _now = DateTime(2026, 1, 1);

Availability _avail(String uid, AvailabilityResponse response) => Availability(
      userId: uid,
      eventId: 'e1',
      teamId: 't1',
      response: response,
      updatedAt: _now,
    );

void main() {
  group('LineupInputResolver.eligiblePlayerUids', () {
    test('empty availability yields an empty list', () {
      expect(
        LineupInputResolver.eligiblePlayerUids(
          availability: const [],
          adminRoles: const {},
          teamPlayerUids: {'p1', 'p2'},
          teamAdminUids: {'a1'},
        ),
        isEmpty,
      );
    });

    test('yes and maybe are included; no is excluded', () {
      final result = LineupInputResolver.eligiblePlayerUids(
        availability: [
          _avail('p1', AvailabilityResponse.yes),
          _avail('p2', AvailabilityResponse.maybe),
          _avail('p3', AvailabilityResponse.no),
        ],
        adminRoles: const {},
        teamPlayerUids: {'p1', 'p2', 'p3'},
        teamAdminUids: const {},
      );
      expect(result, ['p1', 'p2']);
    });

    test('a uid with no availability entry (null RSVP) is excluded', () {
      final result = LineupInputResolver.eligiblePlayerUids(
        availability: [_avail('p1', AvailabilityResponse.yes)],
        adminRoles: const {},
        teamPlayerUids: {'p1', 'p2'},
        teamAdminUids: const {},
      );
      expect(result, ['p1']);
    });

    test('coach-only admin is excluded even with a yes RSVP', () {
      final result = LineupInputResolver.eligiblePlayerUids(
        availability: [
          _avail('a1', AvailabilityResponse.yes),
          _avail('p1', AvailabilityResponse.yes),
        ],
        adminRoles: const {'a1': AdminParticipation.coachOnly},
        teamPlayerUids: {'p1'},
        teamAdminUids: {'a1'},
      );
      expect(result, ['p1']);
    });

    test('coach-only exclusion wins even when the uid is also a team player',
        () {
      final result = LineupInputResolver.eligiblePlayerUids(
        availability: [_avail('x', AvailabilityResponse.yes)],
        adminRoles: const {'x': AdminParticipation.coachOnly},
        teamPlayerUids: {'x'},
        teamAdminUids: {'x'},
      );
      expect(result, isEmpty);
    });

    test('player and sometimes-participation admins are included', () {
      final result = LineupInputResolver.eligiblePlayerUids(
        availability: [
          _avail('a1', AvailabilityResponse.yes),
          _avail('a2', AvailabilityResponse.maybe),
        ],
        adminRoles: const {
          'a1': AdminParticipation.player,
          'a2': AdminParticipation.sometimes,
        },
        teamPlayerUids: const {},
        teamAdminUids: {'a1', 'a2'},
      );
      expect(result, ['a1', 'a2']);
    });

    test('a uid not in team.players or team.admins is excluded', () {
      final result = LineupInputResolver.eligiblePlayerUids(
        availability: [
          _avail('p1', AvailabilityResponse.yes),
          _avail('stranger', AvailabilityResponse.yes),
        ],
        adminRoles: const {},
        teamPlayerUids: {'p1'},
        teamAdminUids: const {},
      );
      expect(result, ['p1']);
    });

    test('result preserves availability order and is not de-duplicated', () {
      final result = LineupInputResolver.eligiblePlayerUids(
        availability: [
          _avail('p2', AvailabilityResponse.yes),
          _avail('p1', AvailabilityResponse.yes),
          _avail('p2', AvailabilityResponse.maybe),
        ],
        adminRoles: const {},
        teamPlayerUids: {'p1', 'p2'},
        teamAdminUids: const {},
      );
      expect(result, ['p2', 'p1', 'p2']);
    });
  });
}
