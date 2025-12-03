import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/movie_ratings_model.dart';
import 'package:http/http.dart' as http;

/// Service class for fetching and caching movie ratings from multiple sources
/// Integrates TMDB API (for IMDb ID) and OMDb API (for ratings)
/// Implements intelligent caching with 7-day TTL in Firestore
class RatingsService {
  // API Keys - Replace with your actual keys
  static const String TMDB_API_KEY = "829afd9e186fc15a71a6dfe50f3d00ad";
  static const String OMDB_API_KEY =
      "3ab8a1fe"; // TODO: Add your OMDb API key

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Main entry point: Get ratings with intelligent caching
  ///
  /// Flow:
  /// 1. Check Firestore for cached ratings
  /// 2. If fresh (< 7 days) → return cached
  /// 3. If stale or missing → fetch from API → cache → return
  ///
  /// @param tmdbId The TMDB movie ID
  /// @returns MovieRatings object (never null, falls back to empty())
  Future<MovieRatings> getRatings(int tmdbId) async {
    try {
      // Check Firestore cache first
      final cachedRatings = await _getCachedRatings(tmdbId);

      if (cachedRatings != null && cachedRatings.isFresh()) {
        print('✅ Using cached ratings for TMDB ID: $tmdbId');
        return cachedRatings;
      }

      // Cache is stale or missing, fetch fresh data
      print('🔄 Fetching fresh ratings for TMDB ID: $tmdbId');
      final freshRatings = await fetchFromApi(tmdbId);

      // Save to cache for future use
      await saveRatingsToFirestore(tmdbId, freshRatings);

      return freshRatings;
    } catch (e) {
      print('❌ Error in getRatings: $e');
      return MovieRatings.empty();
    }
  }

  /// Fetches ratings from external APIs (TMDB + OMDb)
  ///
  /// Process:
  /// 1. Get IMDb ID from TMDB external IDs endpoint
  /// 2. Use IMDb ID to fetch ratings from OMDb
  /// 3. Parse and return MovieRatings object
  ///
  /// @param tmdbId The TMDB movie ID
  /// @returns MovieRatings object with fresh data
  Future<MovieRatings> fetchFromApi(int tmdbId) async {
    try {
      // Step 1: Get IMDb ID from TMDB
      final imdbId = await _getImdbIdFromTmdb(tmdbId);

      if (imdbId.isEmpty) {
        print('⚠️ No IMDb ID found for TMDB ID: $tmdbId');
        return MovieRatings.empty();
      }

      // Step 2: Fetch ratings from OMDb using IMDb ID
      final omdbData = await _fetchFromOmdb(imdbId);

      if (omdbData == null) {
        print('⚠️ No OMDb data found for IMDb ID: $imdbId');
        return MovieRatings.empty();
      }

      // Step 3: Parse and return ratings
      return MovieRatings.fromOmdbJson(omdbData, imdbId);
    } catch (e) {
      print('❌ Error in fetchFromApi: $e');
      return MovieRatings.empty();
    }
  }

  /// Saves ratings to Firestore for caching
  ///
  /// @param tmdbId The TMDB movie ID (used as document ID)
  /// @param ratings The ratings data to cache
  Future<void> saveRatingsToFirestore(int tmdbId, MovieRatings ratings) async {
    try {
      await _firestore
          .collection('movies')
          .doc(tmdbId.toString())
          .collection('ratings')
          .doc('data')
          .set(ratings.toFirestore());

      print('💾 Saved ratings to Firestore for TMDB ID: $tmdbId');
    } catch (e) {
      print('❌ Error saving to Firestore: $e');
      // Don't throw - caching failure shouldn't break the app
    }
  }

  // ========================================================================
  // PRIVATE HELPER METHODS
  // ========================================================================

  /// Retrieves cached ratings from Firestore
  Future<MovieRatings?> _getCachedRatings(int tmdbId) async {
    try {
      final doc = await _firestore
          .collection('movies')
          .doc(tmdbId.toString())
          .collection('ratings')
          .doc('data')
          .get();

      if (!doc.exists) {
        return null;
      }

      return MovieRatings.fromFirestore(doc);
    } catch (e) {
      print('❌ Error getting cached ratings: $e');
      return null;
    }
  }

  /// Fetches IMDb ID from TMDB external IDs endpoint
  ///
  /// Endpoint: https://api.themoviedb.org/3/movie/{tmdbId}/external_ids
  ///
  /// @param tmdbId The TMDB movie ID
  /// @returns IMDb ID (e.g., "tt1234567") or empty string if not found
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
        final imdbId = data['imdb_id'] ?? '';
        print('✅ Found IMDb ID: $imdbId for TMDB ID: $tmdbId');
        return imdbId;
      } else if (response.statusCode == 429) {
        print('⚠️ TMDB rate limit exceeded');
        throw Exception('Rate limit exceeded');
      } else {
        print('⚠️ TMDB API error: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('❌ Error fetching IMDb ID from TMDB: $e');
      return '';
    }
  }

  /// Fetches movie data from OMDb API
  ///
  /// Endpoint: https://www.omdbapi.com/?i={imdbId}&apikey={key}
  ///
  /// @param imdbId The IMDb ID (e.g., "tt1234567")
  /// @returns JSON map with ratings data or null if failed
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

        // Check if OMDb returned an error
        if (data['Response'] == 'False') {
          print('⚠️ OMDb error: ${data['Error']}');
          return null;
        }

        print('✅ Fetched OMDb data for IMDb ID: $imdbId');
        return data;
      } else if (response.statusCode == 401) {
        print('⚠️ Invalid OMDb API key');
        throw Exception('Invalid API key');
      } else {
        print('⚠️ OMDb API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching from OMDb: $e');
      return null;
    }
  }

  /// Clears cached ratings for a specific movie (useful for testing/refresh)
  Future<void> clearCache(int tmdbId) async {
    try {
      await _firestore
          .collection('movies')
          .doc(tmdbId.toString())
          .collection('ratings')
          .doc('data')
          .delete();

      print('🗑️ Cleared ratings cache for TMDB ID: $tmdbId');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }
}
