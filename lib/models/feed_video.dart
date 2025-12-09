import 'package:finishd/models/feed_item.dart';

class FeedVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String channelName;
  final String description;
  final String? recommendationReason; // e.g., "Kobby is watching"
  final String? relatedItemId; // e.g., Movie ID or Friend UID
  final String? relatedItemType; // e.g., "friend", "trending", "movie"

  FeedVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.channelName,
    this.description = '',
    this.recommendationReason,
    this.relatedItemId,
    this.relatedItemType,
  });

  /// Factory to create from FeedItem
  factory FeedVideo.fromFeedItem(FeedItem item) {
    return FeedVideo(
      videoId: item.youtubeKey ?? '',
      title: item.videoName ?? item.title,
      thumbnailUrl: item.bestThumbnailUrl,
      channelName: item.channelTitle ?? '',
      description: item.description ?? item.overview ?? '',
      recommendationReason: item.reason,
      relatedItemId: item.tmdbId?.toString() ?? item.relatedTmdbId?.toString(),
      relatedItemType: item.relatedType ?? item.mediaType,
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
    );
  }
}
