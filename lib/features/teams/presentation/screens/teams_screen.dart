import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/analytics_service.dart';
import '../../domain/team.dart';
import '../providers/teams_provider.dart';
import '../../data/team_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/shared/widgets/banner_ad_widget.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(userTeamsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Teams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'My Schedule',
            onPressed: () => context.push(AppRoutes.mySchedule),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: SafeArea(top: false, child: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (teams) => teams.isEmpty
            ? _EmptyState(onJoin: () => _showJoinDialog(context, ref))
            : _TeamsList(teams: teams),
      )),
      bottomNavigationBar: const BannerAdWidget(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join',
            icon: const Icon(Icons.group_add),
            label: const Text('Join Team'),
            onPressed: () => _showJoinDialog(context, ref),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create',
            icon: const Icon(Icons.add),
            label: const Text('Create Team'),
            onPressed: () => context.push(AppRoutes.createTeam),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _JoinTeamDialog(ref: ref),
    );
  }
}

// ── Team list ─────────────────────────────────────────────────────────────────

class _TeamsList extends StatelessWidget {
  final List<Team> teams;
  const _TeamsList({required this.teams});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: teams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _TeamCard(team: teams[i]),
    );
  }
}

class _TeamCard extends ConsumerWidget {
  final Team team;
  const _TeamCard({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 20 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
          backgroundImage: team.logoUrl != null ? NetworkImage(team.logoUrl!) : null,
          child: team.logoUrl == null ? Text(team.sport.substring(0, 1)) : null,
        ),
        title:   Text(team.name),
        subtitle: Text(
          '${team.sport} · ${team.totalMembers} member${team.totalMembers == 1 ? '' : 's'}'
          '${team.isAdmin(uid) ? ' · Admin' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/teams/${team.teamId}'),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onJoin;
  const _EmptyState({required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No teams yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Create a new team or ask your coach for the team ID to join.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon:    const Icon(Icons.group_add),
              label:   const Text('Join a Team'),
              onPressed: onJoin,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Join team dialog ──────────────────────────────────────────────────────────

class _JoinTeamDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _JoinTeamDialog({required this.ref});

  @override
  ConsumerState<_JoinTeamDialog> createState() => _JoinTeamDialogState();
}

class _JoinTeamDialogState extends ConsumerState<_JoinTeamDialog> {
  final _ctrl      = TextEditingController();
  bool  _loading   = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final teamId = _ctrl.text.trim();
    if (teamId.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    final team = await ref.read(teamRepositoryProvider).getTeam(teamId);
    if (!mounted) return;

    if (team == null) {
      setState(() { _loading = false; _error = 'Team not found. Check the ID and try again.'; });
      return;
    }

    final user    = ref.read(currentUserProvider)!;
    final profile = await ref.read(userRepositoryProvider).getUser(user.uid);
    if (!mounted) return;

    if (team.isMember(user.uid)) {
      setState(() { _loading = false; _error = 'You are already a member of this team.'; });
      return;
    }

    await ref.read(teamRepositoryProvider).requestToJoin(
      teamId,
      user.uid,
      profile?.name ?? user.email ?? '',
      user.email ?? '',
    );
    unawaited(ref.read(analyticsServiceProvider).logTeamJoined(team.sport));

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join request sent to ${team.name}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join a Team'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ask your coach or team admin for the Team ID.'),
          const SizedBox(height: 16),
          TextField(
            controller:    _ctrl,
            autocorrect:   false,
            textInputAction: TextInputAction.done,
            onSubmitted:   (_) => _submit(),
            decoration:    const InputDecoration(
              labelText: 'Team ID',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send Request'),
        ),
      ],
    );
  }
}
