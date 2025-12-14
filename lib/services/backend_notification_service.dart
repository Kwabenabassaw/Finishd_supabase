import 'package:finishd/services/api_client.dart';

/// Service for managing notifications from the backend API
class BackendNotificationService {
  final ApiClient _apiClient = ApiClient();

  /// Get user's notifications
  Future<List<AppNotification>> getNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      final notifications = await _apiClient.getNotifications(
        limit: limit,
        unreadOnly: unreadOnly,
      );
      return notifications.map((n) => AppNotification.fromJson(n)).toList();
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final notifications = await _apiClient.getNotifications(unreadOnly: true);
      return notifications.length;
    } catch (e) {
      print('❌ Error fetching unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    return await _apiClient.markNotificationRead(notificationId);
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    return await _apiClient.markAllNotificationsRead();
  }
}

/// Model for app notification
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? imageUrl;
  final bool read;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.imageUrl,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt']);
      } else if (json['createdAt'] is String) {
        createdAt = DateTime.tryParse(json['createdAt']);
      }
    }

    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] ?? {},
      imageUrl: json['imageUrl'],
      read: json['read'] ?? false,
      createdAt: createdAt,
    );
  }

  bool get isNewEpisode => type == 'new_episode';
  bool get isTrending => type == 'trending';
  bool get isChat => type == 'chat';

  String get timeAgo {
    if (createdAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(createdAt!);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'data': data,
    'imageUrl': imageUrl,
    'read': read,
    'createdAt': createdAt?.millisecondsSinceEpoch,
  };
}
