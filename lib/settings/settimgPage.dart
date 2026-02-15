import 'package:finishd/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/theme_provider.dart';
import '../provider/user_provider.dart';
import '../screens/creator_application_screen.dart';
import 'edit_streaming_services.dart';
import 'edit_genres.dart';
import 'edit_favorite_content.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Get the icon for the current theme mode
  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  /// Get the label for the current theme mode
  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeMode = themeProvider.themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Settings'),
        actions: [
          // Theme toggle icon
          IconButton(
            icon: Icon(
              _getThemeIcon(themeMode),
              color: themeMode == ThemeMode.system
                  ? (isDark ? Colors.blueAccent : Colors.blueGrey)
                  : (isDark ? Colors.amber : Colors.blueGrey),
            ),
            tooltip: 'Theme: ${_getThemeLabel(themeMode)} (tap to change)',
            onPressed: () => themeProvider.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 10),
                children: [
                  // Playback Section
                  _SectionHeader(title: 'Playback'),
                  _SettingsTile(
                    icon: Icons.closed_caption_outlined,
                    title: 'Subtitles',
                  ),
                  _SettingsTile(
                    icon: Icons.play_circle_outline,
                    title: 'Autoplay Next Episode',
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  const SizedBox(height: 20),

                  // App Preferences Section
                  _SectionHeader(title: 'App Preferences'),
                  _SettingsTile(
                    icon: Icons.contrast,
                    title: 'Theme',
                    subtitle: _getThemeLabel(themeMode),
                    onTap: () => themeProvider.toggleTheme(),
                  ),
                  _SettingsTile(icon: Icons.language, title: 'Language'),
                  _SettingsTile(
                    icon: Icons.notifications_none_outlined,
                    title: 'Notifications',
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  const SizedBox(height: 20),

                  // User Preferences Section (NEW)
                  _SectionHeader(title: 'Your Preferences'),
                  _SettingsTile(
                    icon: Icons.live_tv,
                    title: 'Streaming Services',
                    subtitle: 'Manage your subscriptions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditStreamingServicesScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.category,
                    title: 'Genres',
                    subtitle: 'Your favorite genres',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditGenresScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.movie_filter,
                    title: 'Favorite Shows & Movies',
                    subtitle: 'Content you love',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditFavoriteContentScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  const SizedBox(height: 20),

                  // Creator Section - only show for non-creators
                  Consumer<UserProvider>(
                    builder: (context, userProvider, _) {
                      final user = userProvider.currentUser;
                      final isCreator =
                          user != null &&
                          user.role == 'creator' &&
                          user.creatorStatus == 'approved';

                      // Don't show this section if already a creator
                      if (isCreator) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(title: 'Creator'),
                          _SettingsTile(
                            icon: Icons.video_call,
                            title: 'Apply to be a Creator',
                            subtitle: 'Share your content on Finishd',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CreatorApplicationScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, indent: 20, endIndent: 20),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                  _SectionHeader(title: 'About'),
                  _SettingsTile(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                  ),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    title: 'Terms & Privacy',
                  ),
                  _SettingsTile(
                    icon: Icons.web_asset_outlined,
                    title: 'App Version',
                  ),
                ],
              ),
            ),

            // --- Logout Button Area ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : const Color(0xFFEEEEEE),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error logging out: $e')),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: Colors.red,
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

// --- Helper Widgets ---

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        icon,
        color: isDark ? Colors.white70 : Colors.black87,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
      onTap: onTap ?? () {},
    );
  }
}
