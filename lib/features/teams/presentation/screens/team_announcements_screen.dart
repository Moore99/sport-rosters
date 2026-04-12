import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/announcement_repository.dart';
import '../../domain/announcement.dart';
import '../providers/announcements_provider.dart';
import '../providers/teams_provider.dart';

class TeamAnnouncementsScreen extends ConsumerWidget {
  final String teamId;
  const TeamAnnouncementsScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid      = ref.watch(currentUserProvider)?.uid ?? '';
    final teamAsync = ref.watch(teamProvider(teamId));
    final isAdmin  = teamAsync.valueOrNull?.isAdmin(uid) ?? false;
    final listAsync = ref.watch(teamAnnouncementsProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              tooltip: 'Post Announcement',
              onPressed: () => _showEditDialog(context, ref, uid, isAdmin, null),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        top: false,
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text('No announcements yet.',
                    style: TextStyle(color: Colors.grey)),
              );
            }
            // Pinned first, then by date descending (already sorted by Firestore)
            final pinned   = items.where((a) => a.pinned).toList();
            final unpinned = items.where((a) => !a.pinned).toList();
            final ordered  = [...pinned, ...unpinned];

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ordered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AnnouncementCard(
                announcement: ordered[i],
                isAdmin: isAdmin,
                onEdit: () =>
                    _showEditDialog(context, ref, uid, isAdmin, ordered[i]),
                onDelete: () =>
                    _confirmDelete(context, ref, ordered[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
    bool isAdmin,
    Announcement? existing,
  ) async {
    if (!isAdmin) return;

    final titleCtrl  = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl   = TextEditingController(text: existing?.body  ?? '');
    var   pinned     = existing?.pinned ?? false;
    final formKey    = GlobalKey<FormState>();
    String? authorName;

    // Resolve author name once
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    authorName = profile?.name ?? uid;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing != null ? 'Edit Announcement' : 'New Announcement'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bodyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pin to top'),
                    value: pinned,
                    onChanged: (v) => setLocal(() => pinned = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();

                final repo = ref.read(announcementRepositoryProvider);
                if (existing != null) {
                  await repo.updateAnnouncement(existing.copyWith(
                    title:  titleCtrl.text.trim(),
                    body:   bodyCtrl.text.trim(),
                    pinned: pinned,
                  ));
                } else {
                  final docId = FirebaseFirestore.instance
                      .collection('teams')
                      .doc(teamId)
                      .collection('announcements')
                      .doc()
                      .id;
                  await repo.createAnnouncement(Announcement(
                    announcementId: docId,
                    teamId:         teamId,
                    title:          titleCtrl.text.trim(),
                    body:           bodyCtrl.text.trim(),
                    authorId:       uid,
                    authorName:     authorName ?? uid,
                    pinned:         pinned,
                    createdAt:      DateTime.now(),
                  ));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    bodyCtrl.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Announcement a,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement?'),
        content: Text('Delete "${a.title}"? This cannot be undone.'),
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
          .read(announcementRepositoryProvider)
          .deleteAnnouncement(teamId, a.announcementId);
    }
  }
}

// ── Announcement card ──────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final bool         isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (announcement.pinned) ...[
                  Icon(Icons.push_pin,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    announcement.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      if (v == 'edit')   onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          title: Text('Delete',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(announcement.body),
            const SizedBox(height: 8),
            Text(
              '${announcement.authorName} · ${dateFmt.format(announcement.createdAt)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
