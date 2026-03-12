import 'dart:async';
import 'package:finishd/Model/Searchdiscover.dart';
import 'package:finishd/services/feed_search_service.dart';
import 'package:finishd/tmbd/Search.dart';

/// Unified Search Service
///
/// Orchestrates search across multiple sources (Feed Backend and TMDB)
/// and provides deduplicated results.
class UnifiedSearchService {
  // Singleton pattern
  static final UnifiedSearchService _instance = UnifiedSearchService._internal();
  factory UnifiedSearchService() => _instance;
  UnifiedSearchService._internal();

  final FeedSearchService _feedSearchService = FeedSearchService();
  final SearchDiscover _tmdbSearchApi = SearchDiscover();

  /// Perform a global search across all content sources
  Future<List<Result>> searchAll(String query, {int feedLimit = 20}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    try {
      // Search both sources in parallel for speed
      final results = await Future.wait([
        _feedSearchService.search(trimmedQuery, limit: feedLimit),
        _tmdbSearchApi.getSearchitem(trimmedQuery),
      ]);

      final feedResults = results[0];
      final tmdbResults = results[1];

      // Merge results: feed first (curated), then TMDB (deduplicated by ID)
      final seenIds = <int>{};
      final mergedResults = <Result>[];

      // 1. Add feed results first (higher priority - curated content)
      for (final item in feedResults) {
        if (item.id != null && !seenIds.contains(item.id)) {
          seenIds.add(item.id!);
          mergedResults.add(item);
        }
      }

      // 2. Add TMDB results (broader coverage)
      for (final item in tmdbResults) {
        if (item.id != null && !seenIds.contains(item.id)) {
          seenIds.add(item.id!);
          mergedResults.add(item);
        }
      }

      return mergedResults;
    } catch (e) {
      print('❌ UnifiedSearchService error: $e');
      return [];
    }
  }
}
