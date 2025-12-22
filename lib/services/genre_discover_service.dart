import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:finishd/Model/trending.dart';
import 'package:finishd/services/discover_cache_service.dart';

class GenreDiscoverService {
  final String _apiKey = '829afd9e186fc15a71a6dfe50f3d00ad';
  final DiscoverCacheService _cacheService = DiscoverCacheService();

  /// Fetch content (Movies + TV) for a specific genre ID
  Future<List<MediaItem>> fetchGenreContent(int genreId) async {
    final cacheKey = 'discover_genre_$genreId';

    // Try cache first
    final cachedData = await _cacheService.getCached(cacheKey);
    if (cachedData != null && cachedData.isNotEmpty) {
      return cachedData;
    }

    try {
      // Fetch Movies for genre
      final movieResults = await _fetchFromTmdb('movie', genreId);
      // Fetch TV Shows for genre
      final tvResults = await _fetchFromTmdb('tv', genreId);

      // Combine and shuffle
      final combined = [...movieResults, ...tvResults];
      combined.shuffle();

      // Limit to 20 items per section for performance
      final limited = combined.take(20).toList();

      // Save to cache
      if (limited.isNotEmpty) {
        await _cacheService.saveToCache(cacheKey, limited);
      }

      return limited;
    } catch (e) {
      print('Error in GenreDiscoverService.fetchGenreContent: $e');
      return [];
    }
  }

  Future<List<MediaItem>> fetchGenreContentPaginated(
    int genreId,
    int page,
  ) async {
    try {
      // For See All, we usually want to show it combined or separate?
      // The SRS says "mediaType" is passed.
      // If we want to show a combined list in See All:
      final movieResults = await _fetchFromTmdb('movie', genreId, page: page);
      final tvResults = await _fetchFromTmdb('tv', genreId, page: page);

      final combined = [...movieResults, ...tvResults];
      combined.shuffle();
      return combined;
    } catch (e) {
      print('Error in GenreDiscoverService.fetchGenreContentPaginated: $e');
      return [];
    }
  }

  Future<List<MediaItem>> _fetchFromTmdb(
    String mediaType,
    int genreId, {
    int page = 1,
  }) async {
    final url =
        'https://api.themoviedb.org/3/discover/$mediaType?api_key=$_apiKey&with_genres=$genreId&sort_by=popularity.desc&language=en-US&page=$page';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];
      return results
          .map((json) => MediaItem.fromJson(json, type: mediaType))
          .toList();
    } else {
      throw Exception('Failed to fetch $mediaType for genre $genreId');
    }
  }
}
