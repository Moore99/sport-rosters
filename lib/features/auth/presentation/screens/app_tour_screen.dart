import 'package:flutter/material.dart';

class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      icon: Icons.groups_outlined,
      title: 'Manage Your Roster',
      body:
          'Create a team or join one with a Team ID. Coaches approve members, '
          'assign roles, and keep the roster organised across the season.',
    ),
    _Slide(
      icon: Icons.calendar_month_outlined,
      title: 'Schedule Events',
      body:
          'Create practices, games, and drop-in sessions. Set player limits, '
          'RSVP deadlines, and locations — all in one place.',
    ),
    _Slide(
      icon: Icons.how_to_reg_outlined,
      title: 'RSVP & Availability',
      body:
          'Players confirm attendance with a single tap. Coaches see who\'s in '
          'at a glance and get alerted when numbers fall below the minimum.',
    ),
    _Slide(
      icon: Icons.view_list_outlined,
      title: 'Build Lineups',
      body:
          'Drag-and-drop lineup builder with auto-generate by player ranking '
          'and position preferences. Export to PDF for game day.',
    ),
    _Slide(
      icon: Icons.notifications_outlined,
      title: 'Stay Notified',
      body:
          'Push notifications keep everyone in the loop — event reminders, '
          'roster updates, and spare requests sent straight to your phone.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast      = _page == _slides.length - 1;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Slides ──────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller:   _controller,
                onPageChanged: (p) => setState(() => _page = p),
                itemCount:    _slides.length,
                itemBuilder:  (_, i) => _SlidePage(slide: _slides[i]),
              ),
            ),

            // ── Dot indicators ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width:  _page == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _page == i
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // ── Next / Get Started ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(isLast ? 'Get Started' : 'Next'),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(slide.icon, size: 96,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 32),
          Text(
            slide.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String   title;
  final String   body;
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
  });
}
