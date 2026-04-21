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
              'Tap "Join Team" on the Teams screen. You can either scan the team\'s QR code (tap "Scan QR Code") or type in the Team ID your coach shared with you. Once submitted, your coach will approve your request and the team will appear in your list.',
        ),
        _HelpTile(
          title: 'Hiding old teams',
          body:
              'If a team is inactive but you don\'t want to leave, open it and tap the eye icon in the top bar to hide it. Hidden teams are collapsed at the bottom of your Teams list. Tap the eye again to show it.',
        ),

        _SectionHeader(icon: Icons.calendar_today_outlined, label: 'Events & Schedule'),
        _HelpTile(
          title: 'Viewing upcoming events',
          body:
              'Open a team and tap the calendar icon to see all scheduled games and practices. Tap the calendar icon on the main Teams screen (top bar) to see "My Schedule" — a single list of upcoming events across all your teams.',
        ),
        _HelpTile(
          title: 'RSVPing to an event',
          body:
              'Open an event and tap Yes, No, or Maybe under "Your RSVP". Your coach sees your response immediately. You can change it any time while the event is still accepting RSVPs.',
        ),
        _HelpTile(
          title: 'Seeing your lineup position',
          body:
              'Once your coach publishes a lineup for an event, open the event detail screen to see a card showing your assigned position (and sub-team number if the event uses multiple teams).',
        ),
        _HelpTile(
          title: 'Cancelled events',
          body:
              'Cancelled events remain visible with an orange "Cancelled" banner so you\'re aware of the change. You won\'t receive reminders for cancelled events.',
        ),

        _SectionHeader(icon: Icons.campaign_outlined, label: 'Announcements'),
        _HelpTile(
          title: 'Reading team announcements',
          body:
              'Tap the megaphone icon on the team screen to open the announcements feed. Pinned announcements appear at the top. New posts from your coach appear here in real time.',
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
              'Open the event and tap the people icon (Drop-in). Tap "Sign Up" to add yourself to the list. Tap again to remove yourself. The coach can see who\'s signed up and generate balanced teams.',
        ),

        _SectionHeader(icon: Icons.person_add_outlined, label: 'Spares'),
        _HelpTile(
          title: 'Joining the spares pool',
          body:
              'On a team screen, tap "Request to join spares list". If the coach approves, you\'ll be added as a spare — available to fill in when the roster is short. You can leave the spares list at any time from the same screen.',
        ),
        _HelpTile(
          title: 'Spare notifications',
          body:
              'If your team is short of players for an event, the coach can notify all spares. You\'ll receive a push notification with the event details and a link to respond.',
        ),

        _SectionHeader(icon: Icons.tune_outlined, label: 'Your Profile & Preferences'),
        _HelpTile(
          title: 'Setting your position preferences',
          body:
              'On the team screen, tap "My Position Preferences". Select the positions you prefer to play — the coach\'s auto-lineup generator uses these to place you optimally.',
        ),
        _HelpTile(
          title: 'Updating your name or weight',
          body:
              'Tap Profile (person icon in the Teams screen top bar), then tap the edit icon on your profile card. You can update your display name and weight. Weight is optional — it is only used for dragon boat team balancing.',
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
              'In Profile → Account, use the "Push Notifications" toggle. You can also choose which types of events send you reminders: Games, Practices, and Drop-in sessions can each be toggled independently.',
        ),
        _HelpTile(
          title: 'Notification inbox',
          body:
              'Tap the inbox icon on any team screen to see all notifications your coach has sent to that team, including ones you missed.',
        ),

        _SectionHeader(icon: Icons.lock_outline, label: 'Privacy & Security'),
        _HelpTile(
          title: 'Can other players see my ranking?',
          body:
              'No. Player rankings are entered by coaches only and are completely private. Players cannot see their own ranking or anyone else\'s.',
        ),
        _HelpTile(
          title: 'Face ID / Fingerprint lock',
          body:
              'In Profile → Account, enable "Face ID / Fingerprint" to require biometric authentication every time you open the app.',
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
              'On the Teams screen tap "Create Team". Enter your team name and select the sport. You\'ll be set as team admin (coach) automatically.',
        ),
        _HelpTile(
          title: 'Inviting players',
          body:
              'Open your team and tap the QR code icon to see the team\'s QR code and Team ID. Share the QR code image or the Team ID with players — they scan or type it in "Join Team" to send a join request.',
        ),
        _HelpTile(
          title: 'Approving join requests',
          body:
              'A badge appears on your team card when there are pending requests. Open the team to see "Join Requests" at the top — approve or deny each one.',
        ),
        _HelpTile(
          title: 'Removing or promoting a player',
          body:
              'Open the team roster and long-press (or tap the menu icon) next to a player\'s name. You can remove them from the team or promote them to co-admin. Co-admins gain full coach permissions.',
        ),
        _HelpTile(
          title: 'Archiving an inactive team',
          body:
              'Tap the ⋮ overflow menu in the team\'s top bar and choose "Archive Team". Archived teams move out of the main list but nothing is deleted. Restore any time from the same menu.',
        ),

        _SectionHeader(icon: Icons.calendar_today_outlined, label: 'Scheduling Events'),
        _HelpTile(
          title: 'Creating an event',
          body:
              'Open a team, go to Events, and tap the + button. Set the type (Game, Practice, etc.), date, time, location, minimum and maximum player count, and optional RSVP deadline.',
        ),
        _HelpTile(
          title: 'Recurring events',
          body:
              'When creating an event, toggle "Recurring" and choose weekly or biweekly. The app creates a batch of events sharing a series ID. You can edit or cancel just one event or the whole series.',
        ),
        _HelpTile(
          title: 'Cancelling an event',
          body:
              'Open an event and tap ⋮ → "Cancel Event". The event stays visible with an orange banner so players know it\'s off. For recurring events, choose to cancel just this one or the whole series. Restore any cancelled event the same way.',
        ),
        _HelpTile(
          title: 'Event capacity cap',
          body:
              'Set "Max Players" when creating or editing an event. Once that many players have RSVPd Yes, additional players will see a message that the event is full and should contact you to be added to the spares list.',
        ),
        _HelpTile(
          title: 'Viewing availability',
          body:
              'Open an event to see the full availability summary — Yes, Maybe, No counts and the list of names. Tap the download icon to export as a CSV file.',
        ),
        _HelpTile(
          title: 'Logging game results',
          body:
              'After a game, open the event and tap "Log Result". Enter your team\'s score and the opponent\'s score. Results are shown on the event card and contribute to team stats.',
        ),

        _SectionHeader(icon: Icons.campaign_outlined, label: 'Announcements'),
        _HelpTile(
          title: 'Posting an announcement',
          body:
              'Tap the megaphone icon on the team screen. Tap the + button to write an announcement. Toggle "Send push notification" to alert your players immediately. Pin important announcements to keep them at the top.',
        ),

        _SectionHeader(icon: Icons.sports_score_outlined, label: 'Rankings'),
        _HelpTile(
          title: 'Rating your players',
          body:
              'Open a team and tap the Rankings icon (admin only). Tap any player to set their skill score from 0–10. Rankings are completely private — players cannot see them.',
        ),
        _HelpTile(
          title: 'What rankings are used for',
          body:
              'Rankings feed into the auto-lineup generator and the drop-in balanced team generator. Higher-ranked players are distributed evenly across teams using a snake draft.',
        ),

        _SectionHeader(icon: Icons.view_list_outlined, label: 'Lineups'),
        _HelpTile(
          title: 'Building a lineup manually',
          body:
              'Open an event and tap the Lineup icon. Drag players from the bench onto positions, or tap a position to pick from a list.',
        ),
        _HelpTile(
          title: 'Auto-generating a lineup',
          body:
              'On the Lineup screen tap the auto-generate (✨) button. It uses player rankings and position preferences to fill positions optimally. A short rewarded ad may play before generation.',
        ),
        _HelpTile(
          title: 'Sub-teams (snake draft)',
          body:
              'On the Lineup screen, tap "Sub-teams" and choose how many teams. The app drafts players in snake order by ranking, then assigns each player to a position within their team.',
        ),
        _HelpTile(
          title: 'Publishing a lineup',
          body:
              'Once you save a lineup, players can see their assigned position on the event detail screen. The lineup is live as soon as you save — there\'s no separate publish step.',
        ),
        _HelpTile(
          title: 'Exporting a lineup as PDF',
          body:
              'On the Lineup screen tap the PDF icon. The PDF lists every position and the assigned player, ready to print or share.',
        ),

        _SectionHeader(icon: Icons.group_outlined, label: 'Drop-In Sessions'),
        _HelpTile(
          title: 'Enabling drop-in for an event',
          body:
              'When creating an event, toggle "Drop-In Session". Players can then sign up themselves from the event\'s drop-in screen.',
        ),
        _HelpTile(
          title: 'Generating balanced teams',
          body:
              'Once players have signed up, tap "Generate Teams" on the drop-in screen. Choose 2–4 teams. A snake draft by ranking produces balanced teams shown as colour-coded cards.',
        ),

        _SectionHeader(icon: Icons.person_add_outlined, label: 'Spares'),
        _HelpTile(
          title: 'Managing the spares list',
          body:
              'Tap the people icon (Manage Spares) on the team screen. Approve or deny players requesting to join your spares pool. A badge shows when approval is pending.',
        ),
        _HelpTile(
          title: 'Notifying spares when short',
          body:
              'On an event detail screen, if the Yes count is below your minimum, a "Notify Spares" button appears. Tap it to send a push notification to all available spares with a link to respond.',
        ),

        _SectionHeader(icon: Icons.notifications_outlined, label: 'Push Notifications'),
        _HelpTile(
          title: 'Sending a notification to the team',
          body:
              'Tap the notification bell icon on the team or event screen. Enter a title and message. For event-specific notifications, the event context is pre-filled.',
        ),

        _SectionHeader(icon: Icons.bar_chart_outlined, label: 'Stats & Attendance'),
        _HelpTile(
          title: 'Team statistics',
          body:
              'Tap the bar chart icon on a team screen to see team stats: win/loss record, goals scored/conceded, and per-event results.',
        ),
        _HelpTile(
          title: 'Player attendance history',
          body:
              'Open the team roster and tap a player\'s name, then "Attendance". See a full history of events the player RSVPd Yes/No/Maybe to.',
        ),

        _SectionHeader(icon: Icons.admin_panel_settings_outlined, label: 'Admin Tips'),
        _HelpTile(
          title: 'Managing multiple teams',
          body:
              'You can be an admin of multiple teams at the same time. Switch between them from the Teams screen.',
        ),
        _HelpTile(
          title: 'Dragon boat seating',
          body:
              'For Dragon Boating teams, the Lineup screen is replaced with a Boat Seating screen. Players are arranged by weight for optimal balance. Export as PDF for race-day use.',
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
