import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/movie_ratings_model.dart';
import 'package:finishd/services/cache/ratings_cache_service.dart';
import 'package:http/http.dart' as http;

/// Service class for fetching and caching movie ratings from multiple sources
/// Integrates TMDB API (for IMDb ID) and OMDb API (for ratings)
/// Implements intelligent caching with 7-day TTL in Firestore
class RatingsService {
  // API Keys - Replace with your actual keys
  static const String TMDB_API_KEY = "829afd9e186fc15a71a6dfe50f3d00ad";
  static const String OMDB_API_KEY =
      "3ab8a1fe"; // TODO: Add your OMDb API key

  /// Main entry point: Get ratings with intelligent SQLite caching
  Future<MovieRatings> getRatings(int tmdbId) async {
    try {
      // 1. Check SQLite Cache (30 day TTL)
      final cachedMap = await RatingsCacheService.getRatings(tmdbId.toString());

      if (cachedMap != null) {
        print('✅ [SQLite] Using cached ratings for TMDB: $tmdbId');
        return MovieRatings(
            imdbId: cachedMap['imdbId'] ?? '',
            imdbRating: cachedMap['imdbRating'] ?? 'N/A',
            rotten: cachedMap['rotten'] ?? 'N/A',
            metacritic: cachedMap['metacritic'] ?? 'N/A',
            imdbVotes: cachedMap['imdbVotes'] ?? '0',
            lastUpdated: cachedMap['lastUpdated'] != null
                ? (cachedMap['lastUpdated'] is int
                    ? DateTime.fromMillisecondsSinceEpoch(cachedMap['lastUpdated'])
                    : DateTime.tryParse(cachedMap['lastUpdated'].toString()) ?? DateTime.now())
                : DateTime.now(),
        );
      }

      // 2. Fetch fresh data
      print('🔄 Fetching fresh ratings for TMDB ID: $tmdbId');
      final freshRatings = await fetchFromApi(tmdbId);

      // 3. Save to SQLite Cache
      // Convert Timestamp to int for JSON compatibility
      final mapToSave = freshRatings.toFirestore();
      if (mapToSave['lastUpdated'] is Timestamp) {
         mapToSave['lastUpdated'] = (mapToSave['lastUpdated'] as Timestamp).millisecondsSinceEpoch;
      } else if (mapToSave['lastUpdated'] is DateTime) {
         mapToSave['lastUpdated'] = (mapToSave['lastUpdated'] as DateTime).millisecondsSinceEpoch;
      }
      
      await RatingsCacheService.saveRatings(tmdbId.toString(), mapToSave);

      return freshRatings;
    } catch (e) {
      print('❌ Error in getRatings: $e');
      return MovieRatings.empty();
    }
  }

  /// Fetches ratings from external APIs (TMDB + OMDb)
  Future<MovieRatings> fetchFromApi(int tmdbId) async {
    try {
      // Step 1: Get IMDb ID from TMDB
      final imdbId = await _getImdbIdFromTmdb(tmdbId);

      if (imdbId.isEmpty) {
        return MovieRatings.empty();
      }

      // Step 2: Fetch ratings from OMDb using IMDb ID
      final omdbData = await _fetchFromOmdb(imdbId);

      if (omdbData == null) {
        return MovieRatings.empty();
      }

      // Step 3: Parse and return ratings
      return MovieRatings.fromOmdbJson(omdbData, imdbId);
    } catch (e) {
      print('❌ Error in fetchFromApi: $e');
      return MovieRatings.empty();
    }
  }

  // ========================================================================
  // PRIVATE HELPER METHODS
  // ========================================================================

  Future<String> _getImdbIdFromTmdb(int tmdbId) async {
    try {
      final url = Uri.parse(
        'https://api.themoviedb.org/3/movie/$tmdbId/external_ids?api_key=$TMDB_API_KEY',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('TMDB API timeout'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['imdb_id'] ?? '';
      }
      return '';
    } catch (e) {
      print('❌ Error fetching IMDb ID: $e');
      return '';
    }
  }

  Future<Map<String, dynamic>?> _fetchFromOmdb(String imdbId) async {
    try {
      final url = Uri.parse(
        'https://www.omdbapi.com/?i=$imdbId&apikey=$OMDB_API_KEY',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('OMDb API timeout'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['Response'] == 'False') return null;
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Error fetching from OMDb: $e');
      return null;
    }
  }

  Future<void> clearCache(int tmdbId) async {
    await RatingsCacheService.clear(tmdbId.toString());
  }
}
