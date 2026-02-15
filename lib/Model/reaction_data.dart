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
    final String reactionType = json['reaction_type'] ?? 'heart';
    return ReactionData(
      timestamp: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      type: reactionType,
      emoji: typeToEmoji[reactionType] ?? '❤️', // Derive emoji from type
      userId: json['user_id'] ?? '',
      videoId: json['video_id'] ?? '',
    );
  }

  /// Convert to JSON for Supabase upsert
  Map<String, dynamic> toJson() {
    return {
      'reaction_type': type,
      'user_id': userId,
      'video_id': videoId,
      // created_at is handled by default constraint on insert
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
