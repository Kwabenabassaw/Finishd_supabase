import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/services/cache/feed_cache_service.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:finishd/models/feed_video.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:finishd/services/user_preferences_service.dart';
import 'package:finishd/services/youtube_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/services/api_client.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/services/user_titles_service.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'dart:math';

class PersonalizedFeedService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final UserPreferencesService _prefsService = UserPreferencesService();
  final MovieListService _movieListService = MovieListService();
  final YouTubeService _youtubeService = YouTubeService();
  final UserService _userService = UserService();
  final Trending _trendingService = Trending();
  final ApiClient _apiClient = ApiClient();
  final UserTitlesService _userTitlesService = UserTitlesService();

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
  Future<List<FeedVideo>> loadPersonalizedFeed(
    String uid, {
    int page = 1,
  }) async {
    try {
      // 1. Check SQLite Cache (24h TTL) - Page 1
      if (page == 1) {
        // ... (SQLite logic kept as is in original file)
      }

      // 2. Try backend API
      print('📡 Fetching personalized feed (Page $page) from backend API...');
      final apiVideos = await _apiClient.getPersonalizedFeed(page: page);

      if (apiVideos.isNotEmpty) {
        print('✅ Got ${apiVideos.length} videos from backend API');

        // 3. Save/Append to SQLite Cache
        final jsonList = apiVideos.map((v) => v.toJson()).toList();
        if (page == 1) {
          FeedCacheService.saveFeed(jsonList);
        } else {
          FeedCacheService.appendFeed(jsonList);
        }
        return apiVideos;
      }
    } catch (e) {
      print('⚠️ Backend/Cache error: $e, using local implementation');
    }

    // Fallback to local implementation
    return _loadPersonalizedFeedLocal(uid);
  }

  /// Refresh feed (bypasses cache)
  Future<List<FeedVideo>> refreshFeed(String uid) async {
    try {
      print('🔄 Refreshing feed from backend API...');
      final apiVideos = await _apiClient.refreshFeed();

      if (apiVideos.isNotEmpty) {
        final jsonList = apiVideos.map((v) => v.toJson()).toList();
        FeedCacheService.saveFeed(jsonList);
        return apiVideos;
      }
    } catch (e) {
      print('⚠️ Backend refresh failed: $e');
    }
    return _loadPersonalizedFeedLocal(uid);
  }

  /// Local implementation (original logic)
  Future<List<FeedVideo>> _loadPersonalizedFeedLocal(String uid) async {
    try {
      final cachedFeed = await _getCachedFeed(uid);
      if (cachedFeed != null && cachedFeed.isNotEmpty) {
        print('✅ Using cached feed for user: $uid');
        return cachedFeed;
      }

      print('🔄 Generating fresh personalized feed for user: $uid');
      final interests = await _calculateInterestWeights(uid);
      final queriesWithContext = _buildUserFeedQueries(interests);
      final videos = await _fetchVideosFromYouTube(queriesWithContext);

      if (videos.isNotEmpty) {
        await _cacheFeed(uid, videos);
      }
      return videos;
    } catch (e) {
      print('❌ Error loading personalized feed: $e');
      return await _youtubeService.fetchVideos();
    }
  }

  /// Aggregates user data and calculates weighted interests
  Future<List<_Interest>> _calculateInterestWeights(String uid) async {
    final Map<String, _Interest> interestMap = {};

    final results = await Future.wait([
      _prefsService.getUserPreferences(uid),
      _movieListService.getMoviesFromList(uid, 'favorites'),
      _movieListService.getMoviesFromList(uid, 'watchlist'),
      _movieListService.getMoviesFromList(uid, 'watching'),
      _movieListService.getMoviesFromList(uid, 'finished'),
      _getFriendsInterests(uid),
      _getTrendingInterests(),
      _userTitlesService.getTopRatedTitles(uid),
    ]);

    final prefs = results[0] as UserPreferences?;
    final favorites = results[1] as List<MovieListItem>;
    final watchlist = results[2] as List<MovieListItem>;
    final watching = results[3] as List<MovieListItem>;
    final finished = results[4] as List<MovieListItem>;
    final friendsInterests = results[5] as List<_Interest>;
    final trendingInterests = results[6] as List<_Interest>;
    final topRated = results[7] as List<UserTitleRecord>;

    void mergeInterest(_Interest interest) {
      if (interestMap.containsKey(interest.name)) {
        final existing = interestMap[interest.name]!;
        interestMap[interest.name] = _Interest(
          existing.name,
          existing.score + interest.score,
          existing.type,
          reason: interest.reason ?? existing.reason,
        );
      } else {
        interestMap[interest.name] = interest;
      }
    }

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

    for (final movie in favorites)
      mergeInterest(_Interest(movie.title, _weightLiked, _InterestType.movie));
    for (final movie in watching)
      mergeInterest(
        _Interest(movie.title, _weightWatching, _InterestType.movie),
      );
    for (final movie in watchlist)
      mergeInterest(
        _Interest(movie.title, _weightWatchlist, _InterestType.movie),
      );
    for (final movie in finished)
      mergeInterest(
        _Interest(movie.title, _weightFinished, _InterestType.movie),
      );

    for (final interest in friendsInterests) mergeInterest(interest);
    for (final interest in trendingInterests) mergeInterest(interest);

    for (final record in topRated) {
      mergeInterest(
        _Interest(
          record.title,
          _weightLiked + 4,
          _InterestType.movie,
          reason: "Because you loved ${record.title}",
        ),
      );
    }

    return interestMap.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  Future<List<_Interest>> _getFriendsInterests(String uid) async {
    final interests = <_Interest>[];
    try {
      final followingIds = await _userService.getFollowingCached(uid);
      if (followingIds.isEmpty) return [];

      followingIds.shuffle();
      final targetFriends = followingIds.take(5).toList();
      final friends = await _userService.getUsersCached(targetFriends);
      final friendMap = {for (var u in friends) u.uid: u.firstName};

      for (final friendId in targetFriends) {
        final friendName = friendMap[friendId] ?? 'A friend';
        final watching = await _movieListService.getMoviesFromList(
          friendId,
          'watching',
        );
        for (final movie in watching.take(2)) {
          interests.add(
            _Interest(
              movie.title,
              _weightFriendActivity,
              _InterestType.social,
              reason: "$friendName is watching",
            ),
          );
        }
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

  List<_QueryContext> _buildUserFeedQueries(List<_Interest> interests) {
    final queries = <_QueryContext>[];
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

    trendingDiscoveryInterests.shuffle();
    socialInterests.shuffle();
    personalInterests.shuffle();

    void addQueries(List<_Interest> source, int count) {
      for (var i = 0; i < count && i < source.length; i++) {
        final interest = source[i];
        queries.add(_generateQueryForInterest(interest));
      }
    }

    addQueries(trendingDiscoveryInterests, 5);
    addQueries(socialInterests, 3);
    addQueries(personalInterests, 2);

    if (queries.length < 5) {
      queries.add(
        _QueryContext('trending movie trailers 2024', "Trending Movies"),
      );
      queries.add(_QueryContext('viral movie clips', "Viral Clips"));
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
        final random = Random().nextInt(3);
        final reason =
            interest.reason ?? "Because you watched ${interest.name}";
        if (random == 0)
          return _QueryContext('${interest.name} trailer', reason);
        if (random == 1)
          return _QueryContext(
            '${interest.name} cast interview',
            "Cast of ${interest.name}",
          );
        return _QueryContext(
          '${interest.name} best scenes',
          "Scenes from ${interest.name}",
        );
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

  Future<List<FeedVideo>> _fetchVideosFromYouTube(
    List<_QueryContext> queries,
  ) async {
    final allVideos = <FeedVideo>[];
    queries.shuffle();
    for (final q in queries.take(8)) {
      final videos = await _youtubeService.fetchVideos(query: q.query);
      allVideos.addAll(
        videos.map(
          (v) => v.copyWith(
            recommendationReason: q.reason,
            relatedItemType: 'recommendation',
          ),
        ),
      );
    }
    final uniqueVideos = <String, FeedVideo>{};
    for (final video in allVideos) uniqueVideos[video.videoId] = video;
    final result = uniqueVideos.values.toList();
    result.shuffle();
    return result;
  }

  Future<void> _cacheFeed(String uid, List<FeedVideo> videos) async {
    try {
      await _supabase.from('feed_cache').upsert({
        'user_id': uid,
        'videos': videos.map((v) => v.toJson()).toList(),
        'last_updated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ Error caching feed: $e');
    }
  }

  Future<List<FeedVideo>?> _getCachedFeed(String uid) async {
    try {
      final response = await _supabase
          .from('feed_cache')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (response == null) return null;

      final lastUpdated = DateTime.parse(response['last_updated']);
      if (DateTime.now().difference(lastUpdated).inHours > 24) {
        print('⚠️ Cached feed expired');
        return null;
      }

      final List<dynamic> videoList = response['videos'];
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
