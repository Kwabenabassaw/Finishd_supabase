import 'package:flutter/material.dart';
import 'package:finishd/Widget/appeal_bottom_sheet.dart';
import 'package:finishd/models/appeal_model.dart';
import 'package:finishd/services/auth_service.dart';
import 'package:finishd/screens/appeal_status_screen.dart';

/// Screen shown when user is suspended or banned
/// Offers option to appeal or sign out
class ModerationBlockScreen extends StatelessWidget {
  final bool isBanned;
  final String reason;
  final int? daysRemaining; // Only for suspension

  const ModerationBlockScreen({
    super.key,
    required this.isBanned,
    required this.reason,
    this.daysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionType = isBanned ? 'Banned' : 'Suspended';
    final appealActionType = isBanned
        ? AppealActionType.ban
        : AppealActionType.suspension;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBanned ? Icons.block_rounded : Icons.pause_circle_rounded,
                    size: 64,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Account $actionType',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 16),

                // Duration (for suspension)
                if (!isBanned && daysRemaining != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$daysRemaining day(s) remaining',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Reason
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(reason, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Description
                Text(
                  isBanned
                      ? 'Your account has been permanently banned for violating our community guidelines.'
                      : 'Your account is temporarily suspended. You cannot post, comment, or message during this period.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Appeal button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      AppealBottomSheet.show(
                        context,
                        actionType: appealActionType,
                        originalReason: reason,
                      );
                    },
                    icon: const Icon(Icons.gavel_rounded),
                    label: const Text(
                      'Submit Appeal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // View appeal status button
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppealStatusScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('View Appeal Status'),
                  ),
                ),
                const SizedBox(height: 8),

                // Sign out button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
