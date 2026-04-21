import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/spares_repository.dart';
import '../../data/team_repository.dart';
import '../../domain/spare_request.dart';
import '../../domain/join_request.dart';
import '../../domain/team.dart';
import '../providers/spares_provider.dart';
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
    final userProfile = ref.watch(currentUserProfileProvider).valueOrNull;
    final isMuted  = userProfile?.mutedTeams.contains(team.teamId) ?? false;
    final isHidden = userProfile?.hiddenTeams.contains(team.teamId) ?? false;
    final requestsAsync =
        isAdmin ? ref.watch(pendingRequestsProvider(team.teamId)) : null;
    final pendingCount = requestsAsync?.valueOrNull?.length ?? 0;

    final sparesAsync = ref.watch(teamSparesProvider(team.teamId));
    final spareRequestsAsync =
        isAdmin ? ref.watch(spareRequestsProvider(team.teamId)) : null;
    final pendingSpareCount = spareRequestsAsync?.valueOrNull?.length ?? 0;
    final isAlreadySpare =
        sparesAsync.valueOrNull?.any((s) => s.userId == uid) ?? false;
    final myRequestAsync =
        !isAdmin ? ref.watch(mySpareRequestProvider(team.teamId)) : null;
    final hasPendingRequest = myRequestAsync?.valueOrNull != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          // Events — always visible
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Events',
            onPressed: () => context.push('/teams/${team.teamId}/events'),
          ),
          // QR / share — always visible
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'Share Team',
            onPressed: () => _showTeamId(context, team.teamId, team.name),
          ),
          // Single overflow menu — everything else
          Stack(
            clipBehavior: Clip.none,
            children: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More',
                onSelected: (value) async {
                  final repo = ref.read(userRepositoryProvider);
                  switch (value) {
                    case 'announcements':
                      context.push('/teams/${team.teamId}/announcements');
                    case 'inbox':
                      context.push('/teams/${team.teamId}/inbox');
                    case 'stats':
                      context.push('/teams/${team.teamId}/stats');
                    case 'mute':
                      if (isMuted) {
                        await repo.unmuteTeam(uid, team.teamId);
                      } else {
                        await repo.muteTeam(uid, team.teamId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notifications muted for this team.')),
                          );
                        }
                      }
                    case 'hide':
                      if (isHidden) {
                        await repo.unhideTeam(uid, team.teamId);
                      } else {
                        await repo.hideTeam(uid, team.teamId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(
                                '${team.name} hidden. Find it under "hidden teams" on the teams screen.')),
                          );
                        }
                      }
                    case 'notify':
                      context.push('/teams/${team.teamId}/notify');
                    case 'rankings':
                      context.push('/teams/${team.teamId}/rankings');
                    case 'spares':
                      context.push('/teams/${team.teamId}/spares');
                    case 'archive':
                      _confirmArchive(context, ref, archive: true);
                    case 'restore':
                      _confirmArchive(context, ref, archive: false);
                    case 'delete':
                      _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'announcements',
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: const Text('Announcements'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'inbox',
                    child: ListTile(
                      leading: const Icon(Icons.inbox_outlined),
                      title: const Text('Notification Inbox'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'stats',
                    child: ListTile(
                      leading: const Icon(Icons.bar_chart),
                      title: const Text('Team Stats'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'mute',
                    child: ListTile(
                      leading: Icon(isMuted
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                          color: isMuted ? null : Theme.of(context).colorScheme.error),
                      title: Text(isMuted ? 'Unmute notifications' : 'Mute notifications'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'hide',
                    child: ListTile(
                      leading: Icon(isHidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      title: Text(isHidden ? 'Show in list' : 'Hide from list'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (isAdmin) ...[
                    PopupMenuItem(
                      value: 'notify',
                      child: ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('Send Notification'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rankings',
                      child: ListTile(
                        leading: const Icon(Icons.leaderboard),
                        title: const Text('Player Rankings'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'spares',
                      child: ListTile(
                        leading: Badge(
                          isLabelVisible: pendingSpareCount > 0,
                          label: Text('$pendingSpareCount'),
                          child: const Icon(Icons.people_outline),
                        ),
                        title: const Text('Manage Spares'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (!team.archived)
                      const PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          leading: Icon(Icons.archive_outlined),
                          title: Text('Archive Team'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'restore',
                        child: ListTile(
                          leading: Icon(Icons.unarchive_outlined),
                          title: Text('Restore Team'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error),
                        title: Text('Delete Team',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              ),
              if (pendingSpareCount > 0 && isAdmin)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Badge(label: Text('$pendingSpareCount')),
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
              // ── Archived banner ──────────────────────────────────────────
              if (team.archived) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This team is archived. It is hidden from the main list.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
              const SizedBox(height: 8),

              // ── Spare request / leave (non-admin players) ────────────────
              if (!isAdmin && isAlreadySpare)
                _LeaveSpareButton(teamId: team.teamId, uid: uid)
              else if (!isAdmin && !isAlreadySpare)
                _SpareRequestButton(
                  teamId: team.teamId,
                  uid: uid,
                  hasPendingRequest: hasPendingRequest,
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
                      onAttendance: isAdmin
                          ? () => context
                              .push('/teams/${team.teamId}/attendance/$id')
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
                      onAttendance: isAdmin
                          ? () => context
                              .push('/teams/${team.teamId}/attendance/$id')
                          : null,
                    )),
              ],
            ],
          )),
    );
  }

  void _showTeamId(BuildContext context, String teamId, String teamName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Join $teamName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scan this QR code or share the Team ID:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: 'sportsrostering://join/$teamId',
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              teamId,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: teamId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Team ID copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy ID'),
          ),
          TextButton.icon(
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Join my team "$teamName" on Sport Rosters! Team ID: $teamId',
                  subject: 'Join $teamName',
                ),
              );
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
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

  void _confirmArchive(BuildContext context, WidgetRef ref,
      {required bool archive}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(archive ? 'Archive Team' : 'Restore Team'),
        content: Text(archive
            ? 'Archive "${team.name}"? It will be hidden from the main list but nothing will be deleted. You can restore it any time.'
            : 'Restore "${team.name}"? It will reappear in the main teams list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref
                  .read(teamRepositoryProvider)
                  .archiveTeam(team.teamId, archived: archive);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(archive
                          ? '"${team.name}" archived.'
                          : '"${team.name}" restored.')),
                );
              }
            },
            child: Text(archive ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text(
          'Permanently delete "${team.name}"? This will remove all members, events, lineups, and data. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(teamRepositoryProvider).deleteTeam(team.teamId);
                if (context.mounted) context.go('/teams');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete team: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
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
  final VoidCallback? onAttendance;

  const _MemberTile({
    required this.userId,
    required this.label,
    required this.isAdmin,
    required this.isSelf,
    required this.canRemove,
    required this.onRemove,
    this.onSetPrefs,
    this.onPromote,
    this.onAttendance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(_userNameProvider(userId)).valueOrNull ?? userId;
    final displayName = isSelf ? '$name (you)' : name;
    final hasMenu = onSetPrefs != null ||
        onAttendance != null ||
        onPromote != null ||
        canRemove;

    return ListTile(
      leading: CircleAvatar(
        radius:
            16 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      title: Text(displayName, overflow: TextOverflow.ellipsis),
      subtitle: Text(label),
      trailing: hasMenu
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onSelected: (value) {
                switch (value) {
                  case 'prefs':
                    onSetPrefs?.call();
                  case 'attendance':
                    onAttendance?.call();
                  case 'promote':
                    onPromote?.call();
                  case 'remove':
                    onRemove?.call();
                }
              },
              itemBuilder: (_) => [
                if (onSetPrefs != null)
                  const PopupMenuItem(
                    value: 'prefs',
                    child: ListTile(
                      leading: Icon(Icons.tune),
                      title: Text('Position Preferences'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onAttendance != null)
                  const PopupMenuItem(
                    value: 'attendance',
                    child: ListTile(
                      leading: Icon(Icons.bar_chart_outlined),
                      title: Text('Attendance History'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onPromote != null)
                  const PopupMenuItem(
                    value: 'promote',
                    child: ListTile(
                      leading: Icon(Icons.manage_accounts),
                      title: Text('Promote to Admin'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (canRemove)
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.remove_circle_outline,
                          color: Theme.of(context).colorScheme.error),
                      title: Text('Remove from Team',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

final _userNameProvider =
    FutureProvider.family<String, String>((ref, uid) async {
  final user = await ref.read(userRepositoryProvider).getUser(uid);
  return user?.name.isNotEmpty == true ? user!.name : uid;
});

// ── Leave spares button ────────────────────────────────────────────────────────

class _LeaveSpareButton extends ConsumerStatefulWidget {
  final String teamId, uid;
  const _LeaveSpareButton({required this.teamId, required this.uid});

  @override
  ConsumerState<_LeaveSpareButton> createState() => _LeaveSpareButtonState();
}

class _LeaveSpareButtonState extends ConsumerState<_LeaveSpareButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_off_outlined),
        title: const Text('You are on the spares list'),
        subtitle: const Text('Available to fill in when the roster is short'),
        trailing: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(
                onPressed: _confirmLeave,
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Leave'),
              ),
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Spares List?'),
        content: const Text(
            'You will no longer be called as a spare for this team. '
            'You can request to rejoin at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(sparesRepositoryProvider)
          .leaveSpares(widget.teamId, widget.uid);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Spare request button ───────────────────────────────────────────────────────

class _SpareRequestButton extends ConsumerStatefulWidget {
  final String teamId;
  final String uid;
  final bool hasPendingRequest;
  const _SpareRequestButton({
    required this.teamId,
    required this.uid,
    required this.hasPendingRequest,
  });

  @override
  ConsumerState<_SpareRequestButton> createState() =>
      _SpareRequestButtonState();
}

class _SpareRequestButtonState extends ConsumerState<_SpareRequestButton> {
  bool _loading = false;

  Future<void> _submitRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Spare Status'),
        content: const Text(
          'Ask the coach to add you to the spares list? '
          'You\'ll be available to fill in when the roster is short.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final profile =
          await ref.read(userRepositoryProvider).getUser(widget.uid);
      await ref.read(sparesRepositoryProvider).createSpareRequest(
            SpareRequest(
              userId: widget.uid,
              teamId: widget.teamId,
              userName: profile?.name ?? '',
              userEmail: profile?.email ?? '',
              requestedAt: DateTime.now(),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Request sent — waiting for coach approval.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelRequest() async {
    await ref
        .read(sparesRepositoryProvider)
        .denySpareRequest(widget.teamId, widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasPendingRequest) {
      return OutlinedButton.icon(
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.hourglass_top_outlined),
        label: const Text('Spare Request Pending'),
        onPressed: _loading
            ? null
            : () async {
                final cancel = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cancel Request?'),
                    content: const Text('Withdraw your spare request?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Keep'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(ctx).colorScheme.error),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Withdraw'),
                      ),
                    ],
                  ),
                );
                if (cancel == true) await _cancelRequest();
              },
      );
    }

    return OutlinedButton.icon(
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.person_add_outlined),
      label: const Text('Request Spare Status'),
      onPressed: _loading ? null : _submitRequest,
    );
  }
}

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
