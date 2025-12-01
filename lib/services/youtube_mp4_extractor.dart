import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart';

/// Holds URLs for different quality streams
class StreamManifestUrls {
  final String lowQualityUrl;
  final String highQualityUrl;

  StreamManifestUrls({
    required this.lowQualityUrl,
    required this.highQualityUrl,
  });
}

/// Service to extract direct MP4 URLs from YouTube videos
class YouTubeMp4Extractor {
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, _CachedUrl> _cache = {};

  /// Extract both Low and High quality MP4 URLs
  Future<StreamManifestUrls?> getStreamUrls(String videoId) async {
    try {
      // Check cache first
      if (_cache.containsKey(videoId)) {
        final cached = _cache[videoId]!;
        if (DateTime.now().difference(cached.timestamp).inHours < 5) {
          debugPrint('[MP4Extractor] ✅ Cache hit for $videoId');
          return cached.urls;
        } else {
          _cache.remove(videoId);
        }
      }

      debugPrint('[MP4Extractor] 🔍 Extracting streams for $videoId');

      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final muxedStreams = manifest.muxed.toList();

      if (muxedStreams.isEmpty) {
        debugPrint('[MP4Extractor] ❌ No muxed streams found for $videoId');
        return null;
      }

      // Sort by size (proxy for quality)
      muxedStreams.sort(
        (a, b) => a.size.totalBytes.compareTo(b.size.totalBytes),
      );

      // 1. Low Quality (Fastest start)
      // Pick the smallest available stream (usually 144p or 240p)
      final lowQualityStream = muxedStreams.first;

      // 2. High Quality (Best viewing)
      // Pick 480p or 360p (optimal for mobile vertical feed)
      // Avoid 720p/1080p if possible to save bandwidth/memory unless requested,
      // but user asked for "HQ". Let's try to find 480p, else highest available.
      var highQualityStream = muxedStreams.last; // Default to highest

      // Try to find specific optimal qualities
      final preferred480 = muxedStreams
          .where((s) => s.qualityLabel.contains('480'))
          .toList();
      final preferred360 = muxedStreams
          .where((s) => s.qualityLabel.contains('360'))
          .toList();

      if (preferred480.isNotEmpty) {
        highQualityStream = preferred480.last;
      } else if (preferred360.isNotEmpty) {
        highQualityStream = preferred360.last;
      }

      final urls = StreamManifestUrls(
        lowQualityUrl: lowQualityStream.url.toString(),
        highQualityUrl: highQualityStream.url.toString(),
      );

      // Cache the result
      _cache[videoId] = _CachedUrl(urls: urls, timestamp: DateTime.now());

      debugPrint(
        '[MP4Extractor] ✅ Extracted LQ(${lowQualityStream.qualityLabel}) & HQ(${highQualityStream.qualityLabel}) for $videoId',
      );

      return urls;
    } catch (e) {
      debugPrint('[MP4Extractor] ❌ Failed to extract $videoId: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _yt.close();
    _cache.clear();
  }
}

/// Internal class to cache URLs with timestamps
class _CachedUrl {
  final StreamManifestUrls urls;
  final DateTime timestamp;

  _CachedUrl({required this.urls, required this.timestamp});
}
