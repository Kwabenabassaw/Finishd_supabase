import 'package:cloud_firestore/cloud_firestore.dart';

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
      id: json['id'] ?? json['showId']?.toString() ?? '',
      showId: json['showId'] ?? 0,
      title: json['title'] ?? '',
      posterPath: json['posterPath'],
      mediaType: json['mediaType'] ?? 'tv',
      memberCount: json['memberCount'] ?? 0,
      postCount: json['postCount'] ?? 0,
      lastActivityAt: json['lastActivityAt'] is Timestamp
          ? (json['lastActivityAt'] as Timestamp).toDate()
          : null,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      createdBy: json['createdBy'],
      // These might not be in the community doc itself, but injected later
      recentPostContent: json['recentPostContent'],
      recentPostAuthor: json['recentPostAuthor'],
      recentPostTime: json['recentPostTime'] is Timestamp
          ? (json['recentPostTime'] as Timestamp).toDate()
          : json['recentPostTime'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'showId': showId,
    'title': title,
    'posterPath': posterPath,
    'mediaType': mediaType,
    'memberCount': memberCount,
    'postCount': postCount,
    'lastActivityAt': lastActivityAt,
    'createdAt': createdAt,
    'createdBy': createdBy,
    'recentPostContent': recentPostContent,
    'recentPostAuthor': recentPostAuthor,
    'recentPostTime': recentPostTime,
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
      id: json['id'] ?? '',
      showId: json['showId'] ?? 0,
      communityId: json['communityId'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? 'Anonymous',
      authorAvatar: json['authorAvatar'],
      content: json['content'] ?? '',
      mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(json['mediaTypes'] ?? []),
      hashtags: List<String>.from(json['hashtags'] ?? []),
      isSpoiler: json['isSpoiler'] ?? false,
      isHidden: json['isHidden'] ?? false,
      score:
          json['score'] ?? ((json['upvotes'] ?? 0) - (json['downvotes'] ?? 0)),
      upvotes: json['upvotes'] ?? 0,
      downvotes: json['downvotes'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      lastActivityAt: json['lastActivityAt'] is Timestamp
          ? (json['lastActivityAt'] as Timestamp).toDate()
          : null,
      showTitle: json['showTitle'],
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
    'showId': showId,
    'communityId': communityId,
    'authorId': authorId,
    'authorName': authorName,
    'authorAvatar': authorAvatar,
    'content': content,
    'mediaUrls': mediaUrls,
    'mediaTypes': mediaTypes,
    'hashtags': hashtags,
    'isSpoiler': isSpoiler,
    'isHidden': isHidden,
    'score': score,
    'upvotes': upvotes,
    'downvotes': downvotes,
    'commentCount': commentCount,
    'createdAt': createdAt,
    'lastActivityAt': lastActivityAt,
    'showTitle': showTitle,
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
      id: json['id'] ?? '',
      postId: json['postId'] ?? '',
      showId: json['showId'] ?? 0,
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? 'Anonymous',
      authorAvatar: json['authorAvatar'],
      content: json['content'] ?? '',
      parentId: json['parentId'],
      upvotes: json['upvotes'] ?? 0,
      downvotes: json['downvotes'] ?? 0,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  int get score => upvotes - downvotes;
}
