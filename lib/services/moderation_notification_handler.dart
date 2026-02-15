import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Service to listen for and display moderation notifications.
/// Handles warnings, suspension notices, and ban notices via dialog overlays.
class ModerationNotificationHandler {
  static final ModerationNotificationHandler _instance =
      ModerationNotificationHandler._internal();
  static ModerationNotificationHandler get instance => _instance;
  ModerationNotificationHandler._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize with the app's navigator key.
  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Start listening for moderation notifications.
  /// Efficient: Only new unread moderation notifications trigger dialogs.
  void startListening() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _subscription?.cancel();

    // Listen to INSERTs on the notifications table for this user
    _subscription = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .listen(
          (List<Map<String, dynamic>> data) {
            _handleNotifications(data);
          },
          onError: (e) {
            debugPrint('Moderation notification listener error: $e');
          },
        );
  }

  void _handleNotifications(List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) return;

    final data = notifications.first;

    // Filter locally for moderation types and unread status
    // Supabase Stream filters are limited in some SDK versions
    final type = data['type'] as String?;
    final isRead = data['is_read'] as bool? ?? false;

    final moderationTypes = [
      'moderation_warning',
      'account_suspended',
      'account_banned',
    ];

    if (moderationTypes.contains(type) && !isRead) {
      _showModerationDialog(data['id'], data);
    }
  }

  void _showModerationDialog(String notificationId, Map<String, dynamic> data) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    final context = navigator.overlay?.context;
    if (context == null) return;

    final type = data['type'] as String?;
    final title = data['title'] as String? ?? 'Notice';
    final message = data['message'] as String? ?? 'Please review your account.';

    // Determine dialog style based on type
    Color headerColor;
    IconData icon;
    switch (type) {
      case 'moderation_warning':
        headerColor = Colors.orange;
        icon = Icons.warning_rounded;
        break;
      case 'account_suspended':
        headerColor = Colors.deepOrange;
        icon = Icons.pause_circle_rounded;
        break;
      case 'account_banned':
        headerColor = Colors.red;
        icon = Icons.block_rounded;
        break;
      default:
        headerColor = Colors.orange;
        icon = Icons.info_rounded;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: headerColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () async {
              // Mark as read
              await _markNotificationAsRead(notificationId);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
            },
            child: Text(
              'I Understand',
              style: TextStyle(color: headerColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Stop listening (call on sign out)
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Dispose
  void dispose() {
    stopListening();
    _navigatorKey = null;
  }
}
