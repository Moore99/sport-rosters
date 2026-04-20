import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../sports/data/sport_repository.dart';
import '../../../sports/domain/sport.dart';
import '../../../sports/presentation/providers/sports_provider.dart';

class SportsAdminScreen extends ConsumerWidget {
  const SportsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sportsAsync = ref.watch(sportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Sports')),
      body: sportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sports) => sports.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No sports in Firestore yet.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _seedSports(context, ref),
                      child: const Text('Seed from AppConfig'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _SportTile(sport: sports[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _seedSports(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seed Sports'),
        content: Text(
            'This will create ${AppConfig.defaultSports.length} sport documents in Firestore. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(sportRepositoryProvider);
    for (final name in AppConfig.defaultSports) {
      final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final sport = Sport(
        sportId:    id,
        name:       name,
        positions:  AppConfig.positionsForSport(name),
        categories: AppConfig.sportPositionCategories[name] ?? {},
      );
      await repo.addSport(sport);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seeded ${AppConfig.defaultSports.length} sports.')),
      );
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Sport? existing) {
    showDialog(
      context: context,
      builder: (_) => _SportEditDialog(existing: existing),
    );
  }
}

class _SportTile extends ConsumerWidget {
  final Sport sport;
  const _SportTile({required this.sport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(sport.name),
        subtitle: Text('${sport.positions.length} positions · ${sport.categories.length} categories'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _SportEditDialog(existing: sport),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${sport.name}?'),
        content: const Text(
            'This will remove the sport from the picker for new teams. Existing teams using this sport are unaffected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sportRepositoryProvider).deleteSport(sport.sportId);
    }
  }
}

class _SportEditDialog extends ConsumerStatefulWidget {
  final Sport? existing;
  const _SportEditDialog({this.existing});

  @override
  ConsumerState<_SportEditDialog> createState() => _SportEditDialogState();
}

class _SportEditDialogState extends ConsumerState<_SportEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _positionsCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _positionsCtrl = TextEditingController(
      text: widget.existing?.positions.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final positions = _positionsCtrl.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (positions.isEmpty) {
      setState(() => _error = 'At least one position is required.');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final repo = ref.read(sportRepositoryProvider);
      if (widget.existing != null) {
        await repo.updateSport(Sport(
          sportId:    widget.existing!.sportId,
          name:       name,
          positions:  positions,
          categories: widget.existing!.categories,
        ));
      } else {
        final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')
            + '_${FirebaseFirestore.instance.collection('sports').doc().id.substring(0, 4)}';
        await repo.addSport(Sport(
          sportId:    id,
          name:       name,
          positions:  positions,
          categories: {},
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _saving = false; _error = 'Save failed. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Sport' : 'Edit Sport'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Sport name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _positionsCtrl,
            decoration: const InputDecoration(
              labelText: 'Positions (comma-separated)',
              hintText: 'e.g. Centre, Left Wing, Right Wing',
            ),
            maxLines: 3,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
