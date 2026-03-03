import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton LRU-style URL cache for creator video storage paths.
///
/// Resolves Supabase storage paths → absolute HTTP URLs once, then serves
/// from an in-memory map. Prevents every video widget from issuing its own
/// signed-URL request on init.
class CreatorUrlCache {
  CreatorUrlCache._internal();
  static final CreatorUrlCache _instance = CreatorUrlCache._internal();
  static CreatorUrlCache get instance => _instance;

  static const int _maxEntries = 60;
  static const int _signedUrlTtlSeconds = 3600; // 1 hour

  final Map<String, String> _cache = {};

  /// Resolves [pathOrUrl] to an absolute HTTP URL.
  ///
  /// - If it already starts with 'http', returns it unchanged.
  /// - If cached, returns the cached value immediately (synchronous).
  /// - Otherwise fetches a signed URL from Supabase Storage.
  Future<String> resolve(
    String pathOrUrl, {
    String bucket = 'creator-videos',
  }) async {
    if (pathOrUrl.startsWith('http')) return pathOrUrl;

    final cacheKey = '$bucket/$pathOrUrl';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final signedUrl = await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(pathOrUrl, _signedUrlTtlSeconds);
      _store(cacheKey, signedUrl);
      return signedUrl;
    } catch (e) {
      debugPrint(
        '[CreatorUrlCache] Signed URL failed for $pathOrUrl: $e. Falling back to public URL.',
      );
      final publicUrl = Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(pathOrUrl);
      _store(cacheKey, publicUrl);
      return publicUrl;
    }
  }

  /// Resolves a thumbnail URL (uses the creator-thumbnails bucket).
  Future<String> resolveThumbnail(String pathOrUrl) async {
    return resolve(pathOrUrl, bucket: 'creator-thumbnails');
  }

  /// Pre-warms the cache for [pathOrUrl] without awaiting the result.
  void prefetch(String pathOrUrl, {String bucket = 'creator-videos'}) {
    if (pathOrUrl.isEmpty || pathOrUrl.startsWith('http')) return;
    final cacheKey = '$bucket/$pathOrUrl';
    if (_cache.containsKey(cacheKey)) return;
    resolve(pathOrUrl, bucket: bucket); // fire-and-forget
  }

  void _store(String key, String url) {
    if (_cache.length >= _maxEntries) {
      // Evict the oldest entry (first key in insertion-order map)
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = url;
  }

  /// Clears the cache (e.g., on session logout).
  void clear() => _cache.clear();
}
