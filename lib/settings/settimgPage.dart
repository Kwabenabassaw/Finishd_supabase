 import 'package:flutter/material.dart';
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the data structure for the settings sections
    final List<Map<String, dynamic>> sections = [
      {
        'title': 'Playback',
        'items': [
          {'icon': Icons.closed_caption_outlined, 'title': 'Subtitles'},
          {'icon': Icons.play_circle_outline, 'title': 'Autoplay Next Episode'},
        ]
      },
      {
        'title': 'App Preferences',
        'items': [
          {'icon': Icons.contrast, 'title': 'Theme'},
          {'icon': Icons.language, 'title': 'Language'},
          {'icon': Icons.notifications_none_outlined, 'title': 'Notifications'},
          {'icon': Icons.public, 'title': 'Streaming Services'},
        ]
      },
      {
        'title': 'About',
        'items': [
          {'icon': Icons.help_outline, 'title': 'Help & Support'},
          {'icon': Icons.description_outlined, 'title': 'Terms & Privacy'},
          {'icon': Icons.web_asset_outlined, 'title': 'App Version'},
        ]
      },
    ];

    return Scaffold(
      appBar: AppBar(
     
        centerTitle: true,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 10),
                children: [
                  // Map over the sections list to generate widgets dynamically
                  ...sections.expand((section) {
                    bool isLastSection = section == sections.last;
                    return [
                      _SectionHeader(title: section['title'] as String),
                      ...(section['items'] as List<Map<String, dynamic>>).map(
                        (item) => _SettingsTile(
                          icon: item['icon'] as IconData,
                          title: item['title'] as String,
                        ),
                      ),
                      // Add separator if it's not the last section
                      if (!isLastSection) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        const SizedBox(height: 20),
                      ],
                    ];
                  }),
                ],
              ),
            ),

            // --- Logout Button Area ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: Colors.red,
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helper Widgets to keep code clean ---

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        icon,
        color: Colors.black87, // Slightly softer black for icons usually looks better
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.black54,
      ),
      onTap: onTap ?? () {},
    );
  }
}