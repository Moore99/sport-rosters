import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/events/presentation/providers/events_provider.dart';
import '../../../../features/rankings/presentation/providers/rankings_provider.dart';
import '../../../../features/teams/presentation/providers/teams_provider.dart';
import '../../data/dropin_repository.dart';
import '../providers/dropin_provider.dart';

class DropInScreen extends ConsumerWidget {
  final String teamId;
  final String eventId;
  const DropInScreen({super.key, required this.teamId, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid          = ref.watch(currentUserProvider)?.uid ?? '';
    final teamAsync    = ref.watch(teamProvider(teamId));
    final eventAsync   = ref.watch(eventProvider(eventId));
    final sessionAsync = ref.watch(dropInSessionProvider(eventId));

    final isAdmin      = teamAsync.valueOrNull?.isAdmin(uid) ?? false;
    final event        = eventAsync.valueOrNull;
    final session      = sessionAsync.valueOrNull;
    final signups      = session?.signups ?? [];
    final waitlist     = session?.waitlist ?? [];
    final isSignedUp   = signups.contains(uid);
    final isWaitlisted = waitlist.contains(uid);
    final generated    = session?.generatedTeams ?? [];
    final maxPlayers   = event?.maxPlayers;
    final isFull       = maxPlayers != null && signups.length >= maxPlayers;

    return Scaffold(
      appBar: AppBar(title: const Text('Drop-in')),
      body: SafeArea(top: false, child: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Summary card ─────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed up: ${signups.length}'
                      '${event != null ? ' / ${event.maxPlayers} max' : ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (event != null && signups.length < event.minPlayers)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Need ${event.minPlayers - signups.length} more to reach minimum',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── RSVP button ───────────────────────────────────────────────
            if (event?.allowSignups == true)
              if (isSignedUp)
                OutlinedButton.icon(
                  icon:  const Icon(Icons.close),
                  label: const Text('Withdraw'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => ref
                      .read(dropInRepositoryProvider)
                      .withdraw(eventId, uid),
                )
              else if (isWaitlisted)
                OutlinedButton.icon(
                  icon:  const Icon(Icons.hourglass_top_outlined),
                  label: Text('Waitlisted (#${session!.waitlistPosition(uid)}) — Leave'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  onPressed: () => ref
                      .read(dropInRepositoryProvider)
                      .withdraw(eventId, uid),
                )
              else if (isFull)
                FilledButton.icon(
                  icon:  const Icon(Icons.hourglass_empty),
                  label: const Text('Join Waitlist'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  onPressed: () => ref
                      .read(dropInRepositoryProvider)
                      .signUp(eventId, teamId, uid, maxPlayers: maxPlayers),
                )
              else
                FilledButton.icon(
                  icon:  const Icon(Icons.add_circle_outline),
                  label: const Text("I'm In"),
                  onPressed: () => ref
                      .read(dropInRepositoryProvider)
                      .signUp(eventId, teamId, uid, maxPlayers: maxPlayers),
                ),
            const SizedBox(height: 24),

            // ── Admin: generate teams ─────────────────────────────────────
            if (isAdmin) ...[
              FilledButton.icon(
                icon:  const Icon(Icons.auto_awesome),
                label: Text(generated.isEmpty
                    ? 'Generate Balanced Teams'
                    : 'Regenerate Teams'),
                onPressed: signups.length < 2
                    ? null
                    : () => _showGenerateDialog(context, ref, signups, teamId),
              ),
              if (signups.length < 2)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Need at least 2 players to generate teams.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // ── Generated teams ───────────────────────────────────────────
            if (generated.isNotEmpty) ...[
              Text('Teams', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...generated.asMap().entries.map((entry) =>
                  _TeamCard(
                    index:   entry.key,
                    members: entry.value,
                    uid:     uid,
                  )),
              const SizedBox(height: 16),
            ],

            // ── Signup list ───────────────────────────────────────────────
            Text('Players (${signups.length}${maxPlayers != null ? ' / $maxPlayers' : ''})',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (signups.isEmpty)
              Text('No players signed up yet.',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline))
            else
              ...signups.map((id) => _PlayerTile(
                    userId:   id,
                    isSelf:   id == uid,
                    isAdmin:  isAdmin,
                    onRemove: isAdmin && id != uid
                        ? () => ref
                            .read(dropInRepositoryProvider)
                            .withdraw(eventId, id)
                        : null,
                  )),

            // ── Waitlist ──────────────────────────────────────────────────
            if (waitlist.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Waitlist (${waitlist.length})',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...waitlist.asMap().entries.map((e) => _PlayerTile(
                    userId:  e.value,
                    isSelf:  e.value == uid,
                    isAdmin: isAdmin,
                    label:   '#${e.key + 1}',
                    onRemove: isAdmin && e.value != uid
                        ? () => ref
                            .read(dropInRepositoryProvider)
                            .withdraw(eventId, e.value)
                        : null,
                  )),
            ],
          ],
        ),
      )),
    );
  }

  void _showGenerateDialog(
      BuildContext context, WidgetRef ref,
      List<String> signups, String teamId) {
    int numTeams = signups.length >= 6 ? 3 : 2;

    showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Generate Balanced Teams'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${signups.length} players signed up.'),
              const SizedBox(height: 16),
              const Text('Number of teams:'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (int n = 2; n <= _maxTeams(signups.length); n++)
                    ButtonSegment(value: n, label: Text('$n')),
                ],
                selected: {numTeams},
                onSelectionChanged: (v) => setState(() => numTeams = v.first),
              ),
              const SizedBox(height: 8),
              Text(
                '~${(signups.length / numTeams).ceil()} players per team',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.outline),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop(numTeams);
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    ).then((chosen) {
      if (chosen == null || !context.mounted) return;
      _generate(context, ref, signups, teamId, chosen);
    });
  }

  Future<void> _generate(BuildContext context, WidgetRef ref,
      List<String> signups, String teamId, int numTeams) async {
    // Load rankings (admin-visible scores)
    final rankings = ref.read(teamRankingsProvider(teamId)).valueOrNull ?? [];
    final scores   = {for (final r in rankings) r.userId: r.score};

    // Sort by score descending (unranked = 0, go last)
    final sorted = List<String>.from(signups)
      ..sort((a, b) => (scores[b] ?? 0.0).compareTo(scores[a] ?? 0.0));

    // Snake draft into teams
    final teams = List.generate(numTeams, (_) => <String>[]);
    for (int i = 0; i < sorted.length; i++) {
      final round     = i ~/ numTeams;
      final pos       = i % numTeams;
      final teamIndex = round.isEven ? pos : (numTeams - 1 - pos);
      teams[teamIndex].add(sorted[i]);
    }

    await ref.read(dropInRepositoryProvider).saveGeneratedTeams(eventId, teams);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$numTeams balanced teams generated.')),
      );
    }
  }

  int _maxTeams(int playerCount) {
    if (playerCount >= 8) return 4;
    if (playerCount >= 6) return 3;
    return 2;
  }
}

