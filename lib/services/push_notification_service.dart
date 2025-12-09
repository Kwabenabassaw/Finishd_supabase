import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // 1. Initialize Local Notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle local notification tap
        if (response.payload != null) {
          // Parse payload if needed, or just navigate based on stored data
          // For simplicity, we might need to store the message data in a map to retrieve here
          // Or just rely on FCM's onMessageOpenedApp for background taps
        }
      },
    );

    // 2. Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // 3. Subscribe to Trending Topic
      await _fcm.subscribeToTopic('trending');
      print('Subscribed to trending topic');

      // 4. Handle Background/Terminated Taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Message clicked!');
        _handleMessage(message, navigatorKey);
      });

      // 5. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');

        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });

      // 6. Check Initial Message
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
    final data = message.data;
    final type = data['type'];

    if (type == 'trending') {
      // Navigate to Trending List
      navigatorKey.currentState?.pushNamed(
        '/trending_list',
        arguments: data['date'],
      );
    } else if (type == 'new_episode' || type == 'recommended') {
      // Navigate to TV Show Details
      // Support both 'tmdbId' and 'tmdb_id' formats
      final tmdbId = int.tryParse(data['tmdb_id'] ?? data['tmdbId'] ?? '');
      if (tmdbId != null) {
        navigatorKey.currentState?.pushNamed(
          '/tv_details',
          arguments: {
            'id': tmdbId,
            'season': int.tryParse(data['season'] ?? ''),
            'episode': int.tryParse(data['episode'] ?? ''),
          },
        );
      }
    } else if (type == 'trending_digest') {
      // Navigate to Trending/Discover page
      navigatorKey.currentState?.pushNamed(
        '/trending_list',
        arguments: data['date'],
      );
    } else if (type == 'chat') {
      final chatId = data['chatId'];
      navigatorKey.currentState?.pushNamed('/chat', arguments: chatId);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    final details = NotificationDetails(android: androidDetails);

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        details,
        payload: message.data.toString(),
      );
    }
  }

  Future<void> saveTokenToDatabase(String userId) async {
    String? token = await _fcm.getToken();
    if (token != null) {
      // Save to subcollection for multi-device support
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('deviceTokens')
          .doc(token)
          .set({
            'token': token,
            'platform': 'android', // or detect platform
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      // Listen for refresh
      _fcm.onTokenRefresh.listen((newToken) async {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('deviceTokens')
            .doc(newToken)
            .set({
              'token': newToken,
              'platform': 'android',
              'lastUpdated': FieldValue.serverTimestamp(),
            });
      });
    }
  }
}
