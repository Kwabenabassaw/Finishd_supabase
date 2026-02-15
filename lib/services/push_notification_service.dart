import 'package:flutter/material.dart';

/// Stub Push Notification Service
/// Firebase/FCM has been removed from the project.
/// This is a placeholder that can be replaced with OneSignal or similar.
class PushNotificationService {
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // Push notifications disabled - Firebase/FCM removed
    debugPrint('Push notifications are disabled (Firebase removed)');
  }

  Future<void> saveTokenToDatabase(String userId) async {
    // No-op: FCM removed
  }
}
