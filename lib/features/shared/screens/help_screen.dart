import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Help'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person_outline), text: 'Players'),
              Tab(icon: Icon(Icons.sports_outlined), text: 'Coaches'),
            ],
          ),
        ),
        body: SafeArea(top: false, child: TabBarView(
          children: const [
            _PlayerHelp(),
            _CoachHelp(),
          ],
        )),
      ),
    );
  }
}

// ── Player Help ────────────────────────────────────────────────────────────────

class _PlayerHelp extends StatelessWidget {
  const _PlayerHelp();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SectionHeader(icon: Icons.rocket_launch_outlined, label: 'Getting Started'),
        _HelpTile(
          title: 'Joining a team',
          body:
              'Ask your coach for the team\'s invite code. On the Teams screen tap "Join Team", enter the code, and submit a join request. Your coach will approve it — you\'ll see the team appear once approved.',
        ),
        _HelpTile(
          title: 'Switching between teams',
          body:
              'The Teams screen lists all your teams. Tap any team to open it. Use the back button to return and switch to another.',
        ),

        _SectionHeader(icon: Icons.calendar_today_outlined, label: 'Events & Schedule'),
        _HelpTile(
          title: 'Viewing upcoming events',
          body:
              'Open a team and tap "Events" to see all scheduled games and practices, sorted by date.',
        ),
        _HelpTile(
          title: 'RSVPing to an event',
          body:
              'Open an event and tap Yes, No, or Maybe under "My Availability". Your coach sees your response immediately. You can change it at any time before the event.',
        ),

        _SectionHeader(icon: Icons.group_outlined, label: 'Drop-In Sessions'),
        _HelpTile(
          title: 'What is a drop-in session?',
          body:
              'Drop-in sessions are open sign-up events — typically casual games where anyone on the team can join. Unlike regular events, there\'s no pre-set roster.',
        ),
        _HelpTile(
          title: 'Signing up for a drop-in',
          body:
              'Open the event and tap the drop-in tab. Tap "Sign Up" to add yourself to the list. Tap again to remove yourself. The coach can see who\'s signed up and generate balanced teams.',
        ),

        _SectionHeader(icon: Icons.tune_outlined, label: 'Your Profile & Preferences'),
        _HelpTile(
          title: 'Setting your position preferences',
          body:
              'On the team roster screen, tap your name then "Position Preferences". Select your preferred positions — the coach\'s auto-lineup generator uses these to place you in a position you want to play.',
        ),
        _HelpTile(
          title: 'Changing your name or weight',
          body:
              'Tap Profile (bottom of the screen), then tap the edit (pencil) icon on your profile card. You can update your display name and your weight in kg. Weight is optional — it is only used for dragon boat team balancing.',
        ),
        _HelpTile(
          title: 'Light and dark mode',
          body:
              'In Profile, use the Theme selector to choose Light, Dark, or System (follows your device setting).',
        ),

        _SectionHeader(icon: Icons.notifications_outlined, label: 'Notifications'),
        _HelpTile(
          title: 'Turning notifications on or off',
          body:
              'Push notifications require your permission. If you declined when first asked, go to your device Settings → Apps → Sports Rostering → Notifications to enable them.',
        ),

        _SectionHeader(icon: Icons.lock_outline, label: 'Privacy'),
        _HelpTile(
          title: 'Can other players see my ranking?',
          body:
              'No. Player rankings are entered by coaches only and are completely private. Players cannot see their own ranking or anyone else\'s.',
        ),
        _HelpTile(
          title: 'Deleting your account',
          body:
              'Go to Profile → Delete Account. This permanently deletes all your data — availability, drop-in history, team memberships, and your login. This cannot be undone.',
        ),
      ],
    );
  }
}

// ── Coach Help ─────────────────────────────────────────────────────────────────

