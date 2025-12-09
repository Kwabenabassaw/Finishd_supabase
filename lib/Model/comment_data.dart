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

  /// Create from Firestore document
  factory CommentData.fromJson(Map<String, dynamic> json, String docId) {
    return CommentData(
      id: docId,
      text: json['text'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Anonymous',
      userAvatar: json['userAvatar'],
      videoId: json['videoId'] ?? '',
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] as dynamic).toDate()
          : DateTime.now(),
      parentId: json['parentId'],
      replyCount: json['replyCount'] ?? 0,
    );
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
