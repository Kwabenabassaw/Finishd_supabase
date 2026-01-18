import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:finishd/screens/moderation_block_screen.dart';

/// Real-time listener for moderation status changes.
/// Kicks users immediately when banned or suspended.
class ModerationListenerService {
  static final ModerationListenerService _instance =
      ModerationListenerService._internal();
  static ModerationListenerService get instance => _instance;
  ModerationListenerService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot>? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize the listener with the app's navigator key.
  /// Call this once after app initialization.
  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Start listening for moderation changes for the current user.
  /// Does NOT immediately check status - use checkUserModerationStatus for that.
  /// This is designed to be efficient: 1 listener = ~1 read on start, then only on changes.
  void startListening() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Only listen to the specific fields we care about to minimize reads
    _subscription?.cancel();
    _subscription = _db
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .skip(1) // Skip initial snapshot (we check status on login already)
        .listen(
          _handleStatusChange,
          onError: (e) {
            debugPrint('Moderation listener error: $e');
          },
        );
  }

  /// Handle user document changes
  void _handleStatusChange(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return;

    final isBanned = data['isBanned'] == true;
    final isSuspended = data['isSuspended'] == true;

    if (isBanned || isSuspended) {
      // Determine reason and duration
      String reason;
      int? daysRemaining;

      if (isBanned) {
        reason = data['banReason'] ?? 'Policy violation';
      } else {
        reason = data['suspensionReason'] ?? 'Policy violation';
        final suspendedUntil = data['suspendedUntil'];
        if (suspendedUntil != null) {
          final until = (suspendedUntil as Timestamp).toDate();
          if (until.isAfter(DateTime.now())) {
            daysRemaining = until.difference(DateTime.now()).inDays + 1;
          } else {
            // Suspension expired, no action needed
            return;
          }
        }
      }

      // Force navigate to block screen
      _navigateToBlockScreen(
        isBanned: isBanned,
        reason: reason,
        daysRemaining: daysRemaining,
      );
    }
  }

  /// Navigate to the moderation block screen
  void _navigateToBlockScreen({
    required bool isBanned,
    required String reason,
    int? daysRemaining,
  }) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    // Clear all routes and show block screen
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ModerationBlockScreen(
          isBanned: isBanned,
          reason: reason,
          daysRemaining: daysRemaining,
        ),
      ),
      (route) => false,
    );
  }

  /// Stop listening (call on sign out)
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Dispose of the service
  void dispose() {
    stopListening();
    _navigatorKey = null;
  }
}
