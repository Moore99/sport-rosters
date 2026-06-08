import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

/// Shown to new users who have no teams yet.
/// Exits naturally once the user creates or joins a team (teams list becomes
/// non-empty, which removes the router redirect that lands here).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/app_icon.png',
                    height: 88,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.sports, size: 88),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Sports Rostering',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Schedule games, build lineups, and keep your team in sync. '
                    'Start by creating a new team or joining one.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Create a Team'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () => context.push(AppRoutes.createTeam),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Join a Team'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () => context.go(AppRoutes.teams),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.teams),
                    child: const Text('I\'ll look around first'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
