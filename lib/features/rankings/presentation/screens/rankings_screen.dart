import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/teams/presentation/providers/teams_provider.dart';
import '../../data/ranking_repository.dart';
import '../../domain/ranking.dart';
import '../providers/rankings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RANKINGS — COACH / TEAM ADMIN ACCESS ONLY
// Players cannot see this screen or any rankings data.
// Route guard in app_router.dart + Firestore rules both enforce this.
// ─────────────────────────────────────────────────────────────────────────────

class RankingsScreen extends ConsumerWidget {
  final String teamId;
  const RankingsScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync    = ref.watch(teamProvider(teamId));
    final rankingsAsync = ref.watch(teamRankingsProvider(teamId));

    final team = teamAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(team != null ? '${team.name} Rankings' : 'Rankings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Rankings are private — players cannot see their scores.',
            onPressed: () => _showPrivacyNote(context),
          ),
        ],
      ),
      body: SafeArea(top: false, child: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (team) {
          if (team == null) return const Center(child: Text('Team not found.'));

          final allMembers = [...team.players]; // admins not typically ranked
          if (allMembers.isEmpty) {
            return const Center(child: Text('No players on this team yet.'));
          }

          return rankingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (e, _) => Center(child: Text('Error: $e')),
            data:    (rankings) {
              final rankMap = {for (final r in rankings) r.userId: r};
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: allMembers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final uid     = allMembers[i];
                  final ranking = rankMap[uid];
                  return _PlayerRankingTile(
                    userId:  uid,
                    teamId:  teamId,
                    ranking: ranking,
                  );
                },
              );
            },
          );
        },
      )),
    );
  }

  void _showPrivacyNote(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rankings are Private'),
        content: const Text(
          'These scores are your coaching assessment only.\n\n'
          'Players cannot see their rankings or anyone else\'s scores.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _PlayerRankingTile extends ConsumerWidget {
  final String  userId, teamId;
  final Ranking? ranking;
  const _PlayerRankingTile({
    required this.userId,
    required this.teamId,
    required this.ranking,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(_userNameProvider(userId));
    final name      = nameAsync.valueOrNull ?? userId;
    final score     = ranking?.score ?? 0.0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _scoreColor(score, context),
        child: Text(
          ranking?.scoreLabel ?? '—',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
      ),
      title:    Text(name),
      subtitle: Text(ranking?.notes?.isNotEmpty == true
          ? ranking!.notes!
          : 'No notes'),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => _showEditDialog(context, ref, name),
      ),
    );
  }

  Color _scoreColor(double score, BuildContext context) {
    if (score >= 7) return Colors.green.shade600;
    if (score >= 4) return Colors.orange.shade600;
    if (score > 0)  return Colors.red.shade400;
    return Theme.of(context).colorScheme.outline;
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, String playerName) {
    double editScore = ranking?.score ?? 5.0;
    final notesCtrl  = TextEditingController(text: ranking?.notes ?? '');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Rate $playerName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score: ${editScore.toStringAsFixed(1)}',
                  style: Theme.of(ctx).textTheme.titleMedium),
              Slider(
                value:    editScore,
                min:      0,
                max:      10,
                divisions: 20,
                label:    editScore.toStringAsFixed(1),
                onChanged: (v) => setState(() => editScore = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller:  notesCtrl,
                maxLines:    3,
                decoration:  const InputDecoration(
                  labelText: 'Private notes (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Visible to coaches only',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(rankingRepositoryProvider).setRanking(Ranking(
                  userId:    userId,
                  teamId:    teamId,
                  score:     editScore,
                  notes:     notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  updatedAt: DateTime.now(),
                ));
                notesCtrl.dispose();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

final _userNameProvider = FutureProvider.family<String, String>((ref, uid) async {
  final user = await ref.read(userRepositoryProvider).getUser(uid);
  return user?.name.isNotEmpty == true ? user!.name : uid;
});
