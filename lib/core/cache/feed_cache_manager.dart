import 'dart:convert';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages feed JSON caching and Flutter ImageCache limits.
///
/// MEMORY CONTRACT:
///   - Flutter ImageCache capped at 50 images / 50MB
///   - Feed JSON cached in SharedPreferences with 30-minute TTL
///   - Max 100 cache entries
class FeedCacheManager {
  static const _maxAge = Duration(minutes: 30);
  static const _maxEntries = 100;

  SharedPreferences? _prefs;

  /// Initialize the cache manager. Call once at app startup.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    configureImageCache();
  }

  /// CRITICAL: Flutter's default image cache is unlimited.
  /// On low-end Android devices, thumbnail images will OOM without this.
  void configureImageCache() {
    PaintingBinding.instance.imageCache.maximumSize = 50; // max 50 images
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        50 * 1024 * 1024; // 50MB
  }

  /// Cache a feed response as JSON.
  Future<void> cacheFeed(String key, List<Map<String, dynamic>> items) async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final json = jsonEncode(items);
      await prefs.setString('feed_${key}_data', json);
      await prefs.setInt(
        'feed_${key}_ts',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Enforce max entries by cleaning old keys
      await _pruneOldEntries(prefs);
    } catch (e) {
      // Silently fail — cache is a speed layer, not critical
    }
  }

  /// Retrieve cached feed data. Returns null if stale or missing.
  List<Map<String, dynamic>>? getCachedFeed(String key) {
    final prefs = _prefs;
    if (prefs == null) return null;

    final ts = prefs.getInt('feed_${key}_ts');
    if (ts == null) return null;

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    if (DateTime.now().difference(cachedAt) > _maxAge) {
      // Stale — remove
      prefs.remove('feed_${key}_data');
      prefs.remove('feed_${key}_ts');
      return null;
    }

    final json = prefs.getString('feed_${key}_data');
    if (json == null) return null;

    try {
      final decoded = jsonDecode(json) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Clear all feed cache and image cache.
  Future<void> clearAll() async {
    final prefs = _prefs;
    if (prefs != null) {
      final feedKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('feed_'))
          .toList();
      for (final k in feedKeys) {
        await prefs.remove(k);
      }
    }

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  Future<void> _pruneOldEntries(SharedPreferences prefs) async {
    final feedKeys = prefs
        .getKeys()
        .where((k) => k.startsWith('feed_') && k.endsWith('_ts'))
        .toList();

    if (feedKeys.length <= _maxEntries) return;

    // Sort by timestamp ascending (oldest first)
    feedKeys.sort((a, b) {
      final tsA = prefs.getInt(a) ?? 0;
      final tsB = prefs.getInt(b) ?? 0;
      return tsA.compareTo(tsB);
    });

    // Remove oldest entries
    final toRemove = feedKeys.take(feedKeys.length - _maxEntries).toList();
    for (final tsKey in toRemove) {
      final dataKey = tsKey.replaceAll('_ts', '_data');
      await prefs.remove(tsKey);
      await prefs.remove(dataKey);
    }
  }
}
