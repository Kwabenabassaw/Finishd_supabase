/// Model class for storing reaction data
class ReactionData {
  final String type; // "heart", "laugh", "wow", "sad", "angry"
  final String emoji; // "❤️", "😂", "😮", "😢", "😡"
  final DateTime timestamp;
  final String userId;
  final String videoId; // YouTube video ID

  ReactionData({
    required this.type,
    required this.emoji,
    required this.timestamp,
    required this.userId,
    required this.videoId,
  });

  /// Create from Firestore document
  factory ReactionData.fromJson(Map<String, dynamic> json, String odcId) {
    return ReactionData(
      type: json['type'] ?? 'heart',
      emoji: json['emoji'] ?? '❤️',
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] as dynamic).toDate()
          : DateTime.now(),
      userId: json['userId'] ?? '',
      videoId: json['videoId'] ?? '',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'emoji': emoji,
      'timestamp': timestamp,
      'userId': userId,
      'videoId': videoId,
    };
  }

  /// Emoji mapping
  static const Map<String, String> typeToEmoji = {
    'heart': '❤️',
    'laugh': '😂',
    'wow': '😮',
    'sad': '😢',
    'angry': '😡',
  };

  static const Map<String, String> emojiToType = {
    '❤️': 'heart',
    '😂': 'laugh',
    '😮': 'wow',
    '😢': 'sad',
    '😡': 'angry',
  };

  /// All available reaction types
  static const List<String> allTypes = [
    'heart',
    'laugh',
    'wow',
    'sad',
    'angry',
  ];
  static const List<String> allEmojis = ['❤️', '😂', '😮', '😢', '😡'];
}
