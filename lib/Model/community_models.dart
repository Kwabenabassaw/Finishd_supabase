/// Data model for a show-centric community
class Community {
  final String id;
  final int showId;
  final String title;
  final String? posterPath;
  final String mediaType;
  final int memberCount;
  final int postCount;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final String? createdBy;
  final String? recentPostContent;
  final String? recentPostAuthor;
  final DateTime? recentPostTime;

  Community({
    required this.id,
    required this.showId,
    required this.title,
    this.posterPath,
    required this.mediaType,
    this.memberCount = 0,
    this.postCount = 0,
    this.lastActivityAt,
    this.createdAt,
    this.createdBy,
    this.recentPostContent,
    this.recentPostAuthor,
    this.recentPostTime,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] is int
          ? json['id'].toString()
          : (json['id'] ?? json['show_id']?.toString() ?? ''),
      showId: json['show_id'] ?? json['showId'] ?? 0,
      title: json['title'] ?? '',
      posterPath: json['poster_path'] ?? json['posterPath'],
      mediaType: json['media_type'] ?? json['mediaType'] ?? 'tv',
      memberCount: json['member_count'] ?? json['memberCount'] ?? 0,
      postCount: json['post_count'] ?? json['postCount'] ?? 0,
      lastActivityAt: json['last_activity_at'] != null
          ? DateTime.tryParse(json['last_activity_at'].toString())
          : (json['lastActivityAt'] != null
                ? DateTime.tryParse(json['lastActivityAt'].toString())
                : null),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString())
                : null),
      createdBy: json['created_by'] ?? json['createdBy'],
      // These might not be in the community doc itself, but injected later
      recentPostContent:
          json['recent_post_content'] ?? json['recentPostContent'],
      recentPostAuthor: json['recent_post_author'] ?? json['recentPostAuthor'],
      recentPostTime: json['recent_post_time'] != null
          ? DateTime.tryParse(json['recent_post_time'].toString())
          : (json['recentPostTime'] != null
                ? DateTime.tryParse(json['recentPostTime'].toString())
                : null),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'show_id': showId,
    'title': title,
    'poster_path': posterPath,
    'media_type': mediaType,
    'member_count': memberCount,
    'post_count': postCount,
    'last_activity_at': lastActivityAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'created_by': createdBy,
    'recent_post_content': recentPostContent,
    'recent_post_author': recentPostAuthor,
    'recent_post_time': recentPostTime?.toIso8601String(),
  };

  /// Create a copy with updated fields
  Community copyWith({
    String? id,
    int? showId,
    String? title,
    String? posterPath,
    String? mediaType,
    int? memberCount,
    int? postCount,
    DateTime? lastActivityAt,
    DateTime? createdAt,
    String? createdBy,
    String? recentPostContent,
    String? recentPostAuthor,
    DateTime? recentPostTime,
  }) {
    return Community(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      mediaType: mediaType ?? this.mediaType,
      memberCount: memberCount ?? this.memberCount,
      postCount: postCount ?? this.postCount,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      recentPostContent: recentPostContent ?? this.recentPostContent,
      recentPostAuthor: recentPostAuthor ?? this.recentPostAuthor,
      recentPostTime: recentPostTime ?? this.recentPostTime,
    );
  }

  /// Get full poster URL
  String? get posterUrl =>
      posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : null;

  /// Check if community has recent activity (last 7 days)
  bool get hasRecentActivity {
    if (lastActivityAt == null) return false;
    return DateTime.now().difference(lastActivityAt!).inDays <= 7;
  }
}

/// Data model for a community post
class CommunityPost {
  final String id;
  final int showId;
  final String communityId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  final List<String> hashtags;
  final bool isSpoiler;
  final bool isHidden; // Whether post is hidden/deleted
  final int score;
  final int upvotes;
  final int downvotes;
  final int commentCount;
  final DateTime? createdAt;
  final DateTime? lastActivityAt;
  final String? showTitle;

