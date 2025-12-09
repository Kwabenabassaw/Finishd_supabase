import 'package:flutter/foundation.dart';

/// Represents a single item in the personalized feed.
/// 
/// Can be:
/// - TMDB content (trailers, teasers, clips)
/// - YouTube BTS/Interview content (cached globally)
class FeedItem {
  final String id;
  final String type; // trailer, bts, interview, teaser, clip, featurette
  final String source; // tmdb, youtube_cached
  
  // Content info
  final int? tmdbId;
  final String? mediaType; // movie, tv
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  
  // Video info
  final String? youtubeKey;
  final String? videoName;
  final String? videoType;
  final String? thumbnailUrl;
  
  // Metadata
  final String? releaseDate;
  final double? voteAverage;
  final double? popularity;
  final double? score;
  final String? reason;
  
  // BTS-specific fields
  final String? relatedTitle;
  final int? relatedTmdbId;
  final String? relatedType;
  final String? channelTitle;
  final String? description;

  FeedItem({
    required this.id,
    required this.type,
    required this.source,
    this.tmdbId,
    this.mediaType,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.youtubeKey,
    this.videoName,
    this.videoType,
    this.thumbnailUrl,
    this.releaseDate,
    this.voteAverage,
    this.popularity,
    this.score,
    this.reason,
    this.relatedTitle,
    this.relatedTmdbId,
    this.relatedType,
    this.channelTitle,
    this.description,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'trailer',
      source: json['source'] ?? 'tmdb',
      tmdbId: json['tmdbId'],
      mediaType: json['mediaType'],
      title: json['title'] ?? '',
      overview: json['overview'],
      posterPath: json['posterPath'],
      backdropPath: json['backdropPath'],
      youtubeKey: json['youtubeKey'],
      videoName: json['videoName'],
      videoType: json['videoType'],
      thumbnailUrl: json['thumbnailUrl'],
      releaseDate: json['releaseDate'],
      voteAverage: (json['voteAverage'] as num?)?.toDouble(),
      popularity: (json['popularity'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble(),
      reason: json['reason'],
      relatedTitle: json['relatedTitle'],
      relatedTmdbId: json['relatedTmdbId'],
      relatedType: json['relatedType'],
      channelTitle: json['channelTitle'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'source': source,
      'tmdbId': tmdbId,
      'mediaType': mediaType,
      'title': title,
      'overview': overview,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'youtubeKey': youtubeKey,
      'videoName': videoName,
      'videoType': videoType,
      'thumbnailUrl': thumbnailUrl,
      'releaseDate': releaseDate,
      'voteAverage': voteAverage,
      'popularity': popularity,
      'score': score,
      'reason': reason,
      'relatedTitle': relatedTitle,
      'relatedTmdbId': relatedTmdbId,
      'relatedType': relatedType,
      'channelTitle': channelTitle,
      'description': description,
    };
  }

  // =========================================================================
  // HELPER METHODS
  // =========================================================================

  /// Check if this is TMDB content
  bool get isTMDB => source == 'tmdb';

  /// Check if this is cached YouTube BTS content
  bool get isBTS => source == 'youtube_cached' && type == 'bts';

  /// Check if this is an interview
  bool get isInterview => type == 'interview';

  /// Check if this is a trailer
  bool get isTrailer => type == 'trailer' || type == 'teaser';

  /// Check if this item has a YouTube video
  bool get hasYouTubeVideo => youtubeKey != null && youtubeKey!.isNotEmpty;

  /// Get the YouTube URL for this item
  String? get youtubeUrl => hasYouTubeVideo 
      ? 'https://www.youtube.com/watch?v=$youtubeKey' 
      : null;

  /// Get the YouTube embed URL
  String? get youtubeEmbedUrl => hasYouTubeVideo 
      ? 'https://www.youtube.com/embed/$youtubeKey' 
      : null;

  /// Get the poster URL (full TMDB URL)
  String? get fullPosterUrl => posterPath != null 
      ? 'https://image.tmdb.org/t/p/w500$posterPath' 
      : null;

  /// Get the backdrop URL (full TMDB URL)
  String? get fullBackdropUrl => backdropPath != null 
      ? 'https://image.tmdb.org/t/p/w780$backdropPath' 
      : null;

  /// Get the best thumbnail URL (prefers TMDB backdrop, falls back to YouTube)
  String get bestThumbnailUrl {
    if (backdropPath != null) {
      return 'https://image.tmdb.org/t/p/w780$backdropPath';
    }
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl!;
    }
    if (youtubeKey != null) {
      return 'https://img.youtube.com/vi/$youtubeKey/hqdefault.jpg';
    }
    return '';
  }

  /// Get a display label for the content type
  String get typeLabel {
    switch (type) {
      case 'trailer':
        return 'Trailer';
      case 'teaser':
        return 'Teaser';
      case 'bts':
        return 'Behind the Scenes';
      case 'interview':
        return 'Interview';
      case 'clip':
        return 'Clip';
      case 'featurette':
        return 'Featurette';
      default:
        return 'Video';
    }
  }

  /// Get display text for the reason/recommendation
  String get displayReason => reason ?? 'Recommended for you';

  @override
  String toString() {
    return 'FeedItem(id: $id, type: $type, source: $source, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
