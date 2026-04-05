import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/data/user_repository.dart';
import '../../data/event_repository.dart';
import '../../domain/availability.dart';
import '../../domain/event.dart';

// Loads past events + this player's availability in parallel.
final _attendanceProvider = FutureProvider.autoDispose
    .family<_AttendanceData, ({String teamId, String userId})>(
  (ref, args) async {
    final repo   = ref.read(eventRepositoryProvider);
    final events = await repo.fetchPastTeamEvents(args.teamId);
    final avails = await repo.fetchPlayerAvailabilityForEvents(
        events.map((e) => e.eventId).toList(), args.userId);
    final byEvent = {for (final a in avails) a.eventId: a.response};
    return _AttendanceData(events: events, byEvent: byEvent);
  },
);

final _playerNameProvider =
    FutureProvider.autoDispose.family<String, String>((ref, uid) async {
  final user = await ref.read(userRepositoryProvider).getUser(uid);
  return user?.name ?? uid;
});

class _AttendanceData {
  final List<Event> events;
  final Map<String, AvailabilityResponse> byEvent;
  const _AttendanceData({required this.events, required this.byEvent});
}

class PlayerAttendanceScreen extends ConsumerWidget {
  final String teamId;
  final String userId;
  const PlayerAttendanceScreen(
      {super.key, required this.teamId, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(_playerNameProvider(userId));
    final dataAsync = ref.watch(_attendanceProvider((teamId: teamId, userId: userId)));

    final name = nameAsync.valueOrNull ?? '...';

    return Scaffold(
      appBar: AppBar(title: Text('$name — Attendance')),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (data) => _AttendanceBody(data: data),
      ),
    );
  }
}

class _AttendanceBody extends StatelessWidget {
  final _AttendanceData data;
  const _AttendanceBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final events  = data.events;
    final byEvent = data.byEvent;

    if (events.isEmpty) {
      return const Center(child: Text('No past events for this team.'));
    }

    final yes   = events.where((e) => byEvent[e.eventId] == AvailabilityResponse.yes).length;
    final no    = events.where((e) => byEvent[e.eventId] == AvailabilityResponse.no).length;
    final maybe = events.where((e) => byEvent[e.eventId] == AvailabilityResponse.maybe).length;
    final none  = events.length - yes - no - maybe;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary card ──────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Summary — ${events.length} past events',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(label: 'Yes',     value: yes,   color: Colors.green),
                    _StatChip(label: 'No',      value: no,    color: Colors.red),
                    _StatChip(label: 'Maybe',   value: maybe, color: Colors.orange),
                    _StatChip(label: 'No reply',value: none,  color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: events.isEmpty ? 0 : yes / events.length,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: Colors.green,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 4),
                Text(
                  '${events.isEmpty ? 0 : (yes * 100 ~/ events.length)}% confirmed available',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Per-event list ────────────────────────────────────────────────
        Text('Events', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...events.map((e) {
          final response = byEvent[e.eventId];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: _responseColor(response)?.withValues(alpha: 0.15),
              child: Text(
                response?.emoji ?? '—',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            title: Text(
              '${e.type.label} — ${DateFormat('EEE, MMM d, yyyy').format(e.date)}',
            ),
            subtitle: Text(
              response?.label ?? 'No response',
              style: TextStyle(color: _responseColor(response) ?? Colors.grey),
            ),
            trailing: Text(
              DateFormat('h:mm a').format(e.date),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }),
      ],
    );
  }

  Color? _responseColor(AvailabilityResponse? r) => switch (r) {
    AvailabilityResponse.yes   => Colors.green,
    AvailabilityResponse.no    => Colors.red,
    AvailabilityResponse.maybe => Colors.orange,
    null                       => null,
  };
}

class _StatChip extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}
