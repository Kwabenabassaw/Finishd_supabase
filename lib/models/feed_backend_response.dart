/// Feed Backend Response Models
///
/// Models for the new Generator & Hydrator feed backend responses.
library;

import 'feed_item.dart';

/// Response wrapper from new feed backend
class FeedBackendResponse {
  final List<FeedItem> feed;
  final FeedBackendMeta meta;

  FeedBackendResponse({required this.feed, required this.meta});

  factory FeedBackendResponse.fromJson(Map<String, dynamic> json) {
    final feedList = json['feed'] as List? ?? [];
    return FeedBackendResponse(
      feed: feedList.map((item) => FeedItem.fromJson(item)).toList(),
      meta: FeedBackendMeta.fromJson(json['meta'] ?? {}),
    );
  }

  /// Check if there are more items to load
  bool get hasMore => meta.hasMore;

  /// Get cursor for next page
  String? get nextCursor => meta.cursor;

  /// Number of items in this response
  int get itemCount => feed.length;
}

/// Metadata from feed backend response
class FeedBackendMeta {
  final String feedType;
  final int page;
  final int limit;
  final int itemCount;
  final bool hasMore;
  final DateTime generatedAt;
  final int latencyMs;
  final String? cursor;

  FeedBackendMeta({
    required this.feedType,
    required this.page,
    required this.limit,
    required this.itemCount,
    required this.hasMore,
    required this.generatedAt,
    required this.latencyMs,
    this.cursor,
  });

  factory FeedBackendMeta.fromJson(Map<String, dynamic> json) {
    return FeedBackendMeta(
      feedType: json['feedType'] ?? 'for_you',
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      itemCount: json['itemCount'] ?? 0,
      hasMore: json['hasMore'] ?? false,
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt']) ?? DateTime.now()
          : DateTime.now(),
      latencyMs: json['latencyMs'] ?? 0,
      cursor: json['cursor'],
    );
  }
}

/// Analytics event for tracking user interactions
enum AnalyticsEventType {
  view('view'),
  like('like'),
  share('share'),
  skip('skip'),
  complete('complete');

  final String value;
  const AnalyticsEventType(this.value);
}

class AnalyticsEvent {
  final AnalyticsEventType eventType;
  final String itemId;
  final DateTime timestamp;
  final int? durationWatched;
  final Map<String, dynamic>? metadata;

  AnalyticsEvent({
    required this.eventType,
    required this.itemId,
    DateTime? timestamp,
    this.durationWatched,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'eventType': eventType.value,
    'itemId': itemId,
    'timestamp': timestamp.toIso8601String(),
    if (durationWatched != null) 'durationWatched': durationWatched,
    if (metadata != null) 'metadata': metadata,
  };
}
