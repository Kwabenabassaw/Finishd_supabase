import 'package:objectbox/objectbox.dart';

/// Cached feed item - Unified schema matching Content Lake backend.
///
/// This is the LOCAL source of truth for feed content.
/// UI reads directly from ObjectBox - NEVER waits for network.
@Entity()
class CachedFeedItem {
  @Id()
  int localId = 0;

  /// Unique identifier from backend (e.g., "kinocheck_trending_movie_550")
  String id;

  /// Content type: "MEDIA_LINKED" (TMDB matched) or "VIDEO_ONLY" (YouTube only)
  String? type;

  // =========================================================================
  // Content Metadata (from TMDB)
  // =========================================================================

  int? tmdbId;
  String? mediaType; // "movie" or "tv"
  String title;
  String? overview;

  /// Full poster URL (e.g., "https://image.tmdb.org/t/p/w500/xxx.jpg")
  String? poster;

  /// Full backdrop URL
  String? backdrop;

  String? releaseDate;
  double? popularity;
  double? voteAverage;

  // =========================================================================
  // Fallback Metadata (for VIDEO_ONLY)
  // =========================================================================

  String? fallbackThumbnail;
  String? fallbackChannel;

  // =========================================================================
  // Video Info
  // =========================================================================

  String? youtubeKey;
  String? videoType; // "trailer", "bts", "interview"

  // =========================================================================
  // Feed Metadata
  // =========================================================================

  /// Source of the video (e.g., "kinocheck_trending", "kinocheck_latest", "youtube")
  String source;

  /// Feed type this item belongs to (e.g., "trending", "latest", "for_you")
  String feedType;

  /// Position in current feed (for ordering)
  int position;

  /// Version string from pointer (for cache invalidation)
  String version;

  @Property(type: PropertyType.date)
  DateTime cachedAt;

  // =========================================================================
  // Genres (stored as comma-separated string)
  // =========================================================================

  String? genresJson;

  CachedFeedItem({
    required this.id,
    this.type,
    this.tmdbId,
    this.mediaType,
    required this.title,
    this.overview,
    this.poster,
    this.backdrop,
    this.releaseDate,
    this.popularity,
    this.voteAverage,
    this.fallbackThumbnail,
    this.fallbackChannel,
    this.youtubeKey,
    this.videoType,
    required this.source,
    required this.feedType,
    required this.position,
    required this.version,
    required this.cachedAt,
    this.genresJson,
  });

  /// Get genres as list.
  List<String> get genres {
    if (genresJson == null || genresJson!.isEmpty) return [];
    return genresJson!.split(',');
  }

  /// Set genres from list.
  set genres(List<String> value) {
    genresJson = value.join(',');
  }

  /// Convert to Map for debugging/logging.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tmdbId': tmdbId,
      'title': title,
      'mediaType': mediaType,
      'youtubeKey': youtubeKey,
      'feedType': feedType,
      'position': position,
    };
  }
}

/// Feed pointer - Tracks current version per feed type.
///
/// Client polls API for pointer, compares version, fetches new batch if changed.
@Entity()
class FeedPointer {
  @Id()
  int localId = 0;

  @Unique()
  String feedType; // "trending", "latest", "for_you"

  /// Version string from backend (timestamp-based)
  String version;

  int itemCount;

  @Property(type: PropertyType.date)
  DateTime checkedAt;

  /// When this pointer expires (from backend)
  @Property(type: PropertyType.date)
  DateTime? expiresAt;

  FeedPointer({
    required this.feedType,
    required this.version,
    required this.itemCount,
    required this.checkedAt,
    this.expiresAt,
  });

  /// Check if this pointer is expired.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

/// Tracks seen/suppressed items (local only).
///
/// Used for:
/// - Marking items as seen (for analytics)
/// - Suppressing items user dismissed (don't show again)
@Entity()
class SeenItem {
  @Id()
  int localId = 0;

  @Unique()
  String itemId;

  @Property(type: PropertyType.date)
  DateTime seenAt;

  @Property(type: PropertyType.date)
  DateTime lastSeenAt;

  /// Total watch time in milliseconds.
  int viewDurationMs;

  /// User liked this item.
  bool liked;

  /// User explicitly dismissed this item.
  bool suppressed;

  SeenItem({
    required this.itemId,
    required this.seenAt,
    required this.lastSeenAt,
    this.viewDurationMs = 0,
    this.liked = false,
    this.suppressed = false,
  });
}

/// Persistent metadata for a feed item (not cleared on feed batch updates).
@Entity()
class FeedItemMeta {
  @Id()
  int localId = 0;

  @Unique()
  String id;

  @Property(type: PropertyType.date)
  DateTime publishedAt;

  /// Base score assigned during ingestion (0.0 to 1.0).
  double baseScore;

  FeedItemMeta({
    required this.id,
    required this.publishedAt,
    this.baseScore = 0.5,
  });
}
