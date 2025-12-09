import 'package:finishd/services/api_client.dart';
import 'package:finishd/services/cache/trending_cache_service.dart';

/// Service for fetching trending content from the backend API
class BackendTrendingService {
  final ApiClient _apiClient = ApiClient();

  /// Get top 10 trending movies
  Future<List<Map<String, dynamic>>> getTrendingMovies({bool refresh = false}) async {
    try {
      // 1. Check Cache if not refreshing
      if (!refresh) {
        final cached = await TrendingCacheService.getTrending('movie');
        if (cached != null && cached.isNotEmpty) {
          print('✅ [SQLite] Loaded trending movies from cache');
          return cached.cast<Map<String, dynamic>>();
        }
      }

      // 2. Fetch from API
      final data = await _apiClient.getTrending(refresh: refresh);

      // 3. Save to Cache
      if (data.isNotEmpty) {
        TrendingCacheService.saveTrending('movie', data);
      }
      return data;
    } catch (e) {
      print('❌ Error fetching trending movies: $e');
      return [];
    }
  }

  /// Get all trending content (movies and shows)
  Future<Map<String, dynamic>> getAllTrending({
    int movieLimit = 10,
    int showLimit = 10,
  }) async {
    try {
      // 1. Check Cache
      final cachedList = await TrendingCacheService.getTrending('all_trending');
      if (cachedList != null && cachedList.isNotEmpty) {
        // We stored the map as a list with 1 item or just cast logic? 
        // Our service stores List<dynamic>, so we might need to wrap the map or checking if we can store map logic.
        // The service stores List<dynamic> (jsonDecode returns dynamic). 
        // Actually TrendingCacheService uses jsonEncode(data) where data is List<dynamic>. 
        // Here we return Map<String, dynamic>. 
        // Let's modify behavior: The cache service stores whatever we pass if we treat it as dynamic content?
        // Wait, TrendingCacheService.saveTrending takes `List<dynamic>`.
        // getAllTrending returns `Map<String, dynamic>`.
        // We shouldn't use the existing `saveTrending` for this Map unless we change the signature or wrap it.
        // Let's wrap it in a list [data] to store, or skip caching this composite endpoint if it just calls individual ones?
        // Actually, _apiClient.getAllTrending might be optimized.
        // Let's check if we can skip caching 'all' or if user strictly wants it.
        // "Trending never hit the server twice"
        // Let's cache 'movie' and 'tv' separately if possible, or wrap the map.
        // Wrapper approach:
        return cachedList.first as Map<String, dynamic>;
      }

      final data = await _apiClient.getAllTrending(
        movieLimit: movieLimit,
        showLimit: showLimit,
      );
      
      // Save Cache (Wrap map in list to fit signature)
      TrendingCacheService.saveTrending('all_trending', [data]);

      return data;
    } catch (e) {
      print('❌ Error fetching all trending: $e');
      return {'movies': [], 'shows': []};
    }
  }
}
