import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/user_repository.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';
import '../../domain/availability.dart';

final _teamStatsProvider =
    FutureProvider.autoDispose.family<_TeamStatsData, String>(
  (ref, teamId) async {
    final repo = ref.read(eventRepositoryProvider);
    final events = await repo.fetchPastTeamEvents(teamId);

    final games = events.where((e) => e.type == EventType.game).toList();
    games.sort((a, b) => b.date.compareTo(a.date));

    int wins = 0, losses = 0, ties = 0;
    final results = <String>[];
    for (final g in games) {
      if (g.gameResult != null) {
        final label = g.gameResult!.resultLabel;
        results.add(label);
        if (label == 'W')
          wins++;
        else if (label == 'L')
          losses++;
        else
          ties++;
      }
    }

    final lastTen = results.take(10).toList();

    return _TeamStatsData(
      events: events,
      games: games,
      wins: wins,
      losses: losses,
      ties: ties,
      lastTen: lastTen,
    );
  },
);

final _playerAttendanceProvider =
    FutureProvider.autoDispose.family<List<_PlayerAttendance>, String>(
  (ref, teamId) async {
    final repo = ref.read(eventRepositoryProvider);
    final events = await repo.fetchPastTeamEvents(teamId);

    if (events.isEmpty) return [];

    final avail = await repo.fetchAllAvailabilityForTeam(teamId);

    final byUser = <String, List<Event>>{};
    for (final a in avail) {
      byUser.putIfAbsent(a.userId, () => []);
      final event = events.firstWhere((e) => e.eventId == a.eventId,
          orElse: () => Event(
                eventId: '',
                teamId: teamId,
                type: EventType.game,
                date: DateTime.now(),
                location: '',
                minPlayers: 1,
                maxPlayers: 1,
                allowSignups: false,
                createdAt: DateTime.now(),
              ));
      if (event.eventId.isNotEmpty) {
        byUser[a.userId]!.add(event);
      }
    }

    final userRepo = ref.read(userRepositoryProvider);
    final playerStats = <_PlayerAttendance>[];

    for (final userId in byUser.keys) {
      final userEvents = byUser[userId]!;
      final userAvails = avail.where((a) => a.userId == userId).toList();

      if (userEvents.length < 3) continue;

      int yesCount = 0;
      for (final a in userAvails) {
        if (a.response == AvailabilityResponse.yes) yesCount++;
      }

      final rate = userEvents.isEmpty ? 0.0 : yesCount / userEvents.length;

      final user = await userRepo.getUser(userId);
      playerStats.add(_PlayerAttendance(
        userId: userId,
        name: user?.name ?? userId,
        yesRate: rate,
        totalEvents: userEvents.length,
        yesCount: yesCount,
      ));
    }

    playerStats.sort((a, b) => b.yesRate.compareTo(a.yesRate));
    return playerStats;
  },
);

class _TeamStatsData {
  final List<Event> events;
  final List<Event> games;
  final int wins, losses, ties;
  final List<String> lastTen;
  const _TeamStatsData({
    required this.events,
    required this.games,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.lastTen,
  });

  int get totalGames => wins + losses + ties;
  double get winPct => totalGames == 0 ? 0.0 : wins / totalGames;
}

class _PlayerAttendance {
  final String userId;
  final String name;
  final double yesRate;
  final int totalEvents;
  final int yesCount;
  const _PlayerAttendance({
    required this.userId,
    required this.name,
    required this.yesRate,
    required this.totalEvents,
    required this.yesCount,
  });
}

class TeamStatsScreen extends ConsumerWidget {
  final String teamId;
  const TeamStatsScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_teamStatsProvider(teamId));
    final playerStatsAsync = ref.watch(_playerAttendanceProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Team Stats')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _RecordCard(stats: stats),
            const SizedBox(height: 16),
            _LastTenCard(stats: stats),
            const SizedBox(height: 16),
            _AttendanceLeaderboard(statsAsync: playerStatsAsync),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final _TeamStatsData stats;
  const _RecordCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Season Record',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatColumn('Wins', stats.wins.toString(), Colors.green),
                _StatColumn('Losses', stats.losses.toString(), Colors.red),
                _StatColumn('Ties', stats.ties.toString(), Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${stats.winPct.toStringAsFixed(3)} win rate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${stats.totalGames} games played',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatColumn(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LastTenCard extends StatelessWidget {
  final _TeamStatsData stats;
  const _LastTenCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.lastTen.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Results',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stats.lastTen.map((r) {
                final color = switch (r) {
                  'W' => Colors.green,
                  'L' => Colors.red,
                  _ => Colors.grey,
                };
                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color),
                  ),
                  child: Center(
                    child: Text(
                      r,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceLeaderboard extends StatelessWidget {
  final AsyncValue<List<_PlayerAttendance>> statsAsync;
  const _AttendanceLeaderboard({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Attendance',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('(min 3 events)',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (players) {
                if (players.isEmpty) {
                  return const Text('No attendance data yet.');
                }
                return Column(
                  children: [
                    for (int i = 0; i < players.length; i++)
                      _AttendanceRow(
                        rank: i + 1,
                        player: players[i],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final int rank;
  final _PlayerAttendance player;
  const _AttendanceRow({required this.rank, required this.player});

  @override
  Widget build(BuildContext context) {
    final pct = (player.yesRate * 100).toStringAsFixed(0);
    final medal = switch (rank) {
      1 => '🏆',
      2 => '🥈',
      3 => '🥉',
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              medal.isNotEmpty ? medal : '#$rank',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$pct%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: player.yesRate >= 0.8
                  ? Colors.green
                  : player.yesRate >= 0.5
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${player.yesCount}/${player.totalEvents})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
