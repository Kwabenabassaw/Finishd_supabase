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
  final DateTime createdAt;
  final double engagementScore; // Required for cursor-based pagination

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
    required this.createdAt,
    required this.engagementScore,
    required this.creatorName,
    required this.creatorAvatarUrl,
  });

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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      engagementScore: (json['engagement_score'] as num?)?.toDouble() ?? 0.0,
      creatorName: json['profiles']?['username'] ?? 'Unknown Creator',
      creatorAvatarUrl: json['profiles']?['avatar_url'] ?? '',
    );
  }
}
