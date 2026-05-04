import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
              Text('Failed to load stats',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(e.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => ref.invalidate(_appStatsProvider),
                  child: const Text('Retry')),
            ],
          ),
        ),
        data: (stats) {
          final realUsersList   = _toList(stats['realUsersList']);
          final newThisWeekList = _toList(stats['newThisWeekList']);
          final newThisMonthList= _toList(stats['newThisMonthList']);
          final teamsList       = _toList(stats['teamsList']);
          final recentEventsList= _toList(stats['recentEventsList']);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader('Users'),
              _StatCard(
                icon: Icons.people,
                color: Colors.blue,
                label: 'Real Users',
                value: '${stats['totalRealUsers']}',
                subtitle: 'Excludes test accounts & admins',
                onTap: () => _showUserSheet(context, 'Real Users', realUsersList),
              ),
              _StatCard(
                icon: Icons.person_add,
                color: Colors.green,
                label: 'New This Week',
                value: '${stats['newThisWeek']}',
                onTap: newThisWeekList.isEmpty
                    ? null
                    : () => _showUserSheet(context, 'New This Week', newThisWeekList),
              ),
              _StatCard(
                icon: Icons.trending_up,
                color: Colors.teal,
                label: 'New This Month',
                value: '${stats['newThisMonth']}',
                onTap: newThisMonthList.isEmpty
                    ? null
                    : () => _showUserSheet(context, 'New This Month', newThisMonthList),
              ),
              const SizedBox(height: 8),
              _SectionHeader('Activity'),
              _StatCard(
                icon: Icons.groups,
                color: Colors.orange,
                label: 'Total Teams',
                value: '${stats['totalTeams']}',
                onTap: () => _showTeamSheet(context, teamsList),
              ),
              _StatCard(
                icon: Icons.event,
                color: Colors.purple,
                label: 'Events (Last 30 Days)',
                value: '${stats['recentEvents']}',
                onTap: recentEventsList.isEmpty
                    ? null
                    : () => _showEventSheet(context, recentEventsList),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _toList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _showUserSheet(
      BuildContext context, String title, List<Map<String, dynamic>> users) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(
        title: title,
        children: users.map((u) {
          final joined = _fmtDate(u['createdAt'] as String?);
          final teams  = u['teamCount'] as int? ?? 0;
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
            title:    Text(u['name'] as String? ?? '—'),
            subtitle: Text(u['email'] as String? ?? ''),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$teams team${teams == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12)),
                if (joined != null)
                  Text(joined,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showTeamSheet(BuildContext context, List<Map<String, dynamic>> teams) {
    final sorted = [...teams]
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(
        title: 'All Teams',
        children: sorted.map((t) {
          final members = t['memberCount'] as int? ?? 0;
          final created = _fmtDate(t['createdAt'] as String?);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withValues(alpha: 0.15),
              child: Text(
                (t['sport'] as String? ?? '?').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.orange),
              ),
            ),
            title:    Text(t['name'] as String? ?? '—'),
            subtitle: Text(t['sport'] as String? ?? ''),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$members member${members == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12)),
                if (created != null)
                  Text(created,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showEventSheet(BuildContext context, List<Map<String, dynamic>> events) {
    final sorted = [...events]
      ..sort((a, b) {
        final da = a['date'] as String? ?? '';
        final db = b['date'] as String? ?? '';
        return db.compareTo(da); // newest first
      });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(
        title: 'Events — Last 30 Days',
        children: sorted.map((e) {
          final type     = _eventTypeLabel(e['type'] as String? ?? '');
          final teamName = e['teamName'] as String? ?? '—';
          final sport    = e['sport']    as String? ?? '';
          final date     = _fmtDate(e['date'] as String?);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withValues(alpha: 0.15),
              child: Text(_eventTypeIcon(e['type'] as String? ?? ''),
                  style: const TextStyle(fontSize: 16)),
            ),
            title:    Text('$type — $teamName'),
            subtitle: Text(sport),
            trailing: date != null
                ? Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey))
                : null,
          );
        }).toList(),
      ),
    );
  }

  String? _fmtDate(String? iso) {
    if (iso == null) return null;
    try {
      return DateFormat('MMM d, y').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return null;
    }
  }

  String _eventTypeLabel(String type) => switch (type) {
    'game'     => 'Game',
    'practice' => 'Practice',
    'dropIn'   => 'Drop-in',
    _          => type,
  };

  String _eventTypeIcon(String type) => switch (type) {
    'game'     => '🏆',
    'practice' => '🏋️',
    'dropIn'   => '🔓',
    _          => '📅',
  };
}

// ── Detail bottom sheet ────────────────────────────────────────────────────────

class _DetailSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _DetailSheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${children.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: children.isEmpty
                ? Center(
                    child: Text('None',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline)))
                : ListView(
                    controller: controller,
                    children: children,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────────

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
  final Color    color;
  final String   label;
  final String   value;
  final String?  subtitle;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title:    Text(label),
        subtitle: subtitle != null
            ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
