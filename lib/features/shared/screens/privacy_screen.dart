import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                    'Last updated: March 2026',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              'Introduction',
              'Sport Rosters ("the App", "we", "us", or "our") is operated by Kernkraft Consulting Inc. and is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application. Kernkraft Consulting Inc. also publishes Nuclear Message of the Day ("Nuclear MOTD") and Nuclear Quiz; a combined policy covering all apps is available at https://nuclear-motd.com/privacy',
            ),

            _buildSection(
              'Information We Collect',
              '''We collect information you provide directly to us, including:

• Account Information: Name and email address, used to create and identify your account.

• Optional Profile Data: Phone number and profile photo, collected only if you choose to provide them.

• Team & Roster Data: Team memberships, event RSVPs, availability responses, and drop-in sign-ups that you submit through the App.

• Push Notification Token: If you grant permission, a device token used to deliver push notifications.

• Usage Data: Basic information about how you interact with the App, used to improve the service.''',
            ),

            _buildSection(
              'How We Use Your Information',
              '''We use the information we collect to:

• Provide the App's core features: team management, event scheduling, RSVP tracking, and drop-in session sign-ups
• Deliver push notifications you have opted into
• Resolve your name for display to other team members (e.g. roster and availability lists)
• Respond to your support requests
• Comply with legal obligations''',
            ),

            _buildSection(
              'Data Sharing',
              '''We do not sell your personal information. Your data may be visible to other users as follows:

• Your name is visible to members of any team you belong to.
• Your RSVP responses are visible to team admins.
• Your drop-in sign-up status is visible to team members for sessions you join.

We do not share your data with third parties except as required by law or to operate the service (e.g. Firebase/Google Cloud, which stores data under strict confidentiality).''',
            ),

            _buildSection(
              'Coach Rankings — Private Data',
              'Player rankings entered by coaches (team admins) are strictly private. Players cannot view their own rankings or those of other players. Rankings are used only internally to assist with lineup generation.',
            ),

            _buildSection(
              'Data Storage & Region',
              'All data is stored in Google Cloud Firestore in the northamerica-northeast2 region (Toronto, Canada), selected to comply with Canadian privacy law (PIPEDA).',
            ),

            _buildSection(
              'Data Retention',
              'We retain your personal information for as long as your account is active. You may request full deletion of your account and all associated data at any time from within the App (Profile → Delete Account). Deletion is permanent and cannot be undone.',
            ),

            _buildSection(
              'Data Security',
              'We implement appropriate technical and organizational measures to protect your personal information, including encryption of data in transit (TLS) and at rest, and Firebase Security Rules that enforce per-user access controls.',
            ),

            _buildSection(
              'Your Rights',
              '''Depending on your location, you may have the following rights:

• Access: Request a copy of your personal data
• Correction: Request correction of inaccurate data
• Deletion: Request deletion of your data (also available in-app)
• Portability: Request transfer of your data
• Objection: Object to certain processing of your data

To exercise these rights, contact us at privacy@nuclear-motd.com''',
            ),

            _buildSection(
              'GDPR Compliance',
              'For users in the European Economic Area (EEA), we process personal data in accordance with the General Data Protection Regulation (GDPR). Our lawful bases for processing include consent, legitimate interests, and contractual necessity.',
            ),

            _buildSection(
              'PIPEDA Compliance',
              'For users in Canada, we comply with the Personal Information Protection and Electronic Documents Act (PIPEDA). We obtain meaningful consent for the collection, use, and disclosure of personal information.',
            ),

            _buildSection(
              'Children\'s Privacy',
              'The App is not intended for individuals under the age of 13. We do not knowingly collect personal information from children.',
            ),

            _buildSection(
              'Push Notifications',
              'Push notifications are optional and require your explicit permission. You may revoke notification permission at any time through your device settings.',
            ),

            _buildSection(
              'Advertising',
              'The free version of the App displays ads served by Google AdMob. AdMob may use device identifiers and usage data to show relevant ads. You can remove all ads with the one-time "Remove Ads" purchase.',
            ),

            _buildSection(
              'Changes to This Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the App and updating the "Last updated" date above.',
            ),

            _buildSection(
              'Contact Us',
              '''If you have questions about this Privacy Policy, please contact us:

Email: privacy@nuclear-motd.com''',
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kernkraft Consulting Inc. is committed to protecting your privacy and handling your data responsibly.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
