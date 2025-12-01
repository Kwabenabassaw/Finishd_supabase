import 'package:cloud_firestore/cloud_firestore.dart';

class Recommendation {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String movieId; // Changed to String to match MovieListItem
  final String movieTitle;
  final String? moviePosterPath;
  final String mediaType; // 'movie' or 'tv'
  final DateTime timestamp;
  final String status; // 'unread', 'seen'

  Recommendation({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    required this.mediaType,
    required this.timestamp,
    this.status = 'unread',
  });

  factory Recommendation.fromMap(Map<String, dynamic> map, String id) {
    return Recommendation(
      id: id,
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      movieId: map['movieId'] ?? '',
      movieTitle: map['movieTitle'] ?? '',
      moviePosterPath: map['moviePosterPath'],
      mediaType: map['mediaType'] ?? 'movie',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: map['status'] ?? 'unread',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'moviePosterPath': moviePosterPath,
      'mediaType': mediaType,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }
}
