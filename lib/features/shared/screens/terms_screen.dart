import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
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
              'Acceptance of Terms',
              'By downloading or using Sport Rosters ("the App"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.',
            ),

            _buildSection(
              'Description of Service',
              'Sport Rosters is a team management application that helps coaches and players organize rosters, schedule events, track availability, manage lineups, and coordinate drop-in sessions for recreational and competitive sports teams.',
            ),

            _buildSection(
              'User Accounts',
              '''To use the App, you must:

• Provide accurate and complete registration information
• Maintain the security of your account credentials
• Promptly update your information if it changes
• Be at least 13 years of age
• Not share your account with others

You are responsible for all activities that occur under your account.''',
            ),

            _buildSection(
              'User Roles',
              '''The App has two user roles:

• Player: Can view team schedules, submit availability RSVPs, sign up for drop-in sessions, and manage their own profile.

• Team Admin (Coach): Can manage rosters, create and edit events, set lineups, view all availability, manage drop-in sessions, and maintain private player rankings.

Team admins are responsible for the appropriate use of administrative features within their teams.''',
            ),

            _buildSection(
              'Acceptable Use',
              '''You agree not to:

• Use the App for any unlawful purpose
• Submit false or misleading information
• Attempt to gain unauthorized access to data belonging to other users or teams
• Interfere with or disrupt the App or its servers
• Violate any applicable laws or regulations
• Impersonate any person or entity
• Harvest or collect other users' information without consent''',
            ),

            _buildSection(
              'Privacy of Rankings',
              'Player rankings are entered by team admins for internal use only. You agree not to attempt to access, infer, or share ranking data that you are not authorized to view. Circumventing the App\'s access controls to view rankings is a violation of these Terms.',
            ),

            _buildSection(
              'In-App Purchases',
              '''The App offers a one-time purchase ("Remove Ads") that permanently removes advertising. By making a purchase, you agree to the terms of the relevant app store (Google Play or Apple App Store).

• Purchases are non-refundable except as required by applicable law or app store policy.
• Purchases are tied to your app store account and can be restored on other devices using "Restore Purchase".
• We reserve the right to modify pricing with reasonable notice.''',
            ),

            _buildSection(
              'Advertising',
              'The free version of the App displays advertisements served by Google AdMob. We are not responsible for the content of third-party advertisements.',
            ),

            _buildSection(
              'Intellectual Property',
              'The App and its original content are owned by Kernkraft Consulting Inc. and are protected by copyright and other intellectual property laws. You may not reproduce, distribute, or create derivative works without our express permission.',
            ),

            _buildSection(
              'Disclaimer of Warranties',
              'THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, OR SECURE. THE APP IS INTENDED TO ASSIST WITH TEAM ORGANIZATION AND SHOULD NOT BE RELIED UPON AS THE SOLE MEANS OF COMMUNICATING TIME-SENSITIVE INFORMATION.',
            ),

            _buildSection(
              'Limitation of Liability',
              'TO THE MAXIMUM EXTENT PERMITTED BY LAW, KERNKRAFT CONSULTING INC. SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF THE APP, INCLUDING BUT NOT LIMITED TO SCHEDULING ERRORS, MISSED EVENTS, OR ROSTER DISPUTES.',
            ),

            _buildSection(
              'Indemnification',
              'You agree to indemnify and hold harmless Kernkraft Consulting Inc. and its officers, directors, employees, and agents from any claims, damages, or expenses arising from your use of the App or violation of these Terms.',
            ),

            _buildSection(
              'Termination',
              'We may suspend or terminate your account at any time for violation of these Terms. You may delete your account at any time from within the App (Profile → Delete Account). Upon deletion, all your data is permanently removed.',
            ),

            _buildSection(
              'Changes to Terms',
              'We reserve the right to modify these Terms at any time. We will notify users of significant changes through the App. Continued use of the App after changes constitutes acceptance of the new Terms.',
            ),

            _buildSection(
              'Governing Law',
              'These Terms shall be governed by and construed in accordance with the laws of Canada, without regard to conflict of law principles.',
            ),

            _buildSection(
              'Contact Information',
              'For questions about these Terms, please contact us:\n\nEmail: privacy@nuclear-motd.com',
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agreement',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By using Sport Rosters, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '© ${DateTime.now().year} Kernkraft Consulting Inc.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
