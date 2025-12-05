import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:finishd/models/feed_video.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:finishd/services/user_preferences_service.dart';
import 'package:finishd/services/youtube_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'dart:math';

class PersonalizedFeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserPreferencesService _prefsService = UserPreferencesService();
  final MovieListService _movieListService = MovieListService();
  final YouTubeService _youtubeService = YouTubeService();
  final UserService _userService = UserService();
  final Trending _trendingService = Trending();

  // Weights for interest calculation
  static const int _weightGenre = 5;
  static const int _weightLiked = 8; // Favorites
  static const int _weightWatchlist = 6;
  static const int _weightWatching = 7;
  static const int _weightFinished = 4;
  static const int _weightPlatform = 3;
  static const int _weightFriendActivity = 9; // High weight for social proof
  static const int _weightTrending = 5;

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

      // 3. Generate Smart Queries with Context
      final queriesWithContext = _buildUserFeedQueries(interests);

      // 4. Fetch Videos from YouTube
      final videos = await _fetchVideosFromYouTube(queriesWithContext);

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
    final Map<String, _Interest> interestMap = {};

    // Fetch all data in parallel
    final results = await Future.wait([
      _prefsService.getUserPreferences(uid),
      _movieListService.getMoviesFromList(uid, 'favorites'),
      _movieListService.getMoviesFromList(uid, 'watchlist'),
      _movieListService.getMoviesFromList(uid, 'watching'),
      _movieListService.getMoviesFromList(uid, 'finished'),
      _getFriendsInterests(uid), // New: Friends' activity
      _getTrendingInterests(), // New: Trending data
    ]);

    final prefs = results[0] as UserPreferences?;
    final favorites = results[1] as List<dynamic>;
    final watchlist = results[2] as List<dynamic>;
    final watching = results[3] as List<dynamic>;
    final finished = results[4] as List<dynamic>;
    final friendsInterests = results[5] as List<_Interest>;
    final trendingInterests = results[6] as List<_Interest>;

    // Helper to merge interests
    void mergeInterest(_Interest interest) {
      if (interestMap.containsKey(interest.name)) {
        final existing = interestMap[interest.name]!;
        interestMap[interest.name] = _Interest(
          existing.name,
          existing.score + interest.score,
          existing.type,
          reason:
              interest.reason ??
              existing.reason, // Prefer new reason if available
        );
      } else {
        interestMap[interest.name] = interest;
      }
    }

    // Process Genres
    if (prefs != null) {
      for (final genre in prefs.selectedGenres) {
        mergeInterest(_Interest(genre, _weightGenre, _InterestType.genre));
      }
      for (final provider in prefs.streamingProviders) {
        mergeInterest(
          _Interest(
            provider.providerName,
            _weightPlatform,
            _InterestType.platform,
          ),
        );
      }
    }

    // Process Movies (Favorites, Watchlist, etc.)
    for (final movie in favorites) {
      mergeInterest(_Interest(movie.title, _weightLiked, _InterestType.movie));
    }
    for (final movie in watching) {
      mergeInterest(
        _Interest(movie.title, _weightWatching, _InterestType.movie),
      );
    }
    for (final movie in watchlist) {
      mergeInterest(
        _Interest(movie.title, _weightWatchlist, _InterestType.movie),
      );
    }
    for (final movie in finished) {
      mergeInterest(
        _Interest(movie.title, _weightFinished, _InterestType.movie),
      );
    }

    // Process Friends' Interests
    for (final interest in friendsInterests) {
      mergeInterest(interest);
    }

    // Process Trending Interests
    for (final interest in trendingInterests) {
      mergeInterest(interest);
    }

    // Convert to list and sort by score
    final sortedInterests = interestMap.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Return all interests to allow better filtering by type
    return sortedInterests;
  }

  /// Fetches interests based on friends' activity
  Future<List<_Interest>> _getFriendsInterests(String uid) async {
    final interests = <_Interest>[];
    try {
      final followingIds = await _userService.getFollowing(uid);
      if (followingIds.isEmpty) return [];

      // Shuffle and take top 5 friends to avoid excessive reads
      followingIds.shuffle();
      final targetFriends = followingIds.take(5).toList();

      // Fetch friends' names for the reason string
      final friends = await _userService.getUsers(targetFriends);
      final friendMap = {for (var u in friends) u.uid: u.firstName};

      for (final friendId in targetFriends) {
        final friendName = friendMap[friendId] ?? 'A friend';

        // Check what they are watching
        final watching = await _movieListService.getMoviesFromList(
          friendId,
          'watching',
        );
        for (final movie in watching.take(2)) {
          // Take top 2 per friend
          interests.add(
            _Interest(
              movie.title,
              _weightFriendActivity,
              _InterestType.social,
              reason: "$friendName is watching",
            ),
          );
        }

        // Check their favorites
        final favorites = await _movieListService.getMoviesFromList(
          friendId,
          'favorites',
        );
        for (final movie in favorites.take(1)) {
          interests.add(
            _Interest(
              movie.title,
              _weightFriendActivity,
              _InterestType.social,
              reason: "$friendName's favorite",
            ),
          );
        }
      }
    } catch (e) {
      print('⚠️ Error fetching friends interests: $e');
    }
    return interests;
  }

  /// Fetches trending movies and shows from TMDB
  Future<List<_Interest>> _getTrendingInterests() async {
    final interests = <_Interest>[];
    try {
      final trendingMovies = await _trendingService.fetchTrendingMovie();
      final trendingShows = await _trendingService.fetchTrendingShow();

      for (final item in trendingMovies.take(3)) {
        interests.add(
          _Interest(
            item.title ?? 'Unknown',
            _weightTrending,
            _InterestType.trending,
            reason: "Trending Movie",
          ),
        );
      }

      for (final item in trendingShows.take(3)) {
        interests.add(
          _Interest(
            item.title ?? 'Unknown',
            _weightTrending,
            _InterestType.trending,
            reason: "Trending TV Show",
          ),
        );
      }
    } catch (e) {
      print('⚠️ Error fetching trending interests: $e');
    }
    return interests;
  }

  /// Generates YouTube search queries based on interests with 50/30/20 split
  List<_QueryContext> _buildUserFeedQueries(List<_Interest> interests) {
    final queries = <_QueryContext>[];

    // 1. Categorize Interests
    final trendingDiscoveryInterests = interests
        .where(
          (i) =>
              i.type == _InterestType.trending ||
              i.type == _InterestType.genre ||
              i.type == _InterestType.platform,
        )
        .toList();

    final socialInterests = interests
        .where((i) => i.type == _InterestType.social)
        .toList();

    final personalInterests = interests
        .where((i) => i.type == _InterestType.movie)
        .toList();

    // 2. Shuffle for Randomization (as requested)
    trendingDiscoveryInterests.shuffle();
    socialInterests.shuffle();
    personalInterests.shuffle();

    // 3. Select based on Ratio (Target: 10 queries)
    // 50% Trending/Discovery (5 queries)
    // 30% Friends (3 queries)
    // 20% Personal (2 queries)

    void addQueriesFromInterests(List<_Interest> source, int count) {
      for (var i = 0; i < count && i < source.length; i++) {
        final interest = source[i];
        queries.add(_generateQueryForInterest(interest));
      }
    }

    addQueriesFromInterests(trendingDiscoveryInterests, 5);
    addQueriesFromInterests(socialInterests, 3);
    addQueriesFromInterests(personalInterests, 2);

    // 4. Fill gaps if any category was short
    final currentCount = queries.length;
    if (currentCount < 10) {
      // Fill with more trending/discovery first
      final usedTrending = min(5, trendingDiscoveryInterests.length);
      if (trendingDiscoveryInterests.length > usedTrending) {
        for (
          var i = usedTrending;
          i < trendingDiscoveryInterests.length && queries.length < 10;
          i++
        ) {
          queries.add(_generateQueryForInterest(trendingDiscoveryInterests[i]));
        }
      }
    }

    // If still short, add generic trending
    if (queries.length < 5) {
      queries.add(
        _QueryContext('trending movie trailers 2024', "Trending Movies"),
      );
      queries.add(_QueryContext('viral movie clips', "Viral Clips"));
      queries.add(
        _QueryContext('new movie trailers this week', "New Releases"),
      );
    }

    return queries;
  }

  _QueryContext _generateQueryForInterest(_Interest interest) {
    switch (interest.type) {
      case _InterestType.genre:
        return _QueryContext(
          '${interest.name} movie trailers 2024',
          "Because you like ${interest.name}",
        );
      case _InterestType.movie:
        // Randomize query type for movies to avoid repetition
        final random = Random().nextInt(3);
        if (random == 0) {
          return _QueryContext(
            '${interest.name} trailer',
            "Because you watched ${interest.name}",
          );
        } else if (random == 1) {
          return _QueryContext(
            '${interest.name} cast interview',
            "Cast of ${interest.name}",
          );
        } else {
          return _QueryContext(
            '${interest.name} best scenes',
            "Scenes from ${interest.name}",
          );
        }
      case _InterestType.platform:
        return _QueryContext(
          'new ${interest.name} trailers',
          "New on ${interest.name}",
        );
      case _InterestType.social:
        return _QueryContext(
          '${interest.name} trailer',
          interest.reason ?? "Recommended by friends",
        );
      case _InterestType.trending:
        return _QueryContext(
          '${interest.name} trailer',
          interest.reason ?? "Trending now",
        );
    }
  }

  /// Fetches videos for generated queries
  Future<List<FeedVideo>> _fetchVideosFromYouTube(
    List<_QueryContext> queries,
  ) async {
    final allVideos = <FeedVideo>[];

    // Shuffle queries to mix content types
    queries.shuffle();

    // Limit to top 8 queries to save quota but get variety
    final targetQueries = queries.take(8).toList();

    for (final q in targetQueries) {
      final videos = await _youtubeService.fetchVideos(query: q.query);

      // Attach context to videos
      final videosWithContext = videos
          .map(
            (v) => v.copyWith(
              recommendationReason: q.reason,
              relatedItemType: 'recommendation', // Simplified for now
            ),
          )
          .toList();

      allVideos.addAll(videosWithContext);
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
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
  final String? reason;

  _Interest(this.name, this.score, this.type, {this.reason});
}

class _QueryContext {
  final String query;
  final String reason;

  _QueryContext(this.query, this.reason);
}

enum _InterestType { genre, movie, platform, social, trending }