  CommunityPost({
    required this.id,
    required this.showId,
    required this.communityId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
    this.hashtags = const [],
    this.isSpoiler = false,
    this.isHidden = false,
    this.score = 0,
    this.upvotes = 0,
    this.downvotes = 0,
    this.commentCount = 0,
    this.createdAt,
    this.lastActivityAt,
    this.showTitle,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] is int ? json['id'].toString() : (json['id'] ?? ''),
      showId: json['show_id'] ?? json['showId'] ?? 0,
      communityId: json['community_id'] is int
          ? json['community_id'].toString()
          : (json['community_id'] ?? json['communityId'] ?? ''),
      authorId: json['author_id'] ?? json['authorId'] ?? '',
      authorName: json['author_name'] ?? json['authorName'] ?? 'Anonymous',
      authorAvatar: json['author_avatar'] ?? json['authorAvatar'],
      content: json['content'] ?? '',
      mediaUrls: List<String>.from(
        json['media_urls'] ?? json['mediaUrls'] ?? [],
      ),
      mediaTypes: List<String>.from(
        json['media_types'] ?? json['mediaTypes'] ?? [],
      ),
      hashtags: List<String>.from(json['hashtags'] ?? []),
      isSpoiler: json['is_spoiler'] ?? json['isSpoiler'] ?? false,
      isHidden: json['is_hidden'] ?? json['isHidden'] ?? false,
      score:
          json['score'] ?? ((json['upvotes'] ?? 0) - (json['downvotes'] ?? 0)),
      upvotes: json['upvotes'] ?? 0,
      downvotes: json['downvotes'] ?? 0,
      commentCount: json['comment_count'] ?? json['commentCount'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString())
                : null),
      lastActivityAt: json['last_activity_at'] != null
          ? DateTime.tryParse(json['last_activity_at'].toString())
          : (json['lastActivityAt'] != null
                ? DateTime.tryParse(json['lastActivityAt'].toString())
                : null),
      showTitle: json['show_title'] ?? json['showTitle'],
    );
  }

  /// Create a copy with updated fields
  CommunityPost copyWith({
    String? id,
    int? showId,
    String? communityId,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
    List<String>? hashtags,
    bool? isSpoiler,
    bool? isHidden,
    int? score,
    int? upvotes,
    int? downvotes,
    int? commentCount,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    String? showTitle,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      communityId: communityId ?? this.communityId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      hashtags: hashtags ?? this.hashtags,
      isSpoiler: isSpoiler ?? this.isSpoiler,
      isHidden: isHidden ?? this.isHidden,
      score: score ?? this.score,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      showTitle: showTitle ?? this.showTitle,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'show_id': showId,
    'community_id': communityId,
    'author_id': authorId,
    'author_name': authorName,
    'author_avatar': authorAvatar,
    'content': content,
    'media_urls': mediaUrls,
    'media_types': mediaTypes,
    'hashtags': hashtags,
    'is_spoiler': isSpoiler,
    'is_hidden': isHidden,
    'score': score,
    'upvotes': upvotes,
    'downvotes': downvotes,
    'comment_count': commentCount,
    'created_at': createdAt?.toIso8601String(),
    'last_activity_at': lastActivityAt?.toIso8601String(),
    'show_title': showTitle,
  };

  /// Time ago string for display
  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }
}

/// Data model for a comment
class CommunityComment {
  final String id;
  final String postId;
  final int showId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final String? parentId;
  final int upvotes;
  final int downvotes;
  final DateTime? createdAt;

  CommunityComment({
    required this.id,
    required this.postId,
    required this.showId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.parentId,
    this.upvotes = 0,
    this.downvotes = 0,
    this.createdAt,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'] is int ? json['id'].toString() : (json['id'] ?? ''),
      postId: json['post_id'] ?? json['postId'] ?? '',
      showId: json['show_id'] ?? json['showId'] ?? 0,
      authorId: json['author_id'] is int
          ? json['author_id'].toString()
          : (json['author_id'] ?? json['authorId'] ?? ''),
      authorName: json['author_name'] ?? json['authorName'] ?? 'Anonymous',
      authorAvatar: json['author_avatar'] ?? json['authorAvatar'],
      content: json['content'] ?? '',
      parentId: json['parent_id'] ?? json['parentId'],
      upvotes: json['upvotes'] ?? 0,
      downvotes: json['downvotes'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString())
                : null),
    );
  }

  int get score => upvotes - downvotes;
}
