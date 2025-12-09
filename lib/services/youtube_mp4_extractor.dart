import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart';

/// Holds URLs for different quality streams
class StreamManifestUrls {
  final String lowQualityUrl;   // 144p for instant start
  final String highQualityUrl;  // 360p max for smooth playback

  StreamManifestUrls({
    required this.lowQualityUrl,
    required this.highQualityUrl,
  });
}

/// Service to extract direct MP4 URLs from YouTube videos
/// 
/// Strategy:
/// - LQ (144p): For instant start when scrolling fast
/// - HQ (360p max): For smooth playback, saves bandwidth
class YouTubeMp4Extractor {
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, _CachedUrl> _cache = {};

  /// Extract both 144p and 360p MP4 URLs
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

      // Sort by size (proxy for quality, smallest first)
      muxedStreams.sort(
        (a, b) => a.size.totalBytes.compareTo(b.size.totalBytes),
      );

      // === LOW QUALITY (144p for INSTANT START) ===
      // Try to find 144p specifically, else use smallest available
      var lowQualityStream = muxedStreams.first;
      
      final preferred144 = muxedStreams
          .where((s) => s.qualityLabel.contains('144'))
          .toList();
      if (preferred144.isNotEmpty) {
        lowQualityStream = preferred144.first;
      }

      // === HIGH QUALITY (360p MAX for smooth playback) ===
      // User specified: DO NOT go higher than 360p
      var highQualityStream = lowQualityStream; // Default to same as low
      
      // Try to find 360p specifically
      final preferred360 = muxedStreams
          .where((s) => s.qualityLabel.contains('360'))
          .toList();
      final preferred240 = muxedStreams
          .where((s) => s.qualityLabel.contains('240'))
          .toList();
      
      if (preferred360.isNotEmpty) {
        // Found 360p - use it as high quality
        highQualityStream = preferred360.first;
      } else if (preferred240.isNotEmpty) {
        // No 360p, use 240p
        highQualityStream = preferred240.first;
      } else {
        // Use second smallest if available (step up from 144p)
        if (muxedStreams.length > 1) {
          highQualityStream = muxedStreams[1];
        }
      }

      final urls = StreamManifestUrls(
        lowQualityUrl: lowQualityStream.url.toString(),
        highQualityUrl: highQualityStream.url.toString(),
      );

      // Cache the result
      _cache[videoId] = _CachedUrl(urls: urls, timestamp: DateTime.now());

      debugPrint(
        '[MP4Extractor] ✅ Extracted 144p(${lowQualityStream.qualityLabel}) → 360p(${highQualityStream.qualityLabel}) for $videoId',
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
