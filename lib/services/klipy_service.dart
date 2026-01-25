import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:finishd/models/gif_model.dart';

/// Service for interacting with the Klipy GIF API
/// Replaces the previous Giphy integration
class KlipyService {
  static const String _baseUrl = 'https://api.klipy.com/v2';
  static const String _apiKey = 'rut7Q1CHHEPpJ8EMb47E00Dfx3281cqViVjx3pgc1ylLMan1MEobFn9yrZq7qLqo';

  // Cache for recent searches to improve performance
  final Map<String, List<GifModel>> _searchCache = {};
  List<GifModel>? _trendingCache;
  DateTime? _trendingCacheTime;

  /// Search for GIFs by keyword
  /// 
  /// [query] - Search term
  /// [limit] - Number of results to return (default: 25)
  /// [offset] - Offset for pagination (default: 0)
  Future<List<GifModel>> searchGifs({
    required String query,
    int limit = 25,
    int offset = 0,
  }) async {
    try {
      // Check cache first
      final cacheKey = '$query-$limit-$offset';
      if (_searchCache.containsKey(cacheKey)) {
        return _searchCache[cacheKey]!;
      }

      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'key': _apiKey,
          'q': query,
          'limit': limit.toString(),
          'pos': offset.toString(), // Tenor v2 uses 'pos' instead of 'offset'
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'X-API-Key': _apiKey, // Try header as well
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[Klipy] ❌ Search request timed out: $uri');
          throw Exception('Request timed out. Please check your connection.');
        },
      );

      print('[Klipy] GET $uri -> ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = (data['results'] as List?)
                ?.map((item) => GifModel.fromKlipy(item as Map<String, dynamic>))
                .toList() ??
            [];

        // Cache the results
        _searchCache[cacheKey] = results;

        return results;
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to search GIFs: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException')) {
        throw Exception('No internet connection. Please check your network.');
      }
      rethrow;
    }
  }

  /// Get trending/popular GIFs
  /// 
  /// [limit] - Number of results to return (default: 25)
  /// [offset] - Offset for pagination (default: 0)
  Future<List<GifModel>> getTrendingGifs({
    int limit = 25,
    int offset = 0,
  }) async {
    try {
      // Use cache if available and less than 5 minutes old
      if (_trendingCache != null &&
          _trendingCacheTime != null &&
          DateTime.now().difference(_trendingCacheTime!) <
              const Duration(minutes: 5)) {
        return _trendingCache!;
      }

      final uri = Uri.parse('$_baseUrl/featured').replace(
        queryParameters: {
          'key': _apiKey,
          'limit': limit.toString(),
          'pos': offset.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'X-API-Key': _apiKey,
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection.');
        },
      );

      // Handle 204 No Content - Klipy trending endpoint may not be supported
      if (response.statusCode == 204) {
        print('[Klipy] ⚠️ Trending endpoint returned 204 No Content');
        print('[Klipy] 🔄 Falling back to popular search query');
        // Fallback to popular search term
        return await searchGifs(query: 'reactions', limit: limit);
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = (data['results'] as List?)
                ?.map((item) => GifModel.fromKlipy(item as Map<String, dynamic>))
                .toList() ??
            [];

        // Cache the results
        _trendingCache = results;
        _trendingCacheTime = DateTime.now();

        return results;
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        // For other HTTP errors, try fallback before failing
        print('[Klipy] ⚠️ Trending failed with status ${response.statusCode}');
        print('[Klipy] 🔄 Attempting fallback to popular search');
        try {
          return await searchGifs(query: 'popular', limit: limit);
        } catch (fallbackError) {
          // If fallback also fails, throw original error
          throw Exception('Failed to get trending GIFs: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException')) {
        throw Exception('No internet connection. Please check your network.');
      }
      
      // For other exceptions, attempt fallback if not already a fallback error
      if (!e.toString().contains('Failed to get trending GIFs')) {
        print('[Klipy] ⚠️ Exception in trending: $e');
        print('[Klipy] 🔄 Attempting fallback to reactions search');
        try {
          return await searchGifs(query: 'reactions', limit: limit);
        } catch (_) {
          // If fallback fails, rethrow original error
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Clear all caches
  void clearCache() {
    _searchCache.clear();
    _trendingCache = null;
    _trendingCacheTime = null;
  }

  /// Clear search cache only
  void clearSearchCache() {
    _searchCache.clear();
  }
}
