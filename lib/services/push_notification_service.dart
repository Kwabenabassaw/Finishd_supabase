import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // Get token
      String? token = await _fcm.getToken();
      if (token != null) {
        print('FCM Token: $token');
        // Save token to current user's document if logged in
        // This part usually requires the current user ID to be passed or retrieved from auth service
      }

      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Message clicked!');
        _handleMessage(message, navigatorKey);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print(
            'Message also contained a notification: ${message.notification}',
          );
          // Show local notification or snackbar
        }
      });

      // Check if app was opened from a terminated state
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage, navigatorKey);
      }
    }
  }

  void _handleMessage(
    RemoteMessage message,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    if (message.data['type'] == 'chat') {
      final chatId = message.data['chatId'];
      // Navigate to chat screen
      // navigatorKey.currentState?.pushNamed('/chat', arguments: chatId);
      // Note: You'll need to ensure your route handling supports this
    }
  }

  Future<void> saveTokenToDatabase(String userId) async {
    String? token = await _fcm.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) async {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': newToken,
        });
      });
    }
  }
}
