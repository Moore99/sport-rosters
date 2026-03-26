import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/export_service.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/teams/presentation/providers/teams_provider.dart';
import '../../data/event_repository.dart';
import '../../domain/availability.dart';
import '../../domain/event.dart';
import '../providers/events_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  final String teamId;
  final String eventId;
  const EventDetailScreen({super.key, required this.teamId, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));

    return eventAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
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
  final Event  event;
  final String teamId;
  const _EventDetailView({required this.event, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid      = ref.watch(currentUserProvider)?.uid ?? '';
    final teamAsync = ref.watch(teamProvider(teamId));
    final isAdmin   = teamAsync.valueOrNull?.isAdmin(uid) ?? false;
    final myAvail   = ref.watch(myAvailabilityProvider(event.eventId)).valueOrNull;
    final allAvail  = isAdmin
        ? ref.watch(eventAvailabilityProvider((event.eventId, teamId))).valueOrNull ?? []
        : <Availability>[];

    final dateFmt   = DateFormat('EEEE, MMMM d, yyyy');
    final timeFmt   = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(event.type.label),
        actions: [
          // Lineup / Boat Seating button
          if (isAdmin)
            if (teamAsync.valueOrNull?.sport == 'Dragon Boating')
              IconButton(
                icon:    const Icon(Icons.directions_boat_outlined),
                tooltip: 'Boat Seating',
                onPressed: () =>
                    context.push('/teams/$teamId/events/${event.eventId}/boat-seating'),
              )
            else
              IconButton(
                icon:    const Icon(Icons.list_alt),
                tooltip: 'Lineup',
                onPressed: () =>
                    context.push('/teams/$teamId/events/${event.eventId}/lineup'),
              ),
          // Notify team about this event — admin only
          if (isAdmin)
            IconButton(
              icon:    const Icon(Icons.notifications_outlined),
              tooltip: 'Notify Team',
              onPressed: () => context.push(
                '/teams/$teamId/notify',
                extra: event.eventId,
              ),
            ),
          // Drop-in button
          if (event.isDropIn)
            IconButton(
              icon:    const Icon(Icons.people_alt_outlined),
              tooltip: 'Drop-in',
              onPressed: () =>
                  context.push('/teams/$teamId/events/${event.eventId}/dropin'),
            ),
          // Edit / Delete — admin only
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  context.push(
                    '/teams/$teamId/events/${event.eventId}/edit',
                    extra: event,
                  );
                } else if (v == 'delete') {
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
                            backgroundColor:
                                Theme.of(ctx).colorScheme.error,
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
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit Event'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: Colors.red),
                    title: Text('Delete Event',
                        style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(top: false, child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Event header card ──────────────────────────────────────────
          _HeaderCard(event: event, dateFmt: dateFmt, timeFmt: timeFmt),
          const SizedBox(height: 20),

          // ── RSVP (players + admins can respond) ───────────────────────
          if (event.allowSignups) ...[
            Row(
              children: [
                Text('Your RSVP', style: Theme.of(context).textTheme.titleMedium),
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
              current:  myAvail?.response,
              disabled: !event.rsvpOpen,
              onSelect: (r) => ref.read(eventRepositoryProvider).setAvailability(
                Availability(
                  userId:    uid,
                  eventId:   event.eventId,
                  teamId:    teamId,
                  response:  r,
                  updatedAt: DateTime.now(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Availability summary (admin) ────────────────────────────────
          if (isAdmin) ...[
            Row(
              children: [
                Text('Availability', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (allAvail.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: 'Export CSV',
                    onPressed: () => _exportCsv(context, ref, event, allAvail),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _AvailabilitySummary(
              allAvail:   allAvail,
              teamAsync:  teamAsync,
              minPlayers: event.minPlayers,
            ),
          ],
        ],
      )),
    );
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
  final teamName = ref.read(teamProvider(event.teamId)).valueOrNull?.name ?? 'Team';

  final rows = <({String name, String response})>[];
  for (final a in allAvail) {
    final user = await userRepo.getUser(a.userId);
    final name = user?.name.isNotEmpty == true ? user!.name : a.userId;
    rows.add((name: name, response: a.response.label));
  }
  // Sort: Yes → Maybe → No
  const order = {'Yes': 0, 'Maybe': 1, 'No': 2};
  rows.sort((a, b) =>
      (order[a.response] ?? 9).compareTo(order[b.response] ?? 9));

  await ExportService.shareAvailabilityCsv(
    teamName:   teamName,
    eventLabel: event.type.label,
    eventDate:  event.date,
    rows:       rows,
  );
}

// ── Header card ────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Event    event;
  final DateFormat dateFmt, timeFmt;
  const _HeaderCard({required this.event, required this.dateFmt, required this.timeFmt});

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.type.label,
                          style: Theme.of(context).textTheme.headlineSmall),
                      if (!event.isUpcoming)
                        Chip(
                          label: const Text('Past'),
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(Icons.calendar_today, dateFmt.format(event.date)),
            const SizedBox(height: 8),
            _InfoRow(Icons.access_time, timeFmt.format(event.date)),
            const SizedBox(height: 8),
            _InfoRow(Icons.location_on_outlined, event.location),
            const SizedBox(height: 8),
            _InfoRow(Icons.people_outline,
                '${event.minPlayers}–${event.maxPlayers} players'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   text;
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
  const _RsvpButtons({this.current, this.disabled = false, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AvailabilityResponse>(
      segments: AvailabilityResponse.values.map((r) =>
        ButtonSegment(
          value:   r,
          label:   Text(r.label),
          icon:    Text(r.emoji),
          enabled: !disabled,
        )).toList(),
      selected: current != null ? {current!} : {},
      emptySelectionAllowed: true,
      onSelectionChanged: disabled ? null : (s) {
        if (s.isNotEmpty) onSelect(s.first);
      },
    );
  }
}

// ── Availability summary (admin) ───────────────────────────────────────────────

class _AvailabilitySummary extends ConsumerWidget {
  final List<Availability>   allAvail;
  final AsyncValue            teamAsync;
  final int                  minPlayers;
  const _AvailabilitySummary({
    required this.allAvail,
    required this.teamAsync,
    required this.minPlayers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yes    = allAvail.where((a) => a.response == AvailabilityResponse.yes).toList();
    final no     = allAvail.where((a) => a.response == AvailabilityResponse.no).toList();
    final maybe  = allAvail.where((a) => a.response == AvailabilityResponse.maybe).toList();
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
        _ResponseGroup(label: 'No',  emoji: '❌', responses: no,  ref: ref),
        _ResponseGroup(label: 'Maybe', emoji: '❓', responses: maybe, ref: ref),
      ],
    );
  }
}

class _ResponseGroup extends StatelessWidget {
  final String             label, emoji;
  final List<Availability> responses;
  final WidgetRef          ref;
  const _ResponseGroup({
    required this.label, required this.emoji,
    required this.responses, required this.ref,
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

/// Resolves a userId to a display name via Firestore (cached by Riverpod).
final _userNameProvider = FutureProvider.family<String, String>((ref, uid) async {
  final user = await ref.read(userRepositoryProvider).getUser(uid);
  return user?.name.isNotEmpty == true ? user!.name : uid;
});

class _UserNameTile extends ConsumerWidget {
  final String    userId;
  final WidgetRef ref;
  const _UserNameTile({required this.userId, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(_userNameProvider(userId));
    return ListTile(
      dense:   true,
      leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
      title:   Text(nameAsync.valueOrNull ?? userId,
                   overflow: TextOverflow.ellipsis),
    );
  }
}
