import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/export_service.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/teams/data/spares_repository.dart';
import '../../../../features/teams/presentation/providers/spares_provider.dart';
import '../../../../features/teams/presentation/providers/teams_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../features/lineups/presentation/providers/lineup_provider.dart';
import '../../data/event_repository.dart';
import '../../domain/availability.dart';
import '../../domain/event.dart';
import 'edit_event_screen.dart';
import '../providers/events_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  final String teamId;
  final String eventId;
  const EventDetailScreen(
      {super.key, required this.teamId, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));

    return eventAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (event) {
        if (event == null) {
          return const Scaffold(body: Center(child: Text('Event not found.')));
        }
        return _EventDetailView(event: event, teamId: teamId);
      },
    );
  }
}

class _EventDetailView extends ConsumerWidget {
  final Event event;
  final String teamId;
  const _EventDetailView({required this.event, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final teamAsync = ref.watch(teamProvider(teamId));
    final isAdmin = teamAsync.valueOrNull?.isAdmin(uid) ?? false;
    final myAvail =
        ref.watch(myAvailabilityProvider(event.eventId)).valueOrNull;
    final allAvail = isAdmin
        ? ref
                .watch(eventAvailabilityProvider((event.eventId, teamId)))
                .valueOrNull ??
            []
        : <Availability>[];

    final dateFmt = DateFormat('EEEE, MMMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(event.type.label, overflow: TextOverflow.ellipsis, maxLines: 1),
        actions: [
          // Lineup / Boat Seating button
          if (isAdmin)
            if (teamAsync.valueOrNull?.sport == 'Dragon Boating')
              IconButton(
                icon: const Icon(Icons.directions_boat_outlined),
                tooltip: 'Boat Seating',
                onPressed: () => context.push(
                    '/teams/$teamId/events/${event.eventId}/boat-seating'),
              )
            else
              IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: 'Lineup',
                onPressed: () => context
                    .push('/teams/$teamId/events/${event.eventId}/lineup'),
              ),
          // Notify team about this event — admin only
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notify Team',
              onPressed: () => context.push(
                '/teams/$teamId/notify',
                extra: event.eventId,
              ),
            ),
          // Drop-in button
          if (event.isDropIn)
            IconButton(
              icon: const Icon(Icons.people_alt_outlined),
              tooltip: 'Drop-in',
              onPressed: () =>
                  context.push('/teams/$teamId/events/${event.eventId}/dropin'),
            ),
          // Edit / Delete — admin only
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  if (event.recurrenceGroupId != null) {
                    final editAll = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Edit Recurring Event'),
                        content: const Text(
                            'Edit just this event, or update all events in the series?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: const Text('Cancel'),
                          ),
                          OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('This Event'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('All in Series'),
                          ),
                        ],
                      ),
                    );
                    if (editAll == null || !context.mounted) return;
                    context.push(
                      '/teams/$teamId/events/${event.eventId}/edit',
                      extra: editAll
                          ? EditEventArgs(event: event, editSeries: true)
                          : event,
                    );
                  } else {
                    context.push(
                      '/teams/$teamId/events/${event.eventId}/edit',
                      extra: event,
                    );
                  }
                } else if (v == 'copy') {
                  context.push(
                    '/teams/$teamId/events/create',
                    extra: event,
                  );
                } else if (v == 'cancel') {
                  final isCancelling = !event.isCancelled;
                  if (event.recurrenceGroupId != null) {
                    final scope = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(isCancelling
                            ? 'Cancel Recurring Event'
                            : 'Restore Recurring Event'),
                        content: Text(isCancelling
                            ? 'Cancel just this event, or all events in the series?'
                            : 'Restore just this event, or all events in the series?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: const Text('Dismiss'),
                          ),
                          OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop('one'),
                            child: const Text('This Event'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop('all'),
                            child: const Text('All in Series'),
                          ),
                        ],
                      ),
                    );
                    if (scope == null || !context.mounted) return;
                    final repo = ref.read(eventRepositoryProvider);
                    if (scope == 'all') {
                      await repo.cancelEventSeries(
                          event.recurrenceGroupId!,
                          cancelled: isCancelling);
                    } else {
                      await repo.cancelEvent(event.eventId,
                          cancelled: isCancelling);
                    }
                  } else {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                            isCancelling ? 'Cancel Event?' : 'Restore Event?'),
                        content: Text(isCancelling
                            ? 'Members will still see the event but it will be marked as cancelled. Reminders will not be sent.'
                            : 'This will restore the event and re-enable reminders.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Dismiss'),
                          ),
                          FilledButton(
                            style: isCancelling
                                ? FilledButton.styleFrom(
                                    backgroundColor: Colors.orange)
                                : null,
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(isCancelling ? 'Cancel Event' : 'Restore'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(eventRepositoryProvider).cancelEvent(
                          event.eventId,
                          cancelled: isCancelling);
                    }
                  }
                } else if (v == 'delete') {
                  if (event.recurrenceGroupId != null) {
                    final deleteAll = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Recurring Event'),
                        content: const Text(
                            'Delete just this event, or all events in the series?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: const Text('Cancel'),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(ctx).colorScheme.error),
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('This Event'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(ctx).colorScheme.error),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('All in Series'),
                          ),
                        ],
                      ),
                    );
                    if (deleteAll == null || !context.mounted) return;
                    if (deleteAll) {
                      await ref.read(eventRepositoryProvider)
                          .deleteEventSeries(event.recurrenceGroupId!);
                    } else {
                      await ref.read(eventRepositoryProvider)
                          .deleteEvent(event.eventId);
                    }
                    if (context.mounted) context.pop();
                  } else {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Event?'),
                        content: const Text(
                            'This will permanently delete the event and all availability records.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(ctx).colorScheme.error,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(eventRepositoryProvider)
                          .deleteEvent(event.eventId);
                      if (context.mounted) context.pop();
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit Event'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    leading: Icon(Icons.copy_outlined),
                    title: Text('Copy Event'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'cancel',
                  child: ListTile(
                    leading: Icon(
                      event.isCancelled
                          ? Icons.event_available_outlined
                          : Icons.event_busy_outlined,
                      color: event.isCancelled ? null : Colors.orange,
                    ),
                    title: Text(
                      event.isCancelled ? 'Restore Event' : 'Cancel Event',
                      style: TextStyle(
                          color: event.isCancelled ? null : Colors.orange),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Delete Event',
                        style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Event header card ──────────────────────────────────────────
              _HeaderCard(
                event: event,
                dateFmt: dateFmt,
                timeFmt: timeFmt,
                teamName: teamAsync.valueOrNull?.name ?? 'Team',
              ),
              const SizedBox(height: 20),

              // ── RSVP (players + admins can respond) ───────────────────────
              if (event.allowSignups) ...[
                Row(
                  children: [
                    Text('Your RSVP',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (event.rsvpDeadline != null)
                      Text(
                        event.rsvpOpen
                            ? 'Closes ${DateFormat('MMM d h:mm a').format(event.rsvpDeadline!)}'
                            : 'RSVP closed',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: event.rsvpOpen
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _RsvpButtons(
                  current: myAvail?.response,
                  disabled: !event.rsvpOpen,
                  onSelect: (r) async {
                    try {
                      await ref.read(eventRepositoryProvider).setAvailability(
                            Availability(
                              userId: uid,
                              eventId: event.eventId,
                              teamId: teamId,
                              response: r,
                              updatedAt: DateTime.now(),
                            ),
                          );
                    } on EventFullException {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'This event is full. Contact your coach to be added to the spares list.')),
                        );
                      }
                      return;
                    }
                    unawaited(ref
                        .read(analyticsServiceProvider)
                        .logAvailabilitySet(r.name));
                    // Prompt for in-app review after a positive RSVP (OS
                    // decides whether to actually show the dialog).
                    if (r == AvailabilityResponse.yes) {
                      unawaited(() async {
                        final review = InAppReview.instance;
                        if (await review.isAvailable()) {
                          await review.requestReview();
                        }
                      }());
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],

              // ── My lineup position (non-admin players only) ───────────────
              if (!isAdmin) ...[
                _MyLineupCard(eventId: event.eventId, uid: uid),
                const SizedBox(height: 8),
              ],

              // ── Game result (game events only) ────────────────────────────
              if (event.type == EventType.game) ...[
                _GameResultSection(event: event, isAdmin: isAdmin),
                const SizedBox(height: 8),
              ],

              // ── Availability summary (admin) ────────────────────────────────
              if (isAdmin) ...[
                Row(
                  children: [
                    Text('Availability',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (allAvail.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.download_outlined),
                        tooltip: 'Export CSV',
                        onPressed: () =>
                            _exportCsv(context, ref, event, allAvail),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _AvailabilitySummary(
                  allAvail: allAvail,
                  teamAsync: teamAsync,
                  minPlayers: event.minPlayers,
                ),
                const SizedBox(height: 16),
                _NotifySparesButton(
                  event: event,
                  teamId: teamId,
                  yesCount: allAvail
                      .where((a) => a.response == AvailabilityResponse.yes)
                      .length,
                ),
              ],
            ],
          )),
    );
  }
}

// ── My lineup card ─────────────────────────────────────────────────────────────

class _MyLineupCard extends ConsumerWidget {
  final String eventId;
  final String uid;
  const _MyLineupCard({required this.eventId, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineupAsync = ref.watch(lineupProvider(eventId));
    return lineupAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (lineup) {
        if (lineup == null) return const SizedBox.shrink();

        // Find position in single-team or sub-team assignments
        String? position;
        int? subTeamIndex;

        if (lineup.subTeams.isNotEmpty) {
          for (int i = 0; i < lineup.subTeams.length; i++) {
            final entry = lineup.subTeams[i].entries
                .where((e) => e.value == uid)
                .firstOrNull;
            if (entry != null) {
              position = entry.key;
              subTeamIndex = i + 1;
              break;
            }
          }
        } else {
          final entry = lineup.assignments.entries
              .where((e) => e.value == uid)
              .firstOrNull;
          if (entry != null) position = entry.key;
        }

        if (position == null) return const SizedBox.shrink();

        return Card(
          child: ListTile(
            leading: const Icon(Icons.sports),
            title: const Text('Your Position'),
            subtitle: Text(
              subTeamIndex != null
                  ? 'Team $subTeamIndex · $position'
                  : position,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      },
    );
  }
}

class _NotifySparesButton extends ConsumerWidget {
  final Event event;
  final String teamId;
  final int yesCount;
  const _NotifySparesButton({
    required this.event,
    required this.teamId,
    required this.yesCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sparesAsync = ref.watch(teamSparesProvider(teamId));
    final sparesCount = sparesAsync.valueOrNull?.length ?? 0;
    final isBelowMin = yesCount < event.minPlayers;

    if (!isBelowMin || sparesCount == 0) {
      return const SizedBox.shrink();
    }

    return FilledButton.tonalIcon(
      icon: const Icon(Icons.person_add),
      label: Text('Notify Spares ($sparesCount available)'),
      onPressed: () => _notifySpares(context, ref),
    );
  }

  Future<void> _notifySpares(BuildContext context, WidgetRef ref) async {
    final teamName =
        ref.read(teamProvider(event.teamId)).valueOrNull?.name ?? 'Your Team';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notify Spares'),
        content: Text(
            'Send notifications to spares for the ${event.type.label.toLowerCase()} on ${DateFormat.MMMd().format(event.date)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Notify'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final sent = await ref.read(sparesRepositoryProvider).notifySpares(
          eventId: event.eventId,
          teamId: event.teamId,
          teamName: teamName,
          eventDate: event.date,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                sent > 0 ? 'Notified $sent spares' : 'No spares notified')),
      );
    }
  }
}

// ── CSV export ─────────────────────────────────────────────────────────────────

Future<void> _exportCsv(
  BuildContext context,
  WidgetRef ref,
  Event event,
  List<Availability> allAvail,
) async {
  final userRepo = ref.read(userRepositoryProvider);
  final teamName =
      ref.read(teamProvider(event.teamId)).valueOrNull?.name ?? 'Team';

  final rows = <({String name, String response})>[];
  for (final a in allAvail) {
    final user = await userRepo.getUser(a.userId);
    final name = user?.name.isNotEmpty == true ? user!.name : a.userId;
    rows.add((name: name, response: a.response.label));
  }
  // Sort: Yes → Maybe → No
  const order = {'Yes': 0, 'Maybe': 1, 'No': 2};
  rows.sort(
      (a, b) => (order[a.response] ?? 9).compareTo(order[b.response] ?? 9));

  await ExportService.shareAvailabilityCsv(
    teamName: teamName,
    eventLabel: event.type.label,
    eventDate: event.date,
    rows: rows,
  );
}

// ── Header card ────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Event event;
  final DateFormat dateFmt, timeFmt;
  final String teamName;
  const _HeaderCard({
    required this.event,
    required this.dateFmt,
    required this.timeFmt,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(event.type.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(event.type.label,
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                if (event.isCancelled)
                  Chip(
                    label: const Text('Cancelled'),
                    backgroundColor: Colors.orange.withValues(alpha: 0.15),
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                    labelStyle: const TextStyle(color: Colors.orange),
                  )
                else if (!event.isUpcoming)
                  Chip(
                    label: const Text('Past'),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
              ],
            ),
            if (event.isUpcoming) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ExportService.shareEventToCalendar(
                  teamName: teamName,
                  event: event,
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Add to Calendar'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
            const Divider(height: 24),
            _InfoRow(Icons.calendar_today, dateFmt.format(event.date)),
            const SizedBox(height: 8),
            _InfoRow(Icons.access_time, timeFmt.format(event.date)),
            const SizedBox(height: 8),
            _InfoRow(Icons.location_on_outlined, event.location),
            const SizedBox(height: 8),
            _InfoRow(Icons.people_outline,
                '${event.minPlayers}–${event.maxPlayers} players'),
            if (event.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _InfoRow(Icons.notes_outlined, event.notes!),
            ],
            if (event.gameResult != null) ...[
              const Divider(height: 24),
              _GameResultBadge(result: event.gameResult!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

// ── RSVP buttons ───────────────────────────────────────────────────────────────

class _RsvpButtons extends StatelessWidget {
  final AvailabilityResponse? current;
  final bool disabled;
  final ValueChanged<AvailabilityResponse> onSelect;
  const _RsvpButtons(
      {this.current, this.disabled = false, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AvailabilityResponse>(
      segments: AvailabilityResponse.values
          .map((r) => ButtonSegment(
                value: r,
                label: Text(r.label),
                icon: Text(r.emoji),
                enabled: !disabled,
              ))
          .toList(),
      selected: current != null ? {current!} : {},
      emptySelectionAllowed: true,
      onSelectionChanged: disabled
          ? null
          : (s) {
              if (s.isNotEmpty) onSelect(s.first);
            },
    );
  }
}

// ── Availability summary (admin) ───────────────────────────────────────────────

class _AvailabilitySummary extends ConsumerWidget {
  final List<Availability> allAvail;
  final AsyncValue teamAsync;
  final int minPlayers;
  const _AvailabilitySummary({
    required this.allAvail,
    required this.teamAsync,
    required this.minPlayers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yes =
        allAvail.where((a) => a.response == AvailabilityResponse.yes).toList();
    final no =
        allAvail.where((a) => a.response == AvailabilityResponse.no).toList();
    final maybe = allAvail
        .where((a) => a.response == AvailabilityResponse.maybe)
        .toList();
    final yesCount = yes.length;
    final hasQuorum = yesCount >= minPlayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quorum indicator
        Card(
          color: hasQuorum
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(hasQuorum ? Icons.check_circle : Icons.warning_rounded),
                const SizedBox(width: 8),
                Text(hasQuorum
                    ? '$yesCount confirmed — quorum met (min $minPlayers)'
                    : '$yesCount confirmed — need $minPlayers (${minPlayers - yesCount} more)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Response groups
        _ResponseGroup(label: 'Yes', emoji: '✅', responses: yes, ref: ref),
        _ResponseGroup(label: 'No', emoji: '❌', responses: no, ref: ref),
        _ResponseGroup(label: 'Maybe', emoji: '❓', responses: maybe, ref: ref),
      ],
    );
  }
}

class _ResponseGroup extends StatelessWidget {
  final String label, emoji;
  final List<Availability> responses;
  final WidgetRef ref;
  const _ResponseGroup({
    required this.label,
    required this.emoji,
    required this.responses,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('$emoji $label (${responses.length})',
              style: Theme.of(context).textTheme.labelLarge),
        ),
        ...responses.map((a) => _UserNameTile(userId: a.userId, ref: ref)),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Game result badge (inside header card) ────────────────────────────────────

class _GameResultBadge extends StatelessWidget {
  final GameResult result;
  const _GameResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.isWin
        ? Colors.green
        : result.isLoss
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.outline;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            result.resultLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${result.ourScore} – ${result.opponentScore} vs ${result.opponentName}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ── Game result section (body) ─────────────────────────────────────────────────

class _GameResultSection extends ConsumerWidget {
  final Event  event;
  final bool   isAdmin;
  const _GameResultSection({required this.event, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasResult  = event.gameResult != null;
    final isPast     = !event.isUpcoming;

    // Players only see this section if there's a result to show.
    if (!isAdmin && !hasResult) return const SizedBox.shrink();
    // Admins see it for past games only.
    if (isAdmin && !isPast && !hasResult) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Result', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (isAdmin && isPast)
              TextButton.icon(
                icon: Icon(hasResult ? Icons.edit_outlined : Icons.add),
                label: Text(hasResult ? 'Edit' : 'Log Result'),
                onPressed: () => _showResultDialog(context, ref),
              ),
          ],
        ),
        if (!hasResult)
          Text('No result logged yet.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }

  Future<void> _showResultDialog(BuildContext context, WidgetRef ref) async {
    final existing     = event.gameResult;
    final opponentCtrl = TextEditingController(text: existing?.opponentName ?? '');
    var ourScore       = existing?.ourScore ?? 0;
    var theirScore     = existing?.opponentScore ?? 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing != null ? 'Edit Result' : 'Log Result'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: opponentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opponent name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ScoreCounter(
                      label: 'Us',
                      value: ourScore,
                      onChanged: (v) => setLocal(() => ourScore = v),
                    ),
                    Text('–',
                        style: Theme.of(ctx).textTheme.headlineMedium),
                    _ScoreCounter(
                      label: 'Them',
                      value: theirScore,
                      onChanged: (v) => setLocal(() => theirScore = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await ref
                      .read(eventRepositoryProvider)
                      .updateGameResult(event.eventId, null);
                },
                child: const Text('Clear'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = opponentCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();
                await ref.read(eventRepositoryProvider).updateGameResult(
                      event.eventId,
                      GameResult(
                        opponentName:  name,
                        ourScore:      ourScore,
                        opponentScore: theirScore,
                      ),
                    );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    opponentCtrl.dispose();
  }
}

class _ScoreCounter extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _ScoreCounter(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 36,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

/// Resolves a userId to a display name via Firestore (cached by Riverpod).
final _userNameProvider =
    FutureProvider.family<String, String>((ref, uid) async {
  final user = await ref.read(userRepositoryProvider).getUser(uid);
  return user?.name.isNotEmpty == true ? user!.name : uid;
});

class _UserNameTile extends ConsumerWidget {
  final String userId;
  final WidgetRef ref;
  const _UserNameTile({required this.userId, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(_userNameProvider(userId));
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius:
            14 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
        child: const Icon(Icons.person, size: 16),
      ),
      title: Text(nameAsync.valueOrNull ?? userId,
          overflow: TextOverflow.ellipsis),
    );
  }
}
