class Message {
  final String messageId;
  final String senderId;
  final String
  receiverId; // In Supabase, messages belong to chat, receiver is implied. But keeping for model compat.
  final String text;
  final String mediaUrl;
  final String type; // 'text', 'image', 'video', 'video_link', 'recommendation'
  final DateTime timestamp;
  final bool isRead;

  // Video link preview metadata (for type == 'video_link')
  final String? videoId;
  final String? videoTitle;
  final String? videoThumbnail;
  final String? videoChannel;

  // Movie/TV recommendation metadata (for type == 'recommendation')
  final String? movieId;
  final String? movieTitle;
  final String? moviePoster;
  final String? mediaType; // 'movie' or 'tv'

  Message({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.mediaUrl = '',
    this.type = 'text',
    required this.timestamp,
    this.isRead = false,
    this.videoId,
    this.videoTitle,
    this.videoThumbnail,
    this.videoChannel,
    this.movieId,
    this.movieTitle,
    this.moviePoster,
    this.mediaType,
  });

  bool get isVideoLink => type == 'video_link' && videoId != null;
  bool get isRecommendation => type == 'recommendation' && movieId != null;

  factory Message.fromSupabase(Map<String, dynamic> data) {
    // Extract metadata from JSONB column if exists
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    return Message(
      messageId: data['id'],
      senderId: data['sender_id'] ?? '',
      receiverId: '', // Context dependent, often not in message row
      text: data['content'] ?? '',
      mediaUrl: data['media_url'] ?? '',
      type: data['type'] ?? 'text',
      timestamp: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      isRead: data['is_read'] ?? false,

      // Map metadata fields
      videoId:
          metadata['videoId'] ?? data['videoId'], // Support flattened or nested
      videoTitle: metadata['videoTitle'] ?? data['videoTitle'],
      videoThumbnail: metadata['videoThumbnail'] ?? data['videoThumbnail'],
      videoChannel: metadata['videoChannel'] ?? data['videoChannel'],

      movieId: metadata['movieId'] ?? data['movieId'],
      movieTitle: metadata['movieTitle'] ?? data['movieTitle'],
      moviePoster: metadata['moviePoster'] ?? data['moviePoster'],
      mediaType: metadata['mediaType'] ?? data['mediaType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': messageId,
      'sender_id': senderId,
      'content': text,
      'media_url': mediaUrl,
      'type': type,
      'created_at': timestamp.toIso8601String(),
      'is_read': isRead,
      'metadata': {
        if (videoId != null) 'videoId': videoId,
        if (videoTitle != null) 'videoTitle': videoTitle,
        if (videoThumbnail != null) 'videoThumbnail': videoThumbnail,
        if (videoChannel != null) 'videoChannel': videoChannel,
        if (movieId != null) 'movieId': movieId,
        if (movieTitle != null) 'movieTitle': movieTitle,
        if (moviePoster != null) 'moviePoster': moviePoster,
        if (mediaType != null) 'mediaType': mediaType,
      },
    };
  }
}
