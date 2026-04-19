import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../../../features/auth/domain/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/team_repository.dart';
import '../../domain/admin_role.dart';
import '../../domain/join_request.dart';
import '../../domain/team.dart';

// ── Current user Firestore profile ────────────────────────────────────────────

final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.read(userRepositoryProvider).watchUser(user.uid);
});

// ── User's teams list ─────────────────────────────────────────────────────────
// Re-fetches whenever the user profile's teams array changes.

final userTeamsProvider = FutureProvider<List<Team>>((ref) async {
  final profile = await ref.watch(currentUserProfileProvider.future);
  if (profile == null || profile.teams.isEmpty) return [];

  final repo    = ref.read(teamRepositoryProvider);
  // Catch per-team errors (permission denied, deleted team) so one bad team
  // doesn't prevent the rest from loading.
  final results = await Future.wait(
    profile.teams.map((id) async {
      try { return await repo.getTeam(id); } catch (_) { return null; }
    }),
  );
  return results.whereType<Team>().toList();
});

// ── Single team (real-time stream) ───────────────────────────────────────────
// Watches currentUserProvider so the stream restarts on sign-out/sign-in,
// preventing stale error state from carrying over between accounts.

final teamProvider = StreamProvider.family<Team?, String>((ref, teamId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(null);
  return ref.read(teamRepositoryProvider).watchTeam(teamId);
});

// ── Pending join requests for a team (admin only) ─────────────────────────────

final pendingRequestsProvider =
    StreamProvider.family<List<JoinRequest>, String>((ref, teamId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(teamRepositoryProvider).watchPendingRequests(teamId);
});

// ── Admin participation roles for a team ──────────────────────────────────────
// Maps adminUid → AdminParticipation. Missing entries default to player.

final adminRolesProvider =
    StreamProvider.family<Map<String, AdminParticipation>, String>((ref, teamId) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value({});
  return ref.read(teamRepositoryProvider).watchAdminRoles(teamId);
});
