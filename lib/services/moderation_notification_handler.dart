import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Service to listen for and display moderation notifications.
/// Handles warnings, suspension notices, and ban notices via dialog overlays.
class ModerationNotificationHandler {
  static final ModerationNotificationHandler _instance =
      ModerationNotificationHandler._internal();
  static ModerationNotificationHandler get instance => _instance;
  ModerationNotificationHandler._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize with the app's navigator key.
  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Start listening for moderation notifications.
  /// Efficient: Only new unread moderation notifications trigger dialogs.
  void startListening() {
    final user = _auth.currentUser;
    if (user == null) return;

    _subscription?.cancel();
    _subscription = _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where(
          'type',
          whereIn: [
            'moderation_warning',
            'account_suspended',
            'account_banned',
          ],
        )
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          _handleNotifications,
          onError: (e) {
            debugPrint('Moderation notification listener error: $e');
          },
        );
  }

  void _handleNotifications(QuerySnapshot snapshot) {
    if (snapshot.docs.isEmpty) return;

    final doc = snapshot.docs.first;
    final data = doc.data() as Map<String, dynamic>;

    _showModerationDialog(doc.id, data);
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
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
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
