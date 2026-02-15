class Recommendation {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String movieId;
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
      fromUserId:
          map['from_user_id'] ??
          map['fromUserId'] ??
          '', // Support both snake_case (DB) and camelCase (Legacy)
      toUserId: map['to_user_id'] ?? map['toUserId'] ?? '',
      movieId: map['movie_id'] ?? map['movieId'] ?? '',
      movieTitle: map['title'] ?? map['movie_title'] ?? map['movieTitle'] ?? '',
      moviePosterPath:
          map['poster_path'] ??
          map['movie_poster_path'] ??
          map['moviePosterPath'],
      mediaType: map['media_type'] ?? map['mediaType'] ?? 'movie',
      timestamp: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : (map['timestamp'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
                : DateTime.now()),
      status: map['status'] ?? 'unread',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'media_type': mediaType,
      'created_at': timestamp.toIso8601String(),
      'status': status,
    };
  }
}