// ── Generated team card ────────────────────────────────────────────────────────

class _TeamCard extends ConsumerWidget {
  final int          index;
  final List<String> members;
  final String       uid;
  const _TeamCard({required this.index, required this.members, required this.uid});

  static const _teamColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _teamColors[index % _teamColors.length];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.group, color: color, size: 18),
                const SizedBox(width: 8),
                Text('Team ${index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Text('${members.length} players',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          ...members.map((id) => _TeamMemberRow(userId: id, isSelf: id == uid)),
        ],
      ),
    );
  }
}

class _TeamMemberRow extends ConsumerWidget {
  final String userId;
  final bool   isSelf;
  const _TeamMemberRow({required this.userId, required this.isSelf});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(_userNameProvider(userId)).valueOrNull ?? userId;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 12)),
      ),
      title: Text(isSelf ? '$name (you)' : name),
    );
  }
}

// ── Signup player tile ─────────────────────────────────────────────────────────

class _PlayerTile extends ConsumerWidget {
  final String  userId;
  final bool    isSelf, isAdmin;
  final String? label;
  final VoidCallback? onRemove;
  const _PlayerTile({
    required this.userId, required this.isSelf,
    required this.isAdmin, this.label, required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(_userNameProvider(userId)).valueOrNull ?? userId;
    return ListTile(
      leading: label != null
          ? CircleAvatar(child: Text(label!,
              style: const TextStyle(fontSize: 12)))
          : const CircleAvatar(child: Icon(Icons.person)),
      title:   Text(isSelf ? '$name (you)' : name),
      trailing: onRemove != null
          ? IconButton(
              icon:      Icon(Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.error),
              onPressed: onRemove,
            )
          : null,
    );
  }
}

final _userNameProvider = FutureProvider.family<String, String>((ref, uid) async {
  final user = await ref.read(userRepositoryProvider).getUser(uid);
  return user?.name.isNotEmpty == true ? user!.name : uid;
});
