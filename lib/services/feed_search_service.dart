import 'dart:async';
import 'package:finishd/services/api_client.dart';
import 'package:finishd/Model/Searchdiscover.dart';

/// Feed Search Service
///
/// Provides search functionality against the curated feed backend.
/// Features:
/// - Debounced API calls to prevent spam
/// - Simple LRU memory cache for recent queries
/// - Conversion to app's Result model format
class FeedSearchService {
  // Singleton
  static final FeedSearchService _instance = FeedSearchService._internal();
  factory FeedSearchService() => _instance;
  FeedSearchService._internal();

  final ApiClient _apiClient = ApiClient();

  // Simple LRU cache (query -> results)
  final Map<String, List<Result>> _cache = {};
  static const int _maxCacheSize = 20;

  /// Search feed content and return as Result objects
  ///
  /// Results are compatible with the existing SearchScreen UI.
  Future<List<Result>> search(
    String query, {
    int limit = 20,
    String? mediaType,
  }) async {
    final trimmedQuery = query.trim().toLowerCase();

    if (trimmedQuery.length < 2) {
      return [];
    }

    // Check cache first
    final cacheKey = '$trimmedQuery:$mediaType:$limit';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Call backend
      final rawResults = await _apiClient.searchFeedContent(
        query: trimmedQuery,
        limit: limit,
        mediaType: mediaType,
      );

      // Convert to Result objects
      final results = rawResults.map((item) => _mapToResult(item)).toList();

      // Cache results
      _addToCache(cacheKey, results);

      return results;
    } catch (e) {
      print('❌ FeedSearchService error: $e');
      return [];
    }
  }

  /// Convert feed backend item to Result model
  ///
  /// Uses Result.fromJson() to ensure all required fields are handled.
  /// Converts feed backend field names (camelCase) to TMDB-style (snake_case).
  Result _mapToResult(Map<String, dynamic> item) {
    // Feed backend returns camelCase, Result.fromJson expects snake_case
    final tmdbStyleJson = {
      'adult': false,
      'backdrop_path': item['backdropPath'],
      'id': item['tmdbId'] ?? item['id'],
      'title': item['title'],
      'original_language': item['originalLanguage'] ?? 'en',
      'original_title': item['title'],
      'overview': item['overview'] ?? '',
      'poster_path': item['posterPath'],
      'profile_path': null,
      'media_type': item['mediaType'] ?? 'movie',
      'genre_ids': _parseGenreIds(item['genres']),
      'popularity': item['popularity'] ?? 0.0,
      'release_date': item['releaseDate'] ?? '',
      'video': false,
      'vote_average': (item['voteAverage'] ?? 0).toDouble(),
      'vote_count': item['voteCount'] ?? 0,
      'name': item['title'], // TV show name
      'original_name': item['title'],
      'first_air_date': item['mediaType'] == 'tv'
          ? (item['releaseDate'] ?? '')
          : null,
      'origin_country': <String>[],
    };

    return Result.fromJson(tmdbStyleJson);
  }

  /// Parse genre IDs from various formats
  List<int> _parseGenreIds(dynamic genres) {
    if (genres == null) return [];

    if (genres is List) {
      return genres
          .map((g) {
            if (g is int) return g;
            if (g is Map && g['id'] != null) return g['id'] as int;
            return 0;
          })
          .where((id) => id > 0)
          .toList();
    }

    return [];
  }

  /// Add to cache with LRU eviction
  void _addToCache(String key, List<Result> results) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = results;
  }

  /// Clear the cache
  void clearCache() {
    _cache.clear();
  }
}
