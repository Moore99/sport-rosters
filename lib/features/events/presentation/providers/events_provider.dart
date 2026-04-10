import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/teams/domain/team.dart';
import '../../../../features/teams/presentation/providers/teams_provider.dart';
import '../../data/event_repository.dart';
import '../../domain/availability.dart';
import '../../domain/event.dart';

/// All events for a team, ordered by date.
final teamEventsProvider =
    StreamProvider.family<List<Event>, String>((ref, teamId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(eventRepositoryProvider).watchTeamEvents(teamId);
});

/// Single event stream.
final eventProvider =
    StreamProvider.family<Event?, String>((ref, eventId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(null);
  return ref.read(eventRepositoryProvider).watchEvent(eventId);
});

/// Current user's RSVP for a specific event.
final myAvailabilityProvider =
    StreamProvider.family<Availability?, String>((ref, eventId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(null);
  return ref.read(eventRepositoryProvider).watchMyAvailability(eventId, uid);
});

/// Upcoming events across all of the user's teams, sorted by date.
/// Returns list of (event, team) records for display in My Schedule.
typedef ScheduleEntry = ({Event event, Team team});

final myScheduleProvider = FutureProvider<List<ScheduleEntry>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return [];
  final teams = await ref.watch(userTeamsProvider.future);
  if (teams.isEmpty) return [];

  final repo = ref.read(eventRepositoryProvider);
  final nested = await Future.wait(
    teams.map((team) async {
      final events = await repo.fetchUpcomingTeamEvents(team.teamId);
      return events.map<ScheduleEntry>((e) => (event: e, team: team)).toList();
    }),
  );
  final all = nested.expand((e) => e).toList()
    ..sort((a, b) => a.event.date.compareTo(b.event.date));
  return all;
});

/// All RSVPs for an event (admin use).
/// Pass (eventId, teamId) as a record so the repository can filter by teamId,
/// allowing Firestore security rules to evaluate resource.data.teamId.
final eventAvailabilityProvider =
    StreamProvider.family<List<Availability>, (String, String)>((ref, args) {
  final (eventId, teamId) = args;
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value([]);
  return ref.read(eventRepositoryProvider).watchEventAvailability(eventId, teamId);
});
