import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/teams/presentation/providers/teams_provider.dart';
import '../../domain/availability.dart';
import '../../domain/event.dart';
import '../providers/events_provider.dart';
import '../../../../features/shared/widgets/banner_ad_widget.dart';

class EventsScreen extends ConsumerWidget {
  final String teamId;
  const EventsScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync   = ref.watch(teamProvider(teamId));
    final eventsAsync = ref.watch(teamEventsProvider(teamId));
    final uid         = ref.watch(currentUserProvider)?.uid ?? '';
    final isAdmin     = teamAsync.valueOrNull?.isAdmin(uid) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(teamAsync.valueOrNull?.name ?? 'Events'),
      ),
      body: SafeArea(top: false, child: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (events) {
          final upcoming = events.where((e) => e.isUpcoming).toList();
          final past     = events.where((e) => !e.isUpcoming).toList();

          if (events.isEmpty) return _EmptyState(isAdmin: isAdmin, teamId: teamId);

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(tabs: [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Past'),
                ]),
                Expanded(
                  child: TabBarView(children: [
                    _EventList(events: upcoming, teamId: teamId, uid: uid,
                        emptyMsg: 'No upcoming events'),
                    _EventList(events: past,     teamId: teamId, uid: uid,
                        emptyMsg: 'No past events'),
                  ]),
                ),
              ],
            ),
          );
        },
      )),
      bottomNavigationBar: const BannerAdWidget(),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              icon:  const Icon(Icons.add),
              label: const Text('Add Event'),
              onPressed: () => context.push('/teams/$teamId/events/create'),
            )
          : null,
    );
  }
}

// ── Event list ────────────────────────────────────────────────────────────────

class _EventList extends ConsumerWidget {
  final List<Event> events;
  final String teamId, uid, emptyMsg;
  const _EventList({
    required this.events, required this.teamId,
    required this.uid,    required this.emptyMsg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return Center(child: Text(emptyMsg,
          style: TextStyle(color: Theme.of(context).colorScheme.outline)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _EventCard(event: events[i], teamId: teamId, uid: uid),
    );
  }
}

class _EventCard extends ConsumerWidget {
  final Event  event;
  final String teamId, uid;
  const _EventCard({required this.event, required this.teamId, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAvail  = ref.watch(myAvailabilityProvider(event.eventId)).valueOrNull;
    final dateFmt  = DateFormat('EEE, MMM d');
    final timeFmt  = DateFormat('h:mm a');

    return Opacity(
      opacity: event.isCancelled ? 0.5 : 1.0,
      child: Card(
        child: ListTile(
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(event.type.icon, style: const TextStyle(fontSize: 22)),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text('${event.type.label} — ${event.location}',
                    overflow: TextOverflow.ellipsis),
              ),
              if (event.isCancelled) ...[
                const SizedBox(width: 6),
                const Chip(
                  label: Text('Cancelled',
                      style: TextStyle(fontSize: 11, color: Colors.orange)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          subtitle: Text(
            '${dateFmt.format(event.date)} at ${timeFmt.format(event.date)}',
          ),
          trailing: myAvail != null
              ? Text(myAvail.response.emoji,
                  style: const TextStyle(fontSize: 20))
              : const Icon(Icons.chevron_right),
          onTap: () => context.push('/teams/$teamId/events/${event.eventId}'),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool   isAdmin;
  final String teamId;
  const _EmptyState({required this.isAdmin, required this.teamId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No events yet',
                style: Theme.of(context).textTheme.headlineSmall),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              const Text('Tap + Add Event to schedule your first game or practice.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon:  const Icon(Icons.add),
                label: const Text('Add Event'),
                onPressed: () => context.push('/teams/$teamId/events/create'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
