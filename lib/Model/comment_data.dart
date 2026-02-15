/// Model class for storing comment data
class CommentData {
  final String id;
  final String text;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String videoId;
  final DateTime timestamp;
  final String? parentId; // For replies
  final int replyCount;

  CommentData({
    required this.id,
    required this.text,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.videoId,
    required this.timestamp,
    this.parentId,
    this.replyCount = 0,
  });

  /// Create from JSON (Supabase/Postgres)
  factory CommentData.fromJson(Map<String, dynamic> json, [String? docId]) {
    // Extract profile data from joined relation (if present)
    final profiles = json['profiles'] as Map<String, dynamic>?;
    final resolvedUserName =
        profiles?['username'] ?? json['userName'] ?? 'Anonymous';
    final resolvedUserAvatar = profiles?['avatar_url'] ?? json['userAvatar'];

    return CommentData(
      id: docId ?? json['id']?.toString() ?? '',
      text: json['content'] ?? json['text'] ?? '',
      userId: json['author_id'] ?? json['userId'] ?? '',
      userName: resolvedUserName,
      userAvatar: resolvedUserAvatar,
      videoId: json['video_id'] ?? json['videoId'] ?? '',
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['timestamp'] != null
          ? (json['timestamp'] is String
                ? DateTime.parse(json['timestamp'])
                : (json['timestamp'] as dynamic).toDate())
          : DateTime.now(),
      parentId: json['parent_id'] ?? json['parentId'],
      replyCount: json['reply_count'] ?? json['replyCount'] ?? 0,
    );
  }

  /// Convert to JSON (Supabase/Postgres)
  Map<String, dynamic> toSupabase() {
    return {
      'content': text,
      'author_id': userId,
      'video_id': videoId,
      'parent_id': parentId,
      // reply_count and created_at handled by Postgres
    };
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'videoId': videoId,
      'timestamp': timestamp,
      'parentId': parentId,
      'replyCount': replyCount,
    };
  }

  /// Copy with modifications
  CommentData copyWith({
    String? id,
    String? text,
    String? userId,
    String? userName,
    String? userAvatar,
    String? videoId,
    DateTime? timestamp,
    String? parentId,
    int? replyCount,
  }) {
    return CommentData(
      id: id ?? this.id,
      text: text ?? this.text,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      videoId: videoId ?? this.videoId,
      timestamp: timestamp ?? this.timestamp,
      parentId: parentId ?? this.parentId,
      replyCount: replyCount ?? this.replyCount,
    );
  }

  /// Format timestamp as relative time
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }
}
