class CreatorVideo {
  final String id;
  final String creatorId;
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final String description;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime createdAt;
  final double engagementScore; // Required for cursor-based pagination

  // TMDB linking
  final int? tmdbId;
  final String? tmdbType; // 'movie' or 'tv'
  final String? tmdbTitle;

  // Video metadata
  final int durationSeconds;
  final bool spoiler;
  final List<String> tags;

  // Feed source — how this video was selected for the feed
  final String? feedSource; // 'personalized','trending','social','explore'

  // Joined from profiles
  final String creatorName;
  final String creatorAvatarUrl;

  CreatorVideo({
    required this.id,
    required this.creatorId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.description,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    this.shareCount = 0,
    required this.createdAt,
    required this.engagementScore,
    required this.creatorName,
    required this.creatorAvatarUrl,
    this.tmdbId,
    this.tmdbType,
    this.tmdbTitle,
    this.durationSeconds = 0,
    this.spoiler = false,
    this.tags = const [],
    this.feedSource,
  });

  /// Duration in milliseconds (for the interaction tracker).
  int get durationMs => durationSeconds * 1000;

  factory CreatorVideo.fromJson(Map<String, dynamic> json) {
    return CreatorVideo(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      engagementScore: (json['engagement_score'] as num?)?.toDouble() ?? 0.0,
      creatorName: json['profiles']?['username'] ?? 'Unknown Creator',
      creatorAvatarUrl: json['profiles']?['avatar_url'] ?? '',
      tmdbId: json['tmdb_id'] as int?,
      tmdbType: json['tmdb_type'] as String?,
      tmdbTitle: json['tmdb_title'] as String?,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      spoiler: json['spoiler'] as bool? ?? false,
      tags:
          (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ??
          const [],
      feedSource: json['feed_source'] as String?,
    );
  }

  /// Factory for RPC responses that flatten the profile join.
  factory CreatorVideo.fromRpcJson(Map<String, dynamic> json) {
    return CreatorVideo(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      engagementScore: (json['engagement_score'] as num?)?.toDouble() ?? 0.0,
      creatorName: json['creator_username'] ?? 'Unknown Creator',
      creatorAvatarUrl: json['creator_avatar_url'] ?? '',
      tmdbId: json['tmdb_id'] as int?,
      tmdbType: json['tmdb_type'] as String?,
      tmdbTitle: json['tmdb_title'] as String?,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      spoiler: json['spoiler'] as bool? ?? false,
      tags:
          (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ??
          const [],
      feedSource: json['feed_source'] as String?,
    );
  }
}
