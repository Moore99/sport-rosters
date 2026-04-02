import 'package:flutter/material.dart';

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'Kernkraft Consulting Inc.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: April 2026',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              context,
              'Our Commitment',
              'Kernkraft Consulting Inc. is committed to making Sport Rosters accessible to everyone, '
              'including people with disabilities. We aim to meet or exceed platform accessibility '
              'guidelines on both iOS and Android.',
            ),

            _buildSection(
              context,
              'Screen Readers',
              'Sport Rosters is compatible with VoiceOver (iOS) and TalkBack (Android). '
              'Interactive elements include semantic labels so screen readers can describe '
              'them accurately.',
            ),

            _buildSection(
              context,
              'Dynamic Text Sizing',
              'The app respects your device\'s system font size setting. Increasing the text '
              'size in Accessibility settings will scale text throughout the app. Avatars and '
              'touch targets scale proportionally to remain usable at larger text sizes.',
            ),

            _buildSection(
              context,
              'Dark Mode',
              'Sport Rosters follows your device\'s system appearance setting. Switching to '
              'Dark Mode reduces eye strain and improves readability for many users.',
            ),

            _buildSection(
              context,
              'Colour Contrast',
              'UI elements are designed to meet WCAG AA contrast ratios. Meaning is never '
              'conveyed by colour alone — icons and labels are always present.',
            ),

            _buildSection(
              context,
              'Biometric Authentication',
              'Face ID, Touch ID, and fingerprint unlock are supported as an alternative to '
              'password entry, which can be easier for users with motor or cognitive '
              'accessibility needs.',
            ),

            _buildSection(
              context,
              'Known Limitations',
              'We are continuously improving accessibility. Current known limitations:\n\n'
              '• Drag-and-drop in the lineup builder does not have a full switch-access '
              'alternative. Tap-based reordering is planned.\n\n'
              '• Complex data grids (boat seating, availability) may have reduced screen '
              'reader context on older devices.',
            ),

            _buildSection(
              context,
              'Feedback',
              'If you encounter an accessibility barrier or have a suggestion, please contact '
              'us at admin@nuclear-motd.com. We take all accessibility feedback seriously '
              'and aim to respond within 5 business days.',
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
