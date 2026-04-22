import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../features/auth/data/user_repository.dart';
import '../../data/team_repository.dart';
import '../../domain/team.dart';

class JoinViaLinkScreen extends ConsumerStatefulWidget {
  final String teamId;
  const JoinViaLinkScreen({super.key, required this.teamId});

  @override
  ConsumerState<JoinViaLinkScreen> createState() => _JoinViaLinkScreenState();
}

class _JoinViaLinkScreenState extends ConsumerState<JoinViaLinkScreen> {
  Team? _team;
  bool _loadingTeam = true;
  bool _submitting  = false;
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    final team = await ref.read(teamRepositoryProvider).getTeam(widget.teamId);
    if (mounted) setState(() { _team = team; _loadingTeam = false; });
  }

  Future<void> _sendRequest() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push(AppRoutes.login);
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final team = _team!;
      if (team.isMember(user.uid)) {
        context.go('/teams/${team.teamId}');
        return;
      }

      final profile = await ref.read(userRepositoryProvider).getUser(user.uid);
      await ref.read(teamRepositoryProvider).requestToJoin(
        team.teamId,
        user.uid,
        profile?.name ?? user.email ?? '',
        user.email ?? '',
      );
      unawaited(ref.read(analyticsServiceProvider).logTeamJoined(team.sport));

      if (mounted) setState(() { _done = true; _submitting = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to send request. Please try again.'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join Team')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loadingTeam
              ? const Center(child: CircularProgressIndicator())
              : _team == null
                  ? _NotFound(onGoHome: () => context.go(AppRoutes.teams))
                  : _done
                      ? _Success(team: _team!, onGoHome: () => context.go(AppRoutes.teams))
                      : _JoinPrompt(
                          team: _team!,
                          isLoggedIn: user != null,
                          submitting: _submitting,
                          error: _error,
                          onJoin: _sendRequest,
                          onLogin: () => context.push(AppRoutes.login),
                        ),
        ),
      ),
    );
  }
}

class _JoinPrompt extends StatelessWidget {
  final Team team;
  final bool isLoggedIn;
  final bool submitting;
  final String? error;
  final VoidCallback onJoin;
  final VoidCallback onLogin;

  const _JoinPrompt({
    required this.team,
    required this.isLoggedIn,
    required this.submitting,
    required this.error,
    required this.onJoin,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: team.logoUrl != null ? NetworkImage(team.logoUrl!) : null,
          child: team.logoUrl == null
              ? Text(team.sport.substring(0, 1),
                  style: const TextStyle(fontSize: 28))
              : null,
        ),
        const SizedBox(height: 24),
        Text("You've been invited to join",
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(team.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(team.sport,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 32),
        if (!isLoggedIn) ...[
          const Text(
            'Sign in or create an account to send a join request.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Sign In / Register'),
            onPressed: onLogin,
          ),
        ] else ...[
          if (error != null) ...[
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            icon: submitting
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.group_add),
            label: const Text('Send Join Request'),
            onPressed: submitting ? null : onJoin,
          ),
        ],
      ],
    );
  }
}

class _Success extends StatelessWidget {
  final Team team;
  final VoidCallback onGoHome;
  const _Success({required this.team, required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
        const SizedBox(height: 24),
        Text('Request sent!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Your request to join ${team.name} has been sent to the coach.',
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton(onPressed: onGoHome, child: const Text('Go to My Teams')),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  final VoidCallback onGoHome;
  const _NotFound({required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 72, color: Colors.grey),
        const SizedBox(height: 24),
        Text('Team not found',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('This invite link may be invalid or expired.',
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton(onPressed: onGoHome, child: const Text('Go to My Teams')),
      ],
    );
  }
}
