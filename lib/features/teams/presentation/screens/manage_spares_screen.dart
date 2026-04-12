import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/user_repository.dart';
import '../../../auth/domain/app_user.dart';
import '../../data/spares_repository.dart';
import '../../domain/spare_request.dart';
import '../../domain/spares.dart';
import '../providers/spares_provider.dart';
import '../providers/teams_provider.dart';

final _userProvider =
    FutureProvider.family<AppUser?, String>((ref, userId) async {
  return ref.read(userRepositoryProvider).getUser(userId);
});

class ManageSparesScreen extends ConsumerWidget {
  final String teamId;
  const ManageSparesScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sparesAsync    = ref.watch(teamSparesProvider(teamId));
    final requestsAsync  = ref.watch(spareRequestsProvider(teamId));
    final pendingCount   = requestsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Spares'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Spares',
            onPressed: () => _showAddSparesDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Pending requests ──────────────────────────────────────────────
          if (pendingCount > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('Requests',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Badge(label: Text('$pendingCount')),
                ],
              ),
            ),
            ...requestsAsync.valueOrNull!.map((req) => _SpareRequestTile(
                  request: req,
                  teamId: teamId,
                )),
            const Divider(),
          ],

          // ── Active spares ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Spares',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          sparesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (spares) => spares.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No spares on file. Tap + to add players.'),
                  )
                : Column(
                    children: spares
                        .map((s) => _SpareTile(spare: s, teamId: teamId))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddSparesDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSparesSheet(teamId: teamId),
    );
  }
}

// ── Spare request tile ─────────────────────────────────────────────────────────

class _SpareRequestTile extends ConsumerWidget {
  final SpareRequest request;
  final String teamId;
  const _SpareRequestTile({required this.request, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(request.userName.isNotEmpty
              ? request.userName[0].toUpperCase()
              : '?'),
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
                    .read(sparesRepositoryProvider)
                    .approveSpareRequest(teamId, request.userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${request.userName} added to spares.')),
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
                    .read(sparesRepositoryProvider)
                    .denySpareRequest(teamId, request.userId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active spare tile ──────────────────────────────────────────────────────────

class _SpareTile extends ConsumerWidget {
  final TeamSpare spare;
  final String teamId;
  const _SpareTile({required this.spare, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_userProvider(spare.userId));

    return ListTile(
      leading: CircleAvatar(
        child: userAsync.when(
          data: (user) => Text(user?.name.substring(0, 1).toUpperCase() ?? '?'),
          loading: () => const Icon(Icons.person),
          error: (_, __) => const Icon(Icons.person),
        ),
      ),
      title: userAsync.when(
        data: (user) => Text(user?.name ?? 'Unknown'),
        loading: () => const Text('Loading...'),
        error: (_, __) => const Text('Error'),
      ),
      subtitle: Text('Added ${_formatDate(spare.joinedAt)}'),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: () => _confirmRemove(context, ref),
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove from Spares'),
        content: const Text('Remove this player from the spares list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(sparesRepositoryProvider)
                  .removeSpares(teamId, [spare.userId]);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _AddSparesSheet extends ConsumerStatefulWidget {
  final String teamId;
  const _AddSparesSheet({required this.teamId});

  @override
  ConsumerState<_AddSparesSheet> createState() => _AddSparesSheetState();
}

class _AddSparesSheetState extends ConsumerState<_AddSparesSheet> {
  final Set<String> _selected = {};
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider(widget.teamId));
    final sparesAsync = ref.watch(teamSparesProvider(widget.teamId));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Add Spares',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        _selected.isEmpty || _loading ? null : _addSelected,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Add (${_selected.length})'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: teamAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (team) {
                  if (team == null)
                    return const Center(child: Text('Team not found'));

                  final existingIds =
                      sparesAsync.valueOrNull?.map((s) => s.userId).toSet() ??
                          {};
                  final availableIds = [...team.admins, ...team.players]
                      .where((id) => !existingIds.contains(id))
                      .toList();

                  if (availableIds.isEmpty) {
                    return const Center(
                        child: Text('All team members are already spares.'));
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: availableIds.length,
                    itemBuilder: (context, index) {
                      final userId = availableIds[index];
                      return _UserCheckboxTile(
                        userId: userId,
                        selected: _selected.contains(userId),
                        onChanged: (v) => setState(() {
                          if (v == true)
                            _selected.add(userId);
                          else
                            _selected.remove(userId);
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSelected() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(sparesRepositoryProvider)
          .addSpares(widget.teamId, _selected.toList());
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _UserCheckboxTile extends ConsumerWidget {
  final String userId;
  final bool selected;
  final ValueChanged<bool?> onChanged;
  const _UserCheckboxTile({
    required this.userId,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_userProvider(userId));

    return CheckboxListTile(
      value: selected,
      onChanged: onChanged,
      title: userAsync.when(
        data: (user) => Text(user?.name ?? 'Unknown'),
        loading: () => const Text('Loading...'),
        error: (_, __) => const Text('Error'),
      ),
      subtitle: userAsync.when(
        data: (user) => Text(user?.email ?? ''),
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}
