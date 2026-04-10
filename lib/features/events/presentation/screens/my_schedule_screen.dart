import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/event_repository.dart';
import '../../domain/availability.dart';
import '../../domain/event.dart';
import '../providers/events_provider.dart';

class MyScheduleScreen extends ConsumerWidget {
  const MyScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(myScheduleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule')),
      body: SafeArea(
        top: false,
        child: scheduleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (entries) {
            if (entries.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No upcoming events',
                          style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text(
                        'Events from all your teams will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => ref.refresh(myScheduleProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _ScheduleEventTile(entry: entries[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScheduleEventTile extends ConsumerWidget {
  final ScheduleEntry entry;
  const _ScheduleEventTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = entry.event;
    final team  = entry.team;
    final uid   = ref.watch(currentUserProvider)?.uid ?? '';

    final dateFmt = DateFormat('EEE, MMM d');
    final timeFmt = DateFormat('h:mm a');

    final myAvailAsync = ref.watch(myAvailabilityProvider(event.eventId));
    final myResponse   = myAvailAsync.valueOrNull?.response;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(event.type.icon, style: const TextStyle(fontSize: 24)),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${event.type.label} · ${team.name}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (myResponse != null)
            _RsvpChip(response: myResponse),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text('${dateFmt.format(event.date)}  ${timeFmt.format(event.date)}'),
          if (event.location.isNotEmpty)
            Text(event.location,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12)),
        ],
      ),
      trailing: event.allowSignups && event.rsvpOpen
          ? _QuickRsvpButton(event: event, uid: uid, current: myResponse, ref: ref)
          : const Icon(Icons.chevron_right),
      onTap: () => context.push(
        '/teams/${team.teamId}/events/${event.eventId}',
      ),
    );
  }
}

class _RsvpChip extends StatelessWidget {
  final AvailabilityResponse response;
  const _RsvpChip({required this.response});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${response.emoji} ${response.label}',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _QuickRsvpButton extends StatelessWidget {
  final Event event;
  final String uid;
  final AvailabilityResponse? current;
  final WidgetRef ref;
  const _QuickRsvpButton({
    required this.event,
    required this.uid,
    required this.current,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    // Show a compact Yes/No toggle when RSVP is open and user hasn't responded
    if (current == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _rsvpBtn(context, AvailabilityResponse.yes),
          _rsvpBtn(context, AvailabilityResponse.no),
        ],
      );
    }
    return const Icon(Icons.chevron_right);
  }

  Widget _rsvpBtn(BuildContext context, AvailabilityResponse r) {
    return IconButton(
      tooltip: r.label,
      icon: Text(r.emoji, style: const TextStyle(fontSize: 20)),
      onPressed: () {
        unawaited(ref.read(eventRepositoryProvider).setAvailability(
          Availability(
            userId:    uid,
            eventId:   event.eventId,
            teamId:    event.teamId,
            response:  r,
            updatedAt: DateTime.now(),
          ),
        ));
      },
    );
  }
}
