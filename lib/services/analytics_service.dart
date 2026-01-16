import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();

  factory AnalyticsService() {
    return _instance;
  }

  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Returns the standard Firebase Analytics observer
  NavigatorObserver getAnalyticsObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  /// Logs a custom event for time spent on a screen
  Future<void> logTimeSpentOnScreen(String screenName, int seconds) async {
    // Only log if significant time spent (e.g. > 1 second)
    if (seconds > 0) {
      await _analytics.logEvent(
        name: 'screen_view_duration',
        parameters: {
          'screen_name': screenName,
          'duration_seconds': seconds,
        },
      );
      debugPrint('⏱️ Analytics: $screenName viewed for ${seconds}s');
    }
  }
}

/// A custom RouteObserver to track time spent on each screen
/// Register this in your MaterialApp or GoRouter observers
class ScreenTimeObserver extends RouteObserver<PageRoute<dynamic>> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final Map<String, DateTime> _screenEntryTimes = {};

  void _startTimer(String? screenName) {
    if (screenName != null && screenName.isNotEmpty) {
      _screenEntryTimes[screenName] = DateTime.now();
    }
  }

  void _stopTimer(String? screenName) {
    if (screenName != null && _screenEntryTimes.containsKey(screenName)) {
      final startTime = _screenEntryTimes[screenName]!;
      final duration = DateTime.now().difference(startTime);
      _screenEntryTimes.remove(screenName);

      _analyticsService.logTimeSpentOnScreen(screenName, duration.inSeconds);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _startTimer(route.settings.name);
    }
    // When pushing a new route, the previous one is no longer "active"
    if (previousRoute is PageRoute) {
      _stopTimer(previousRoute.settings.name);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute) {
      _stopTimer(route.settings.name);
    }
    // When popping, the previous route becomes active again
    if (previousRoute is PageRoute) {
      _startTimer(previousRoute.settings.name);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _startTimer(newRoute.settings.name);
    }
    if (oldRoute is PageRoute) {
      _stopTimer(oldRoute.settings.name);
    }
  }
}