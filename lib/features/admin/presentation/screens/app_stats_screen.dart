import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _appStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final result = await FirebaseFunctions.instanceFor(region: 'northamerica-northeast1')
      .httpsCallable('getAppStats')
      .call();
  return Map<String, dynamic>.from(result.data as Map);
});

class AppStatsScreen extends ConsumerWidget {
  const AppStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_appStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_appStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load stats', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(e.toString(), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => ref.invalidate(_appStatsProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader('Users'),
            _StatCard(
              icon: Icons.people,
              color: Colors.blue,
              label: 'Real Users',
              value: '${stats['totalRealUsers']}',
              subtitle: 'Excludes test accounts & admins',
            ),
            _StatCard(
              icon: Icons.person_add,
              color: Colors.green,
              label: 'New This Week',
              value: '${stats['newThisWeek']}',
            ),
            _StatCard(
              icon: Icons.trending_up,
              color: Colors.teal,
              label: 'New This Month',
              value: '${stats['newThisMonth']}',
            ),
            const SizedBox(height: 8),
            _SectionHeader('Activity'),
            _StatCard(
              icon: Icons.groups,
              color: Colors.orange,
              label: 'Total Teams',
              value: '${stats['totalTeams']}',
            ),
            _StatCard(
              icon: Icons.event,
              color: Colors.purple,
              label: 'Events (Last 30 Days)',
              value: '${stats['recentEvents']}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        subtitle: subtitle != null ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall) : null,
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ),
    );
  }
}
