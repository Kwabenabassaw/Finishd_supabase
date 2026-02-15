import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Service to handle video caching and preloading.
///
/// Uses a custom [CacheManager] with:
///  - `stalePeriod` of 50 minutes (signed URLs expire at 60 min)
///  - `maxNrOfCacheObjects` capped at 20 to prevent disk bloat
class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();

  factory VideoCacheService() => _instance;

  VideoCacheService._internal();

  /// Custom cache manager tuned for video files
  final BaseCacheManager _cacheManager = CacheManager(
    Config(
      'videoCacheData',
      stalePeriod: const Duration(minutes: 50), // < signed URL TTL (60m)
      maxNrOfCacheObjects: 20,
    ),
  );

  /// Get a file from cache, or download it.
  /// Returns `null` on failure so the caller can fall back to network streaming.
  Future<File?> getSingleFile(String url) async {
    if (url.isEmpty) return null;
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo != null) return fileInfo.file;
      return await _cacheManager.getSingleFile(url);
    } catch (e) {
      // Network error, bad URL, etc.  Caller will fall back to streaming.
      print('[VideoCacheService] ❌ Cache miss / error for $url: $e');
      return null;
    }
  }

  /// Check cache only — returns the file if cached, null otherwise.
  /// Does NOT download. Used for instant cache checks during playback.
  Future<File?> getCachedFileOnly(String url) async {
    if (url.isEmpty) return null;
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      return fileInfo?.file;
    } catch (e) {
      return null;
    }
  }

  /// Preload a video into cache (fire-and-forget).
  void preload(String url) {
    if (url.isEmpty) return;
    _cacheManager
        .downloadFile(url)
        .then(
          (_) => print(
            '[VideoCacheService] ✅ Preloaded: ${url.substring(0, url.length.clamp(0, 60))}…',
          ),
        )
        .catchError((e) => print('[VideoCacheService] ❌ Preload failed: $e'));
  }

  /// Check if a video is already cached.
  Future<bool> isCached(String url) async {
    final fileInfo = await _cacheManager.getFileFromCache(url);
    return fileInfo != null;
  }
}
