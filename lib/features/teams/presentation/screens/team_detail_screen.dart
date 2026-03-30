import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/team_repository.dart';
import '../../domain/join_request.dart';
import '../../domain/team.dart';
import '../providers/teams_provider.dart';

class TeamDetailScreen extends ConsumerWidget {
  final String teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamProvider(teamId));

    return teamAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (team) {
        if (team == null) {
          return const Scaffold(body: Center(child: Text('Team not found.')));
        }
        return _TeamDetailView(team: team);
      },
    );
  }
}

class _TeamDetailView extends ConsumerWidget {
  final Team team;
  const _TeamDetailView({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final isAdmin = team.isAdmin(uid);
    final requestsAsync =
        isAdmin ? ref.watch(pendingRequestsProvider(team.teamId)) : null;
    final pendingCount = requestsAsync?.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          // Show Team ID for sharing
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Team ID',
            onPressed: () => _showTeamId(context, team.teamId),
          ),
          // Events button
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Events',
            onPressed: () => context.push('/teams/${team.teamId}/events'),
          ),
          // Notification inbox — all members
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            tooltip: 'Notification Inbox',
            onPressed: () => context.push('/teams/${team.teamId}/inbox'),
          ),
          // Notify team — admin only
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Send Notification',
              onPressed: () => context.push('/teams/${team.teamId}/notify'),
            ),
          // Rankings — admin only
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.leaderboard),
              tooltip: 'Player Rankings (Coach only)',
              onPressed: () => context.push('/teams/${team.teamId}/rankings'),
            ),
          // Spares — admin only
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Manage Spares',
              onPressed: () => context.push('/teams/${team.teamId}/spares'),
            ),
        ],
      ),
      body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Header card ─────────────────────────────────────────────
              _HeaderCard(team: team, isAdmin: isAdmin),
              const SizedBox(height: 16),

              // ── Pending join requests (admin only) ───────────────────────
              if (isAdmin) ...[
                _SectionHeader(
                  title: 'Join Requests',
                  badge: pendingCount > 0 ? pendingCount : null,
                ),
                const SizedBox(height: 8),
                requestsAsync!.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (requests) => requests.isEmpty
                      ? const _EmptySection(message: 'No pending requests')
                      : Column(
                          children: requests
                              .map((r) => _JoinRequestTile(
                                  request: r, teamId: team.teamId))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Position preferences ─────────────────────────────────────
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('My Position Preferences'),
                onPressed: () => context.push(
                  '/teams/${team.teamId}/preferences/$uid'
                  '?sport=${Uri.encodeComponent(team.sport)}'
                  '&name=',
                ),
              ),
              const SizedBox(height: 20),

              // ── Roster ──────────────────────────────────────────────────
              _SectionHeader(
                title: 'Roster',
                badge: team.totalMembers,
              ),
              const SizedBox(height: 8),
              if (team.admins.isEmpty && team.players.isEmpty)
                const _EmptySection(message: 'No members yet')
              else ...[
                ...team.admins.map((id) => _MemberTile(
                      userId: id,
                      label: 'Coach / Admin',
                      isAdmin: isAdmin,
                      isSelf: id == uid,
                      canRemove: false,
                      onRemove: null,
                      onSetPrefs: isAdmin
                          ? () => context.push(
                                '/teams/${team.teamId}/preferences/$id'
                                '?sport=${Uri.encodeComponent(team.sport)}&name=',
                              )
                          : null,
                    )),
                ...team.players.map((id) => _MemberTile(
                      userId: id,
                      label: 'Player',
                      isAdmin: isAdmin,
                      isSelf: id == uid,
                      canRemove: isAdmin && id != uid,
                      onRemove: () => _confirmRemove(context, ref, id),
                      onPromote: isAdmin
                          ? () => _confirmPromote(context, ref, id)
                          : null,
                      onSetPrefs: isAdmin
                          ? () => context.push(
                                '/teams/${team.teamId}/preferences/$id'
                                '?sport=${Uri.encodeComponent(team.sport)}&name=',
                              )
                          : null,
                    )),
              ],
            ],
          )),
    );
  }

  void _showTeamId(BuildContext context, String teamId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Team ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Share this ID with players so they can request to join:'),
            const SizedBox(height: 12),
            SelectableText(
              teamId,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: teamId));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Team ID copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _confirmPromote(BuildContext context, WidgetRef ref, String userId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Promote to Admin'),
        content: const Text(
          'This player will become a co-admin and gain full coach permissions '
          '(scheduling, rankings, lineups, roster management). '
          'This cannot be undone from within the app.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref
                  .read(teamRepositoryProvider)
                  .promoteToAdmin(team.teamId, userId);
            },
            child: const Text('Promote'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, String userId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Player'),
        content: const Text(
            'Remove this player from the team? They can request to rejoin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await ref
                  .read(teamRepositoryProvider)
                  .removePlayer(team.teamId, userId);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ── Header card ────────────────────────────────────────────────────────────────

class _HeaderCard extends ConsumerStatefulWidget {
  final Team team;
  final bool isAdmin;
  const _HeaderCard({required this.team, required this.isAdmin});

  @override
  ConsumerState<_HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends ConsumerState<_HeaderCard> {
  bool _uploading = false;

  Future<void> _pickAndUploadLogo() async {
    // Step 1 — pick from gallery
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    // Step 2 — crop to square
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 85,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Team Logo',
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Team Logo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null) return; // user cancelled crop

    setState(() => _uploading = true);
    try {
      await ref
          .read(teamRepositoryProvider)
          .uploadTeamLogo(widget.team.teamId, File(cropped.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Logo ────────────────────────────────────────────────────
            GestureDetector(
              onTap: widget.isAdmin ? _pickAndUploadLogo : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 32 *
                        MediaQuery.textScalerOf(context)
                            .scale(1.0)
                            .clamp(1.0, 1.5),
                    backgroundImage: widget.team.logoUrl != null
                        ? NetworkImage(widget.team.logoUrl!)
                        : null,
                    child: widget.team.logoUrl == null
                        ? Text(widget.team.sport.substring(0, 1),
                            style: const TextStyle(fontSize: 22))
                        : null,
                  ),
                  if (widget.isAdmin)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: _uploading
                            ? const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Colors.white))
                            : const Icon(Icons.camera_alt,
                                size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.team.sport,
                      style: Theme.of(context).textTheme.labelMedium),
                  Text(widget.team.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '${widget.team.totalMembers}/${widget.team.maxPlayers} players'
                    '${widget.team.dropInEnabled ? ' · Drop-in enabled' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (widget.isAdmin)
              Chip(
                label: const Text('Admin'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Join request tile ──────────────────────────────────────────────────────────

class _JoinRequestTile extends ConsumerWidget {
  final JoinRequest request;
  final String teamId;
  const _JoinRequestTile({required this.request, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius:
              20 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
          child: const Icon(Icons.person_add),
        ),
        title: Text(request.userName),
        subtitle: Text(request.userEmail),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              tooltip: 'Approve',
              onPressed: () async {
                await ref
                    .read(teamRepositoryProvider)
                    .approveRequest(teamId, request.userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${request.userName} approved.')),
                  );
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.cancel_outlined,
                  color: Theme.of(context).colorScheme.error),
              tooltip: 'Deny',
              onPressed: () async {
                await ref
                    .read(teamRepositoryProvider)
                    .denyRequest(teamId, request.userId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Member tile ────────────────────────────────────────────────────────────────

class _MemberTile extends ConsumerWidget {
  final String userId;
  final String label;
  final bool isAdmin;
  final bool isSelf;
  final bool canRemove;
  final VoidCallback? onRemove;
  final VoidCallback? onSetPrefs;
  final VoidCallback? onPromote;

  const _MemberTile({
    required this.userId,
    required this.label,
    required this.isAdmin,
    required this.isSelf,
    required this.canRemove,
    required this.onRemove,
    this.onSetPrefs,
    this.onPromote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(_userNameProvider(userId)).valueOrNull ?? userId;
    final displayName = isSelf ? '$name (you)' : name;
    return ListTile(
      leading: CircleAvatar(
        radius:
            20 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(displayName, overflow: TextOverflow.ellipsis),
      subtitle: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onSetPrefs != null)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Set position preferences',
              onPressed: onSetPrefs,
            ),
          if (onPromote != null)
            IconButton(
              icon: const Icon(Icons.manage_accounts),
              tooltip: 'Promote to Admin',
              onPressed: onPromote,
            ),
          if (canRemove)
            IconButton(
              icon: Icon(Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.error),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

final _userNameProvider =
    FutureProvider.family<String, String>((ref, uid) async {
  final user = await ref.read(userRepositoryProvider).getUser(uid);
  return user?.name.isNotEmpty == true ? user!.name : uid;
});

// ── Helpers ────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? badge;
  const _SectionHeader({required this.title, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (badge != null && badge! > 0) ...[
          const SizedBox(width: 8),
          Badge(label: Text('$badge')),
        ],
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message,
          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
    );
  }
}
