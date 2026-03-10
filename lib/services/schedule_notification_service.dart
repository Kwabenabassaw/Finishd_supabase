import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finishd/models/simkl/simkl_models.dart';

class ScheduleNotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showPersonalizedNotification(List<ShowRelease> matches) async {
    if (matches.isEmpty) return;

    // Check rate limit: Once per day max
    if (await _hasNotifiedToday()) return;

    final firstMatch = matches.first;
    String title = "🔥 New Episode Available";

    String seasonStr = firstMatch.season != null ? "S${firstMatch.season.toString().padLeft(2, '0')}" : "";
    String episodeStr = firstMatch.episode != null ? "E${firstMatch.episode.toString().padLeft(2, '0')}" : "";

    String body = "${firstMatch.title} $seasonStr$episodeStr is out today.";

    if (matches.length > 1) {
      body += " and ${matches.length - 1} more releases.";
    }

    await _showNotification(title, body, 1);
    await _markNotifiedToday();
  }

  Future<void> showTrendingNotification(
      List<ShowRelease> trendingShows, List<ShowRelease> trendingMovies) async {

    if (await _hasNotifiedToday()) return;

    String title = "🎬 Trending Releases Today";
    List<String> items = [];

    for (var m in trendingMovies.take(2)) {
      items.add(m.title);
    }
    for (var s in trendingShows.take(3)) {
      items.add(s.title);
    }

    String body = items.join(', ');

    await _showNotification(title, body, 2);
    await _markNotifiedToday();
  }

  Future<void> _showNotification(String title, String body, int id) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'schedule_releases_channel',
      'Release Schedule Notifications',
      channelDescription: 'Alerts for new episodes and popular releases',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<bool> _hasNotifiedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastNotifiedStr = prefs.getString('last_schedule_notification_date');
    if (lastNotifiedStr == null) return false;

    final lastNotified = DateTime.parse(lastNotifiedStr);
    final now = DateTime.now();

    return lastNotified.year == now.year &&
        lastNotified.month == now.month &&
        lastNotified.day == now.day;
  }

  Future<void> _markNotifiedToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_schedule_notification_date', DateTime.now().toIso8601String());
  }
}
