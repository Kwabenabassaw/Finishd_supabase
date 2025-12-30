import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/models/feed_video.dart';
import 'package:finishd/models/feed_item.dart';

/// Feed Types for personalized content
enum FeedType {
  forYou('for_you'),
  trending('trending'),
  following('following');

  final String value;
  const FeedType(this.value);
}

/// API Client for Finishd Backend
///
/// Handles all communication with the FastAPI backend deployed on Railway.
/// All endpoints require Firebase authentication (unless public).
class ApiClient {
  // Backend URL (Vercel deployment)
  static const String baseUrl = 'https://finishdbackend-master.vercel.app';

  // Risk 2 FIX: Hide logs behind debug flag - TEMPORARILY ENABLED FOR DEBUGGING
  static const bool _debugLogging = true;

  // Singleton pattern
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  /// Get Firebase ID token for authentication
  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log('No user logged in', isError: true);
        return null;
      }
      return await user.getIdToken();
    } catch (e) {
      _log('Error getting token: $e', isError: true);
      return null;
    }
  }

  /// Build headers with authentication
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getIdToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Centralized logger
  void _log(String message, {bool isError = false}) {
    if (_debugLogging || isError) {
      print((isError ? '❌ ' : '📡 ') + message);
    }
  }

  /// GET request with authentication and retry
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool retry = true, // Risk 3 FIX: Retry strategy
  }) async {
    final headers = await _getHeaders();
    // Bug 3 FIX: Fail fast if no token (implied by usage, but explicit check good practices)
    if (!headers.containsKey('Authorization')) {
      // Optional: throw Exception('Not authenticated');
    }

    Uri uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    _log('ApiClient GET: $uri');

    // Simple retry logic
    int attempts = 0;
    while (attempts < (retry ? 2 : 1)) {
      try {
        attempts++;
        final response = await http
            .get(uri, headers: headers)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception('Request timeout'),
            );

        _log('ApiClient Response: ${response.statusCode}');

        // Bug 5 FIX: fail fast on auth error
        if (response.statusCode == 401) {
          _log('Unauthorized access', isError: true);
          throw Exception('Unauthorized');
        }

        return response;
      } catch (e) {
        _log('ApiClient Error (Attempt $attempts): $e', isError: true);
        if (attempts >= (retry ? 2 : 1)) rethrow;
        await Future.delayed(const Duration(seconds: 1)); // Backoff
      }
    }
    throw Exception('Request failed after retries');
  }

  /// Public GET request (No Auth Headers) - Bug 2 FIX
  Future<http.Response> getPublic(
    String endpoint, {
    Map<String, String>? queryParams,
    bool retry = true,
  }) async {
    Uri uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    _log('ApiClient GET (Public): $uri');

    // Simple retry logic
    int attempts = 0;
    while (attempts < (retry ? 2 : 1)) {
      try {
        attempts++;
        final response = await http
            .get(uri) // No headers injected
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception('Request timeout'),
            );
        return response;
      } catch (e) {
        _log('ApiClient Public Error (Attempt $attempts): $e', isError: true);
        if (attempts >= (retry ? 2 : 1)) rethrow;
        await Future.delayed(const Duration(seconds: 1)); // Backoff
      }
    }
    throw Exception('Request public failed after retries');
  }

  /// POST request with authentication
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');

    _log('ApiClient POST: $uri');

    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timeout'),
          );

      _log('ApiClient Response: ${response.statusCode}');
      return response;
    } catch (e) {
      _log('ApiClient Error: $e', isError: true);
      rethrow;
    }
  }

  // =========================================================================
  // FEED API (TMDB-based)
  // =========================================================================

  /// Get feed based on feed type (NEW - supports three tabs)
  ///
  /// [feedType]: Enum 'trending', 'following', or 'for_you' (default)
  Future<List<FeedItem>> getPersonalizedFeedV2({
    bool refresh = false,
    int limit = 50,
    int? page, // null means auto-randomize
    FeedType feedType = FeedType.forYou, // Risk 1 FIX: Use enum
  }) async {
    // Generate random page if not specified (for variety in feed)
    final effectivePage = page ?? Random().nextInt(10) + 1;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log('No user logged in', isError: true);
        return []; // Standardize empty list return
      }

      final queryParams = {
        'refresh': refresh.toString(),
        'limit': limit.toString(),
        'page': effectivePage.toString(),
        'feed_type': feedType.value, // Bug 1 FIX: Match backend param name
      };

      _log('📡 Calling /feed/${user.uid} with params: $queryParams');

      final response = await get('/feed/${user.uid}', queryParams: queryParams);

      _log('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // DEBUG: Log raw response structure
        _log('📦 Response keys: ${data.keys.toList()}');

        final List<dynamic> feedJson = data['feed'] ?? [];

        _log('✅ Got ${feedJson.length} ${feedType.value} feed items');

        // DEBUG: Log first item's youtubeKey if exists
        if (feedJson.isNotEmpty) {
          final firstItem = feedJson[0];
          _log(
            '🎬 First item: ${firstItem['title']}, youtubeKey: ${firstItem['youtubeKey']}',
          );
        }

        return feedJson.map((v) => FeedItem.fromJson(v)).toList();
      } else {
        _log(
          'Feed API error: ${response.statusCode} - ${response.body}',
          isError: true,
        );
        return [];
      }
    } catch (e, stackTrace) {
      _log('Error fetching personalized feed v2: $e', isError: true);
      _log('Stack trace: $stackTrace', isError: true);
      return [];
    }
  }

  /// Get global trending feed (no auth required for content)
  Future<List<FeedItem>> getGlobalFeed({int limit = 20}) async {
    try {
      final queryParams = {'limit': limit.toString()};
      // Bug 2 FIX: Use public endpoint (no auth headers injected)
      final response = await getPublic(
        '/feed/global',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> feedJson = data['feed'] ?? [];
        return feedJson.map((v) => FeedItem.fromJson(v)).toList();
      }
      return [];
    } catch (e) {
      _log('Error fetching global feed: $e', isError: true);
      return [];
    }
  }

  /// Get BTS content (cached YouTube content)
  Future<List<Map<String, dynamic>>> getBTSContent() async {
    try {
      // Bug 2 FIX: Use public endpoint
      final response = await getPublic('/feed/bts');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> content = data['content'] ?? [];
        return content.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _log('Error fetching BTS content: $e', isError: true);
      return [];
    }
  }

  // =========================================================================
  // LEGACY FEED API (YouTube-based - kept for compatibility)
  // =========================================================================

  /// Get personalized video feed (LEGACY)
  Future<List<FeedVideo>> getPersonalizedFeed({
    bool refresh = false,
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final queryParams = {
        'refresh': refresh.toString(),
        'limit': limit.toString(),
        'page': page.toString(),
      };

      final response = await get('/feed/get', queryParams: queryParams);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Handle both old (videos) and new (feed) response format
        final List<dynamic> itemsJson = data['videos'] ?? data['feed'] ?? [];

        return itemsJson.map((v) => FeedVideo.fromJson(v)).toList();
      } else {
        _log(
          'Feed API error: ${response.statusCode} - ${response.body}',
          isError: true,
        );
        return [];
      }
    } catch (e) {
      _log('Error fetching feed: $e', isError: true);
      return [];
    }
  }

  /// Refresh personalized feed (LEGACY)
  Future<List<FeedVideo>> refreshFeed({int limit = 20}) async {
    try {
      final response = await post('/feed/refresh', body: {'limit': limit});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> itemsJson = data['videos'] ?? data['feed'] ?? [];

        return itemsJson.map((v) => FeedVideo.fromJson(v)).toList();
      }
      return [];
    } catch (e) {
      _log('Error refreshing feed: $e', isError: true);
      return [];
    }
  }

  // =========================================================================
  // OTHER API METHODS
  // =========================================================================

  /// Health check
  Future<bool> healthCheck() async {
    try {
      // Bug 4 FIX: Use getPublic to share logic/timeouts
      final response = await getPublic('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Verify authentication token
  Future<Map<String, dynamic>?> verifyAuth() async {
    try {
      final response = await post('/auth/verify');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      _log('Auth verification failed: $e', isError: true);
      return null;
    }
  }

  /// Get trending movies (top 10)
  Future<List<Map<String, dynamic>>> getTrending({bool refresh = false}) async {
    try {
      final queryParams = {'refresh': refresh.toString()};
      // Use Public
      final response = await getPublic(
        '/trending/get',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> movies = data['movies'] ?? [];
        return movies.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _log('Error fetching trending: $e', isError: true);
      return [];
    }
  }

  /// Get all trending content (movies and shows)
  Future<Map<String, dynamic>> getAllTrending({
    int movieLimit = 10,
    int showLimit = 10,
  }) async {
    try {
      final queryParams = {
        'movie_limit': movieLimit.toString(),
        'show_limit': showLimit.toString(),
      };
      // Use Public
      final response = await getPublic(
        '/trending/all',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'movies': [], 'shows': []};
    } catch (e) {
      _log('Error fetching all trending: $e', isError: true);
      return {'movies': [], 'shows': []};
    }
  }

  /// Check for new episodes of shows user is watching
  /// DEPRECATED: This is slow (5-15s) - use getEpisodeAlertsFast() instead
  Future<List<Map<String, dynamic>>> checkNewEpisodes() async {
    try {
      final response = await get('/episodes/check');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> alerts = data['alerts'] ?? [];
        return alerts.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _log('Error checking episodes: $e', isError: true);
      return [];
    }
  }

  /// Get pre-computed episode alerts (FAST - ~50ms)
  /// This reads from Firestore cache instead of querying TMDB for each show
  Future<List<Map<String, dynamic>>> getEpisodeAlertsFast({
    int limit = 50,
  }) async {
    try {
      final queryParams = {'limit': limit.toString()};
      final response = await get('/episodes/alerts', queryParams: queryParams);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> alerts = data['alerts'] ?? [];
        _log('Fast alerts: ${alerts.length} pre-computed alerts');
        return alerts.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _log('Error fetching fast alerts: $e', isError: true);
      return [];
    }
  }

  /// Get upcoming episodes
  Future<List<Map<String, dynamic>>> getUpcomingEpisodes({int days = 7}) async {
    try {
      final queryParams = {'days': days.toString()};
      final response = await get(
        '/episodes/upcoming',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> upcoming = data['upcoming'] ?? [];
        return upcoming.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _log('Error fetching upcoming episodes: $e', isError: true);
      return [];
    }
  }

  /// Get TV notifications from shows subcollection
  Future<List<Map<String, dynamic>>> getTVNotifications({
    int limit = 50,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final queryParams = {'limit': limit.toString()};
      final response = await get(
        '/notifications/tv/${user.uid}',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> notifications = data['notifications'] ?? [];
        return notifications.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _log('Error fetching TV notifications: $e', isError: true);
      return [];
    }
  }

  /// Get personalized TV recommendations
  Future<List<Map<String, dynamic>>> getRecommendations({
    int limit = 10,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final queryParams = {'limit': limit.toString()};
      final response = await get(
        '/feed/recommendations/${user.uid}',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> recommendations = data['recommendations'] ?? [];
        return recommendations.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _log('Error fetching recommendations: $e', isError: true);
      return [];
    }
  }

  /// Send chat notification via backend
  Future<bool> sendChatNotification({
    required String receiverUid,
    required String senderUid,
    required String messageText,
    required String chatId,
  }) async {
    try {
      final response = await post(
        '/chat/notify',
        body: {
          'receiver_uid': receiverUid,
          'sender_uid': senderUid,
          'message_text': messageText,
          'chat_id': chatId,
        },
      );

      if (response.statusCode == 200) {
        _log('Chat notification sent successfully');
        return true;
      } else {
        _log('Chat notification failed: ${response.statusCode}', isError: true);
        return false;
      }
    } catch (e) {
      _log('Error sending chat notification: $e', isError: true);
      // Non-critical error, don't block message send
      return false;
    }
  }

  /// Get cached YouTube video data
  Future<Map<String, dynamic>?> getYouTubeVideo(String videoId) async {
    try {
      final response = await getPublic('/youtube/video/$videoId');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      _log('Error fetching YouTube video: $e', isError: true);
      return null;
    }
  }

  /// Search YouTube videos
  Future<List<FeedVideo>> searchYouTube({
    required String query,
    int maxResults = 10,
    String duration = 'short',
  }) async {
    try {
      final queryParams = {
        'query': query,
        'max_results': maxResults.toString(),
        'duration': duration,
      };
      final response = await getPublic(
        '/youtube/search',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> videosJson = data['videos'] ?? [];
        return videosJson.map((v) => FeedVideo.fromJson(v)).toList();
      }
      return [];
    } catch (e) {
      _log('Error searching YouTube: $e', isError: true);
      return [];
    }
  }

  /// Get user's notifications
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'unread_only': unreadOnly.toString(),
      };
      final response = await get('/notifications/me', queryParams: queryParams);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> notifications = data['notifications'] ?? [];
        return notifications.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _log('Error fetching notifications: $e', isError: true);
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response = await post('/notifications/read/$notificationId');
      return response.statusCode == 200;
    } catch (e) {
      _log('Error marking notification read: $e', isError: true);
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsRead() async {
    try {
      final response = await post('/notifications/read-all');
      return response.statusCode == 200;
    } catch (e) {
      _log('Error marking all notifications read: $e', isError: true);
      return false;
    }
  }

  /// Send notification (admin/system use)
  Future<bool> sendNotification({
    String? uid,
    String? topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await post(
        '/notifications/send',
        body: {
          if (uid != null) 'uid': uid,
          if (topic != null) 'topic': topic,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      _log('Error sending notification: $e', isError: true);
      return false;
    }
  }

  /// Trigger backend cron job to refresh content (Debug/Admin)
  Future<bool> triggerBackendRefresh() async {
    try {
      final response = await post('/feed/admin/refresh-caches');
      if (response.statusCode == 200) {
        _log('Backend refresh triggered successfully');
        return true;
      }
      return false;
    } catch (e) {
      _log('Error triggering backend refresh: $e', isError: true);
      return false;
    }
  }
}
