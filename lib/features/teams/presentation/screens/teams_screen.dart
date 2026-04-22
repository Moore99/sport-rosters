import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/providers.dart';
import '../../domain/team.dart';
import '../../data/team_repository.dart';
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
        data:    (teams) {
          final hiddenAsync   = ref.watch(userHiddenTeamsProvider);
          final archivedAsync = ref.watch(userArchivedTeamsProvider);
          final hidden        = hiddenAsync.valueOrNull ?? [];
          final archived      = archivedAsync.valueOrNull ?? [];

          if (teams.isEmpty && hidden.isEmpty && archived.isEmpty) {
            return _EmptyState(onJoin: () => _showJoinDialog(context, ref));
          }
          return _TeamsListView(
            teams:    teams,
            hidden:   hidden,
            archived: archived,
          );
        },
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

class _TeamsListView extends StatefulWidget {
  final List<Team> teams;
  final List<Team> hidden;
  final List<Team> archived;
  const _TeamsListView({
    required this.teams,
    required this.hidden,
    required this.archived,
  });

  @override
  State<_TeamsListView> createState() => _TeamsListViewState();
}

class _TeamsListViewState extends State<_TeamsListView> {
  bool _showHidden   = false;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        ...widget.teams.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TeamCard(team: t),
        )),

        if (widget.hidden.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showHidden = !_showHidden),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(_showHidden
                      ? Icons.expand_less
                      : Icons.expand_more,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.hidden.length} hidden team${widget.hidden.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          if (_showHidden)
            ...widget.hidden.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Opacity(opacity: 0.6, child: _TeamCard(team: t)),
            )),
        ],

        if (widget.archived.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showArchived = !_showArchived),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(_showArchived
                      ? Icons.expand_less
                      : Icons.expand_more,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.archived.length} archived team${widget.archived.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          if (_showArchived)
            ...widget.archived.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Opacity(opacity: 0.5, child: _TeamCard(team: t)),
            )),
        ],
      ],
    );
  }
}

class _TeamCard extends ConsumerWidget {
  final Team team;
  const _TeamCard({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    final sportColor = AppConfig.sportColor(team.sport);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: sportColor),
            Expanded(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                leading: CircleAvatar(
                  radius: 20 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
                  backgroundColor: team.logoUrl == null ? sportColor : null,
                  backgroundImage: team.logoUrl != null ? NetworkImage(team.logoUrl!) : null,
                  child: team.logoUrl == null
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: SvgPicture.asset(
                            AppConfig.sportIconAsset(team.sport),
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        )
                      : null,
                ),
                title:   Text(team.name),
                subtitle: Text(
                  '${team.sport} · ${team.totalMembers} member${team.totalMembers == 1 ? '' : 's'}'
                  '${team.isAdmin(uid) ? ' · Admin' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/teams/${team.teamId}'),
              ),
            ),
          ],
        ),
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
  bool _scanning   = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String? _parseTeamId(String raw) {
    if (raw.startsWith('sportsrostering://join/')) {
      return raw.substring('sportsrostering://join/'.length);
    }
    if (raw.length > 5 && !raw.contains(' ')) {
      return raw;
    }
    return null;
  }

  Future<void> _submit({String? teamId}) async {
    final id = (teamId ?? _ctrl.text.trim());
    if (id.isEmpty || _loading) return;

    setState(() { _loading = true; _error = null; });

    try {
      final team = await ref.read(teamRepositoryProvider).getTeam(id);
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
        id,
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
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Something went wrong. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_scanning) {
      return AlertDialog(
        title: const Text('Scan Team QR Code'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw == null) return;
              final teamId = _parseTeamId(raw);
              if (teamId != null) {
                setState(() { _scanning = false; });
                _submit(teamId: teamId);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() { _scanning = false; }),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Join a Team'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scan the team QR code or ask your coach for the Team ID.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() { _scanning = true; }),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Scan QR Code'),
          ),
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
          onPressed: _loading ? null : () => _submit(),
          child: _loading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send Request'),
        ),
      ],
    );
  }
}
