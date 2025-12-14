import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String text;
  final String mediaUrl;
  final String type; // 'text', 'image', 'video', 'video_link', 'recommendation'
  final Timestamp timestamp;
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

  /// Check if this message is a video link with preview
  bool get isVideoLink => type == 'video_link' && videoId != null;

  /// Check if this message is a movie/TV recommendation
  bool get isRecommendation => type == 'recommendation' && movieId != null;

  factory Message.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      messageId: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      type: data['type'] ?? 'text',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
      videoId: data['videoId'],
      videoTitle: data['videoTitle'],
      videoThumbnail: data['videoThumbnail'],
      videoChannel: data['videoChannel'],
      movieId: data['movieId'],
      movieTitle: data['movieTitle'],
      moviePoster: data['moviePoster'],
      mediaType: data['mediaType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'mediaUrl': mediaUrl,
      'type': type,
      'timestamp': timestamp,
      'isRead': isRead,
      if (videoId != null) 'videoId': videoId,
      if (videoTitle != null) 'videoTitle': videoTitle,
      if (videoThumbnail != null) 'videoThumbnail': videoThumbnail,
      if (videoChannel != null) 'videoChannel': videoChannel,
      if (movieId != null) 'movieId': movieId,
      if (movieTitle != null) 'movieTitle': movieTitle,
      if (moviePoster != null) 'moviePoster': moviePoster,
      if (mediaType != null) 'mediaType': mediaType,
    };
  }
}
