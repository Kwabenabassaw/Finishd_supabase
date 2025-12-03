import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:finishd/models/feed_video.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:finishd/services/user_preferences_service.dart';
import 'package:finishd/services/youtube_service.dart';

class PersonalizedFeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserPreferencesService _prefsService = UserPreferencesService();
  final MovieListService _movieListService = MovieListService();
  final YouTubeService _youtubeService = YouTubeService();

  // Weights for interest calculation
  static const int _weightGenre = 5;
  static const int _weightLiked = 8; // Favorites
  static const int _weightWatchlist = 6;
  static const int _weightWatching = 7;
  static const int _weightFinished = 4;
  static const int _weightPlatform = 3;

  /// Main entry point to load the personalized feed
  Future<List<FeedVideo>> loadPersonalizedFeed(String uid) async {
    try {
      // 1. Check Cache (24h TTL)
      final cachedFeed = await _getCachedFeed(uid);
      if (cachedFeed != null && cachedFeed.isNotEmpty) {
        print('✅ Using cached feed for user: $uid');
        return cachedFeed;
      }

      print('🔄 Generating fresh personalized feed for user: $uid');

      // 2. Aggregate User Data & Calculate Interests
      final interests = await _calculateInterestWeights(uid);

      // 3. Generate Smart Queries
      final queries = _buildUserFeedQueries(interests);

      // 4. Fetch Videos from YouTube
      final videos = await _fetchVideosFromYouTube(queries);

      // 5. Cache Results
      if (videos.isNotEmpty) {
        await _cacheFeed(uid, videos);
      }

      return videos;
    } catch (e) {
      print('❌ Error loading personalized feed: $e');
      // Fallback to random discovery if personalization fails
      return await _youtubeService.fetchVideos();
    }
  }

  /// Aggregates user data and calculates weighted interests
  Future<List<_Interest>> _calculateInterestWeights(String uid) async {
    final Map<String, int> interestScores = {};

    // Fetch all data in parallel
    final results = await Future.wait([
      _prefsService.getUserPreferences(uid),
      _movieListService.getMoviesFromList(uid, 'favorites'),
      _movieListService.getMoviesFromList(uid, 'watchlist'),
      _movieListService.getMoviesFromList(uid, 'watching'),
      _movieListService.getMoviesFromList(uid, 'finished'),
    ]);

    final prefs = results[0] as UserPreferences?;
    final favorites = results[1] as List<dynamic>;
    final watchlist = results[2] as List<dynamic>;
    final watching = results[3] as List<dynamic>;
    final finished = results[4] as List<dynamic>;

    // Process Genres
    if (prefs != null) {
      for (final genre in prefs.selectedGenres) {
        _addScore(
          interestScores,
          genre,
          _weightGenre,
          type: _InterestType.genre,
        );
      }
      for (final provider in prefs.streamingProviders) {
        _addScore(
          interestScores,
          provider.providerName,
          _weightPlatform,
          type: _InterestType.platform,
        );
      }
    }

    // Process Movies (Favorites, Watchlist, etc.)
    for (final movie in favorites) {
      _addScore(
        interestScores,
        movie.title,
        _weightLiked,
        type: _InterestType.movie,
      );
    }
    for (final movie in watching) {
      _addScore(
        interestScores,
        movie.title,
        _weightWatching,
        type: _InterestType.movie,
      );
    }
    for (final movie in watchlist) {
      _addScore(
        interestScores,
        movie.title,
        _weightWatchlist,
        type: _InterestType.movie,
      );
    }
    for (final movie in finished) {
      _addScore(
        interestScores,
        movie.title,
        _weightFinished,
        type: _InterestType.movie,
      );
    }

    // Convert to list and sort by score
    final sortedInterests =
        interestScores.entries
            .map(
              (e) => _Interest(
                e.key,
                e.value,
                _getType(
                  e.key,
                  prefs,
                  favorites,
                  watchlist,
                  watching,
                  finished,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    // Return top 10 interests to avoid too many API calls
    return sortedInterests.take(10).toList();
  }

  /// Helper to add scores
  void _addScore(
    Map<String, int> scores,
    String key,
    int weight, {
    required _InterestType type,
  }) {
    scores[key] = (scores[key] ?? 0) + weight;
  }

  /// Helper to determine type (simplified)
  _InterestType _getType(
    String key,
    UserPreferences? prefs,
    List fav,
    List watch,
    List watching,
    List fin,
  ) {
    if (prefs?.selectedGenres.contains(key) ?? false)
      return _InterestType.genre;
    if (prefs?.streamingProviders.any((p) => p.providerName == key) ?? false)
      return _InterestType.platform;
    return _InterestType.movie;
  }

  /// Generates YouTube search queries based on interests
  List<String> _buildUserFeedQueries(List<_Interest> interests) {
    final queries = <String>[];

    for (final interest in interests) {
      switch (interest.type) {
        case _InterestType.genre:
          queries.add('${interest.name} movie trailers 2024');
          queries.add('${interest.name} movie behind the scenes');
          break;
        case _InterestType.movie:
          queries.add('${interest.name} trailer');
          queries.add('${interest.name} cast interview');
          queries.add('${interest.name} behind the scenes');
          break;
        case _InterestType.platform:
          queries.add('new ${interest.name} trailers');
          break;
      }
    }

    // Add some general discovery queries if list is short
    if (queries.length < 5) {
      queries.add('trending movie trailers 2024');
      queries.add('viral movie clips');
    }

    return queries;
  }

  /// Fetches videos for generated queries
  Future<List<FeedVideo>> _fetchVideosFromYouTube(List<String> queries) async {
    final allVideos = <FeedVideo>[];

    // Shuffle queries to mix content types
    queries.shuffle();

    // Limit to top 5 queries to save quota
    final targetQueries = queries.take(5).toList();

    for (final query in targetQueries) {
      final videos = await _youtubeService.fetchVideos(query: query);
      allVideos.addAll(videos);
    }

    // Deduplicate by videoId
    final uniqueVideos = <String, FeedVideo>{};
    for (final video in allVideos) {
      uniqueVideos[video.videoId] = video;
    }

    final result = uniqueVideos.values.toList();
    result.shuffle(); // Mix them up for the feed
    return result;
  }

  // --- Caching Logic ---

  Future<void> _cacheFeed(String uid, List<FeedVideo> videos) async {
    try {
      final batch = _firestore.batch();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Store in a subcollection with a timestamp document or similar structure
      // Here we store the list in a single document for simplicity if size permits,
      // or multiple documents. Given Firestore limits (1MB), 50 videos is fine in one doc.

      await _firestore.collection('feed_cache').doc(uid).set({
        'lastUpdated': timestamp,
        'videos': videos.map((v) => v.toJson()).toList(),
      });
    } catch (e) {
      print('⚠️ Error caching feed: $e');
    }
  }

  Future<List<FeedVideo>?> _getCachedFeed(String uid) async {
    try {
      final doc = await _firestore.collection('feed_cache').doc(uid).get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final lastUpdated = data['lastUpdated'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check 24h TTL (24 * 60 * 60 * 1000 = 86400000 ms)
      if (now - lastUpdated > 86400000) {
        print('⚠️ Cached feed expired');
        return null;
      }

      final List<dynamic> videoList = data['videos'];
      return videoList.map((v) => FeedVideo.fromJson(v)).toList();
    } catch (e) {
      print('⚠️ Error reading cached feed: $e');
      return null;
    }
  }
}

// Helper classes
class _Interest {
  final String name;
  final int score;
  final _InterestType type;

  _Interest(this.name, this.score, this.type);
}

enum _InterestType { genre, movie, platform }