class _CoachHelp extends StatelessWidget {
  const _CoachHelp();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SectionHeader(icon: Icons.rocket_launch_outlined, label: 'Getting Started'),
        _HelpTile(
          title: 'Creating a team',
          body:
              'On the Teams screen tap the + button. Enter your team name and select the sport. You\'ll be set as team admin (coach) automatically.',
        ),
        _HelpTile(
          title: 'Inviting players',
          body:
              'Open your team and tap the share/invite icon to see the team\'s invite code. Share it with players — they enter it in "Join Team" to send a join request.',
        ),
        _HelpTile(
          title: 'Approving join requests',
          body:
              'A badge appears on your team when there are pending requests. Open the team and go to "Join Requests" to approve or deny each one.',
        ),
        _HelpTile(
          title: 'Removing a player',
          body:
              'Open the team roster, tap the player\'s name, and tap "Remove from Team".',
        ),

        _SectionHeader(icon: Icons.calendar_today_outlined, label: 'Scheduling Events'),
        _HelpTile(
          title: 'Creating an event',
          body:
              'Open a team, go to Events, and tap the + button. Set the type (Game, Practice, Tournament, etc.), date, time, location, and minimum player count.',
        ),
        _HelpTile(
          title: 'Viewing availability',
          body:
              'Open an event to see the availability summary — how many players said Yes, Maybe, or No. Tap the download icon to export as a CSV.',
        ),

        _SectionHeader(icon: Icons.sports_score_outlined, label: 'Rankings'),
        _HelpTile(
          title: 'Rating your players',
          body:
              'Open a team and tap Rankings (lock icon — admin only). Tap any player to set their overall skill score from 0–10. Rankings are completely private — players cannot see them.',
        ),
        _HelpTile(
          title: 'What rankings are used for',
          body:
              'Rankings feed into the auto-lineup generator and drop-in balanced team generator. Higher-ranked players are distributed evenly across teams using a snake draft.',
        ),

        _SectionHeader(icon: Icons.view_list_outlined, label: 'Lineups'),
        _HelpTile(
          title: 'Building a lineup manually',
          body:
              'Open an event and tap "Lineup". Drag players from the bench onto positions, or tap a position to assign a player from a list.',
        ),
        _HelpTile(
          title: 'Auto-generating a lineup',
          body:
              'On the Lineup screen tap the ✨ auto-generate button. The generator uses your player rankings and their position preferences to fill the lineup optimally.',
        ),
        _HelpTile(
          title: 'Exporting a lineup as PDF',
          body:
              'On the Lineup screen tap the PDF icon in the top-right corner. The PDF lists every position and the assigned player, ready to print or share.',
        ),

        _SectionHeader(icon: Icons.group_outlined, label: 'Drop-In Sessions'),
        _HelpTile(
          title: 'Enabling drop-in for an event',
          body:
              'Open an event and tap the Drop-In tab. Players can then sign up themselves. You can see the full sign-up list in real time.',
        ),
        _HelpTile(
          title: 'Generating balanced teams',
          body:
              'Once players have signed up, tap "Generate Teams". Choose how many teams (2–4). The app uses a snake draft based on rankings to create balanced teams. Results are shown as colour-coded team cards.',
        ),

        _SectionHeader(icon: Icons.tune_outlined, label: 'Player Preferences'),
        _HelpTile(
          title: 'Viewing a player\'s position preferences',
          body:
              'Open the team roster and tap a player\'s name. Tap "Position Preferences" to see (and edit) which positions they prefer to play.',
        ),

        _SectionHeader(icon: Icons.admin_panel_settings_outlined, label: 'Admin Tips'),
        _HelpTile(
          title: 'Multiple teams',
          body:
              'You can be an admin of multiple teams simultaneously. Switch between them from the Teams screen.',
        ),
        _HelpTile(
          title: 'Promoting a player to co-admin',
          body:
              'Open the team roster and tap the person-with-gear icon next to a player\'s name. Confirm the promotion — they\'ll immediately gain full coach permissions (scheduling, rankings, lineups, roster management).',
        ),
      ],
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  final String title;
  final String body;
  const _HelpTile({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 14),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              body,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.6,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
