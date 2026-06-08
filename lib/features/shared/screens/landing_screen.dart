import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';

// Store URLs — update with actual listing IDs once confirmed.
const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.sportsrostering.app';
const _appStoreUrl =
    'https://apps.apple.com/app/id6761060200';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surfaceTint,
            title: Row(
              children: [
                Icon(Icons.sports, color: cs.primary, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Sport Rosters',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Sign In'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => context.go(AppRoutes.register),
                child: const Text('Get Started'),
              ),
              const SizedBox(width: 16),
            ],
          ),

          // ── Hero ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 80 : 24,
                vertical: 64,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primaryContainer, cs.secondaryContainer],
                ),
              ),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _HeroCopy(cs: cs, theme: theme)),
                        const SizedBox(width: 48),
                        _HeroGraphic(cs: cs),
                      ],
                    )
                  : Column(
                      children: [
                        _HeroCopy(cs: cs, theme: theme),
                        const SizedBox(height: 40),
                        _HeroGraphic(cs: cs),
                      ],
                    ),
            ),
          ),

          // ── Features ─────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 80 : 24,
              vertical: 56,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Everything your team needs',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 32),
                  _FeaturesGrid(isWide: isWide),
                ],
              ),
            ),
          ),

          // ── Download CTAs ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 80 : 24,
                vertical: 56,
              ),
              color: cs.surfaceContainerHighest,
              child: Column(
                children: [
                  Text(
                    'Best experience on mobile',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Full push notifications, biometric lock, and offline access.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _StoreBadge(
                        icon: Icons.shop,
                        label: 'Google Play',
                        sublabel: 'Get it on',
                        onTap: () => _launch(_playStoreUrl),
                        cs: cs,
                      ),
                      _StoreBadge(
                        icon: Icons.apple,
                        label: 'App Store',
                        sublabel: 'Download on the',
                        onTap: () => _launch(_appStoreUrl),
                        cs: cs,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.register),
                    icon: const Icon(Icons.language),
                    label: const Text('Continue on Web instead'),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => context.go(AppRoutes.privacy),
                    child: const Text('Privacy Policy'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.terms),
                    child: const Text('Terms of Service'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.help),
                    child: const Text('Help'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// ── Hero copy ─────────────────────────────────────────────────────────────────

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.cs, required this.theme});
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Roster management\nfor every sport.',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onPrimaryContainer,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Schedule events, manage lineups, track availability, '
          'and keep your whole team in sync — free.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: cs.onPrimaryContainer.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.register),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Get Started Free'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.login),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Hero graphic (icon grid) ──────────────────────────────────────────────────

class _HeroGraphic extends StatelessWidget {
  const _HeroGraphic({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final icons = [
      (Icons.calendar_month, 'Schedule'),
      (Icons.people, 'Roster'),
      (Icons.format_list_numbered, 'Lineups'),
      (Icons.sports, '24 Sports'),
      (Icons.campaign, 'Announcements'),
      (Icons.add_circle_outline, 'Drop-ins'),
    ];

    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: icons.map((entry) {
          return Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(entry.$1, size: 28, color: cs.onPrimaryContainer),
                const SizedBox(height: 6),
                Text(
                  entry.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Features grid ─────────────────────────────────────────────────────────────

class _FeaturesGrid extends StatelessWidget {
  const _FeaturesGrid({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final features = [
      (
        Icons.calendar_month_outlined,
        'Event Scheduling',
        'Create games, practices, and drop-ins with recurring series support and automatic reminders.'
      ),
      (
        Icons.check_circle_outline,
        'RSVP & Availability',
        'Players set their availability per event. Coaches see who\'s in at a glance.'
      ),
      (
        Icons.format_list_numbered_outlined,
        'Lineup Builder',
        'Drag-and-drop manual lineups, or auto-generate using player rankings and position preferences.'
      ),
      (
        Icons.campaign_outlined,
        'Team Announcements',
        'Post updates to your team with pin support. Notify everyone in one tap.'
      ),
      (
        Icons.sports_outlined,
        '24 Sports Supported',
        'Ice hockey, soccer, dragon boating, basketball, and 20 more — each with sport-specific positions.'
      ),
      (
        Icons.group_add_outlined,
        'Drop-in Sign-ups',
        'Open sessions for casual players with auto-balanced team assignment.'
      ),
    ];

    return isWide
        ? GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.4,
            children: features.map(_FeatureCard.new).toList(),
          )
        : Column(
            children: features
                .map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _FeatureCard(f),
                    ))
                .toList(),
          );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.feature);
  final (IconData, String, String) feature;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(feature.$1, color: cs.primary, size: 32),
            const SizedBox(height: 12),
            Text(
              feature.$2,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              feature.$3,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Store badge ───────────────────────────────────────────────────────────────

class _StoreBadge extends StatelessWidget {
  const _StoreBadge({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    required this.cs,
  });
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cs.onInverseSurface, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onInverseSurface.withOpacity(0.8),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onInverseSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
