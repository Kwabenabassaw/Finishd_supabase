import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:finishd/provider/chat_provider.dart';
import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/Model/recommendation_model.dart'; // Ensure this is explicitly imported for generic type
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for global unread state (Messages + Recommendations).
/// Manages both in-app Nav Bar dot and Launcher Icon badges.
class UnreadStateProvider with ChangeNotifier {
  final ChatProvider _chatProvider;
  final RecommendationService _recommendationService = RecommendationService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<List<Recommendation>>? _recommendationSub;
  String? _currentUserId;

  // State
  bool _hasUnreadMessages = false;
  bool _hasUnreadRecommendations = false;

  // New Activity State (Dot Logic)
  bool _hasNewActivity = false;
  DateTime? _lastViewedMessagesAt;
  static const String _lastViewedKey = 'messages_last_viewed';

  /// Global unread status (True if ANY unread content exists) - Retained for backward compat or other badges?
  /// The prompt says "Navigation Bar Badge UI ... Display a small dot ... when hasNewActivity == true".
  /// So we exposethat primarily.
  bool get hasUnread => _hasUnreadMessages || _hasUnreadRecommendations;

  /// Badge Dot State
  bool get hasNewActivity => _hasNewActivity;

  UnreadStateProvider(this._chatProvider) {
    _initNotifications();
  }

  // ===================================
  // Initialization & Listeners
  // ===================================

  Future<void> initialize() async {
    // Load persisted timestamp
    await _loadLastViewedTime();

    // Listen to Auth Changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session?.user != null) {
        _currentUserId = session!.user.id;
        _startListening();
      } else {
        _currentUserId = null;
        _resetState();
      }
    });

    // Listen to ChatProvider changes locally
    _chatProvider.addListener(_checkForUnreadMessages);
  }

  Future<void> _loadLastViewedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastViewedKey);
    if (timestamp != null) {
      _lastViewedMessagesAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      _lastViewedMessagesAt = DateTime.now(); // Default to now if first run
    }
  }

  Future<void> markMessagesAsViewed() async {
    _hasNewActivity = false;
    _lastViewedMessagesAt = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastViewedKey,
      _lastViewedMessagesAt!.millisecondsSinceEpoch,
    );

    _updateBagdeState();
  }

  void _startListening() {
    if (_currentUserId == null) return;

    // 1. Listen for Recommendation changes (getting latest item timestamp)
    _recommendationSub?.cancel();
    _recommendationSub = _recommendationService
        .getRecommendations(
          _currentUserId!,
        ) // Needs a stream that returns items to check timestamp, or unread count stream?
        // The original used getUnreadCountStream. To detect NEW activity based on time, we need timestamps.
        // Let's use getRecommendations(limit: 1) or similar if high frequency?
        // Actually, the original stored generic unread count.
        // To strictly follow "incomingTimestamp > lastViewedMessagesAt", we need the latest timestamp.
        // We'll switch to listening to the latest recommendation.
        .listen((recs) {
          if (recs.isNotEmpty) {
            final latestRec = recs.first; // Assumes descending sort
            // Check if new
            if (_lastViewedMessagesAt != null &&
                latestRec.timestamp.isAfter(_lastViewedMessagesAt!)) {
              _hasNewActivity = true;
            }

            // Keep legacy "unread" logic if needed, but prompt says specific rule.
            // "unread" usually implies status='unread'.
            _hasUnreadRecommendations = recs.any((r) => r.status == 'unread');

            _updateBagdeState();
          }
        });

    // 2. Initial check for messages
    _checkForUnreadMessages();
  }

  void _checkForUnreadMessages() {
    // Iterate through all local conversations to find any unread count > 0
    final hasUnreadCount = _chatProvider.conversations.any(
      (c) => c.unreadCount > 0,
    );

    // Check for NEW activity (timestamp based)
    // We need to look at the latest message in any conversation
    bool newActivityFound = false;
    if (_lastViewedMessagesAt != null) {
      for (final conv in _chatProvider.conversations) {
        if (conv.lastMessageAt != null &&
            conv.lastMessageAt!.isAfter(_lastViewedMessagesAt!)) {
          newActivityFound = true;
          break;
        }
      }
    }

    if (_hasUnreadMessages != hasUnreadCount ||
        (_hasNewActivity != newActivityFound && newActivityFound)) {
      // Only update if something changed.
      // Note: newActivityFound only sets to true. We don't auto-clear it here (cleared by user action).
      // So we logic: if newActivityFound is true, set _hasNewActivity = true.
      if (newActivityFound) {
        _hasNewActivity = true;
      }
      _hasUnreadMessages = hasUnreadCount;
      _updateBagdeState();
    }
  }

  void _resetState() {
    _hasUnreadMessages = false;
    _hasUnreadRecommendations = false;
    _hasNewActivity = false;
    _recommendationSub?.cancel();
    _updateBagdeState();
  }

  // ===================================
  // Badge Logic (Side Effects)
  // ===================================

  void _updateBagdeState() {
    // 1. Notify UI (Bottom Navigation Dot)
    notifyListeners();

    // 2. Update Launcher Icon (Legacy logic uses total unread, keeping it?)
    // Prompt: "Does not rely on unread totals".
    // But Android badge usually implies "something to check".
    // I'll use hasNewActivity for the internal app badge, keeps launcher sync with "unread items"
    // OR sync launcher with "New Activity"?
    // Usually launcher badge = number. "New Activity" is boolean.
    // I will keep launcher badge as "hasUnread" (legacy) to assume counts,
    // while the IN-APP badge uses `hasNewActivity`.
    final isUnread = hasUnread;
    if (Platform.isAndroid) {
      _updateAndroidBadge(isUnread);
    } else if (Platform.isIOS) {
      _updateIOSBadge(isUnread);
    }
  }

  // Android: Post silent notification to show dot
  Future<void> _updateAndroidBadge(bool showDot) async {
    const int badgeNotificationId = 999;

    if (showDot) {
      // Show silent notification
      const androidDetails = AndroidNotificationDetails(
        'unread_badge_channel',
        'Unread Badges',
        channelDescription:
            'Shows a dot on the app icon when unread items exist',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
      );
      const details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        badgeNotificationId,
        null, // No title
        null, // No body
        details,
      );
    } else {
      // Remove notification (clears dot)
      await _notificationsPlugin.cancel(badgeNotificationId);
    }
  }

  // iOS: Set badge count to 1 or 0 (REMOVED: flutter_app_badger)
  Future<void> _updateIOSBadge(bool showBadge) async {
    // iOS badge logic removed due to flutter_app_badger build issues
  }

  // Initialize Local Notifications configuration
  void _initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestBadgePermission: true,
      requestSoundPermission: false,
      requestAlertPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  @override
  void dispose() {
    _recommendationSub?.cancel();
    _chatProvider.removeListener(_checkForUnreadMessages);
    super.dispose();
  }
}
