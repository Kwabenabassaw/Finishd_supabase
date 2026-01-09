import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/models/feed_item.dart';
import 'package:finishd/db/objectbox/feed_entities.dart';

class FeedVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String channelName;
  final String description;
  final String? recommendationReason; // e.g., "Kobby is watching"
  final String? relatedItemId; // e.g., Movie ID or Friend UID
  final String? relatedItemType; // e.g., "friend", "trending", "movie"
  final String?
  feedType; // 'trending', 'following', 'for_you' - indicates where content is from
  final String? type; // 'MEDIA_LINKED' or 'VIDEO_ONLY'
  final String? videoType; // 'trailer', 'bts', 'short', 'interview'
  final Map<String, dynamic>? tmdb; // {id, mediaType, confidence}
  final Map<String, dynamic>? fallback; // {thumbnail, channel}
  final Map<String, dynamic>? availability;
  final DateTime? lastEnriched;

  FeedVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.channelName,
    this.description = '',
    this.recommendationReason,
    this.relatedItemId,
    this.relatedItemType,
    this.feedType,
    this.type,
    this.videoType,
    this.tmdb,
    this.fallback,
    this.availability,
    this.lastEnriched,
  });

  /// Factory to create from CachedFeedItem (ObjectBox)
  factory FeedVideo.fromCachedFeedItem(CachedFeedItem item) {
    return FeedVideo(
      videoId: item.youtubeKey ?? '',
      title: item.title,
      thumbnailUrl: item.poster ?? item.fallbackThumbnail ?? '',
      channelName: item.fallbackChannel ?? '',
      description: item.overview ?? '',
      recommendationReason: null, // Populated by provider
      relatedItemId: item.tmdbId?.toString(),
      relatedItemType: item.mediaType,
      feedType: item.feedType,
      type: item.type,
      videoType: item.videoType,
      tmdb: item.tmdbId != null
          ? {'id': item.tmdbId, 'mediaType': item.mediaType}
          : null,
      fallback: {
        'thumbnail': item.fallbackThumbnail,
        'channel': item.fallbackChannel,
      },
    );
  }

  /// Factory to create from FeedItem (Legacy compat)
  factory FeedVideo.fromFeedItem(FeedItem item) {
    return FeedVideo(
      videoId: item.youtubeKey ?? '',
      title: item.videoName ?? item.title,
      thumbnailUrl: item.bestThumbnailUrl,
      channelName: item.channelTitle ?? '',
      description: item.description ?? item.overview ?? '',
      recommendationReason: item.reason,
      relatedItemId: item.tmdbId?.toString() ?? item.relatedTmdbId?.toString(),
      relatedItemType: item.mediaType,
      feedType: item.feedType,
    );
  }

  /// Factory to create from YouTube API JSON
  factory FeedVideo.fromJson(Map<String, dynamic> json) {
    // Handle both direct API response and Firestore cached data
    if (json.containsKey('snippet')) {
      // YouTube API structure
      final snippet = json['snippet'];
      final idData = json['id'];
      final videoId = idData is Map
          ? (idData['videoId'] ?? '')
          : (idData ?? '');

      return FeedVideo(
        videoId: videoId,
        title: snippet['title'] ?? '',
        thumbnailUrl: snippet['thumbnails']?['high']?['url'] ?? '',
        channelName: snippet['channelTitle'] ?? '',
        description: snippet['description'] ?? '',
        // These will be populated manually after fetching from YouTube
        recommendationReason: null,
        relatedItemId: null,
        relatedItemType: null,
        feedType: null,
      );
    } else {
      // Firestore/Local structure
      return FeedVideo(
        videoId: json['videoId'] ?? '',
        title: json['title'] ?? '',
        thumbnailUrl: json['thumbnailUrl'] ?? '',
        channelName: json['channelName'] ?? '',
        description: json['description'] ?? '',
        recommendationReason: json['recommendationReason'],
        relatedItemId: json['relatedItemId'],
        relatedItemType: json['relatedItemType'],
        feedType: json['feedType'],
        availability: json['availability'] as Map<String, dynamic>?,
        lastEnriched: json['lastEnriched'] != null
            ? (json['lastEnriched'] is Timestamp
                  ? (json['lastEnriched'] as Timestamp).toDate()
                  : DateTime.parse(json['lastEnriched']))
            : null,
      );
    }
  }

  /// Convert to JSON for Firestore caching
  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'channelName': channelName,
      'description': description,
      'recommendationReason': recommendationReason,
      'relatedItemId': relatedItemId,
      'relatedItemType': relatedItemType,
      'feedType': feedType,
      'type': type,
      'tmdb': tmdb,
      'fallback': fallback,
      'availability': availability,
      'lastEnriched': lastEnriched?.toIso8601String(),
    };
  }

  FeedVideo copyWith({
    String? videoId,
    String? title,
    String? thumbnailUrl,
    String? channelName,
    String? description,
    String? recommendationReason,
    String? relatedItemId,
    String? relatedItemType,
    String? feedType,
    Map<String, dynamic>? availability, // FIX Bug #4: Add missing parameter
    DateTime? lastEnriched, // FIX Bug #4: Add missing parameter
  }) {
    return FeedVideo(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channelName: channelName ?? this.channelName,
      description: description ?? this.description,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      relatedItemId: relatedItemId ?? this.relatedItemId,
      relatedItemType: relatedItemType ?? this.relatedItemType,
      feedType: feedType ?? this.feedType,
      availability: availability ?? this.availability,
      lastEnriched: lastEnriched ?? this.lastEnriched,
    );
  }
}
