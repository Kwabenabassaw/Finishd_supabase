import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/models/feed_video.dart';
import 'package:finishd/models/feed_item.dart';

/// API Client for Finishd Backend
///
/// Handles all communication with the FastAPI backend deployed on Railway.
/// All endpoints require Firebase authentication.
class ApiClient {
  // Railway backend URL
  static const String baseUrl =
      'https://finishdbackend-master-production.up.railway.app';

  // Singleton pattern
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  /// Get Firebase ID token for authentication
  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ ApiClient: No user logged in');
        return null;
      }
      return await user.getIdToken();
    } catch (e) {
      print('❌ ApiClient: Error getting token: $e');
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

  /// GET request with authentication
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final headers = await _getHeaders();

    Uri uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    print('📡 ApiClient GET: $uri');

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Request timeout'),
          );

      print('📡 ApiClient Response: ${response.statusCode}');
      return response;
    } catch (e) {
      print('❌ ApiClient Error: $e');
      rethrow;
    }
  }

  /// POST request with authentication
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');

    print('📡 ApiClient POST: $uri');

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

      print('📡 ApiClient Response: ${response.statusCode}');
      return response;
    } catch (e) {
      print('❌ ApiClient Error: $e');
      rethrow;
    }
  }

  // =========================================================================
  // FEED API (TMDB-based)
  // =========================================================================

  /// Get personalized feed (NEW - TMDB-based)
  /// Returns FeedItem list with trailers, BTS, and interviews
  Future<List<FeedItem>> getPersonalizedFeedV2({
    bool refresh = false,
    int limit = 50,
    int page = 1,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return [];
      }

      final queryParams = {
        'refresh': refresh.toString(),
        'limit': limit.toString(),
        'page': page.toString(),
      };

      final response = await get('/feed/${user.uid}', queryParams: queryParams);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> feedJson = data['feed'] ?? [];

        print('✅ Got ${feedJson.length} feed items from TMDB-based API');
        return feedJson.map((v) => FeedItem.fromJson(v)).toList();
      } else {
        print('❌ Feed API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching personalized feed v2: $e');
      return [];
    }
  }

  /// Get global trending feed (no auth required for content)
  Future<List<FeedItem>> getGlobalFeed({int limit = 50}) async {
    try {
      final queryParams = {'limit': limit.toString()};
      final response = await get('/feed/global', queryParams: queryParams);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> feedJson = data['feed'] ?? [];
        return feedJson.map((v) => FeedItem.fromJson(v)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error fetching global feed: $e');
      return [];
    }
  }

  /// Get BTS content (cached YouTube content)
  Future<List<Map<String, dynamic>>> getBTSContent() async {
    try {
      final response = await get('/feed/bts');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> content = data['content'] ?? [];
        return content.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Error fetching BTS content: $e');
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
        print('❌ Feed API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching feed: $e');
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
      print('❌ Error refreshing feed: $e');
      return [];
    }
  }

  // =========================================================================
  // OTHER API METHODS
  // =========================================================================

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
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
      print('❌ Auth verification failed: $e');
      return null;
    }
  }

  /// Get trending movies (top 10)
  Future<List<Map<String, dynamic>>> getTrending({bool refresh = false}) async {
    try {
      final queryParams = {'refresh': refresh.toString()};
      final response = await get('/trending/get', queryParams: queryParams);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> movies = data['movies'] ?? [];
        return movies.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Error fetching trending: $e');
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
      final response = await get('/trending/all', queryParams: queryParams);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'movies': [], 'shows': []};
    } catch (e) {
      print('❌ Error fetching all trending: $e');
      return {'movies': [], 'shows': []};
    }
  }

  /// Check for new episodes of shows user is watching
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
      print('❌ Error checking episodes: $e');
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
      print('❌ Error fetching upcoming episodes: $e');
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
      print('❌ Error fetching TV notifications: $e');
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
      print('❌ Error fetching recommendations: $e');
      return [];
    }
  }

  /// Get cached YouTube video data
  Future<Map<String, dynamic>?> getYouTubeVideo(String videoId) async {
    try {
      final response = await get('/youtube/video/$videoId');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching YouTube video: $e');
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
      final response = await get('/youtube/search', queryParams: queryParams);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> videosJson = data['videos'] ?? [];
        return videosJson.map((v) => FeedVideo.fromJson(v)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error searching YouTube: $e');
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
      print('❌ Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response = await post('/notifications/read/$notificationId');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error marking notification read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsRead() async {
    try {
      final response = await post('/notifications/read-all');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error marking all notifications read: $e');
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
      print('❌ Error sending notification: $e');
      return false;
    }
  }

  /// Trigger backend cron job to refresh content (Debug/Admin)
  Future<bool> triggerBackendRefresh() async {
    try {
      final response = await post('/feed/admin/refresh-caches');
      if (response.statusCode == 200) {
        print('✅ Backend refresh triggered successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error triggering backend refresh: $e');
      return false;
    }
  }
}
