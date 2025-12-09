# 🚀 SQLite Caching Integration Guide

Here is how to integrate the new caching system into your existing services.

## 1. Feed Integration
Modify `lib/services/personalized_feed_service.dart`:

```dart
import 'package:finishd/services/cache/feed_cache_service.dart';

class PersonalizedFeedService {
  // ... existing code ...

  Future<List<dynamic>> getFeed(String userId) async {
    // 1. Try Cache First
    final cachedFeed = await FeedCacheService.getCachedFeed();
    if (cachedFeed != null && cachedFeed.isNotEmpty) {
      print("✅ Loaded feed from local cache");
      
      // OPTIONAL: Refresh in background if cache is old but still valid?
      // For now, we return cache immediately.
      return cachedFeed;
    }

    // 2. Fetch from Network if Cache Miss
    try {
      final freshFeed = await _apiClient.getPersonalizedFeed(userId);
      
      // 3. Save to Cache (Non-blocking)
      if (freshFeed.isNotEmpty) {
        FeedCacheService.saveFeed(freshFeed);
      }
      
      return freshFeed;
    } catch (e) {
      print("Error fetching feed: $e");
      // If network fails, maybe return cached even if expired? 
      // Current logic returns empty or throws.
      // You could add: return await FeedCacheService.getCachedFeed(ignoreTTL: true) ?? [];
      rethrow;
    }
  }
}
```

## 2. Trending Integration
Modify `lib/services/backend_trending_service.dart`:

```dart
import 'package:finishd/services/cache/trending_cache_service.dart';

class BackendTrendingService {
  // ... existing code ...

  Future<List<dynamic>> getTrendingMovies() async {
    // 1. Check Cache
    final cached = await TrendingCacheService.getTrending('movie');
    if (cached != null) return cached;

    // 2. Network Call
    final data = await _apiClient.getTrendingMovies();

    // 3. Save Cache
    TrendingCacheService.saveTrending('movie', data);
    return data;
  }
  
  Future<List<dynamic>> getTrendingTV() async {
    final cached = await TrendingCacheService.getTrending('tv');
    if (cached != null) return cached;

    final data = await _apiClient.getTrendingTV();

    TrendingCacheService.saveTrending('tv', data);
    return data;
  }
}
```

## 3. Ratings Integration
Modify `lib/services/ratings_service.dart`:

```dart
import 'package:finishd/services/cache/ratings_cache_service.dart';

class RatingsService {
  // ... 

  Future<Map<String, dynamic>> getRatings(String tmdbId) async {
    // 1. Check Cache (30 day TTL)
    final cached = await RatingsCacheService.getRatings(tmdbId);
    if (cached != null) return cached;

    // 2. Network Call
    final ratings = await _omdbApi.fetchRatings(tmdbId);

    // 3. Save Cache
    if (ratings.isNotEmpty) {
      RatingsCacheService.saveRatings(tmdbId, ratings);
    }
    return ratings;
  }
}
```

## ⚡ Improvements & Best Practices

1.  **Stale-While-Revalidate**:
    For the feed, you might want to show cached data immediately, but trigger a network refresh in the background to update the cache for next time.
    
2.  **Pagination Caching**:
    Currently `feed_cache` stores one big JSON. If you implement pagination (page 1, 2, 3), you'll need to update the schema to store individual pages or append items. The simple `json` column is best for a "Snapshot" cache.

3.  **Image Caching**:
    This SQLite system caches *data* (text/json). For images (`posterPath`), ensure you use `cached_network_image` in your UI widgets to handle image file caching effectively.

4.  **Database Migration**:
    `AppDatabase` handles version 1. If you change the schema later, increment `version: 2` and handle `onUpgrade`.

5.  **Offline Actions**:
    If a user likes a movie while offline, store that action in a local `pending_actions` table and sync with backend when online.
