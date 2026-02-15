/// Model for movies stored in user's lists (watching, watchlist, finished, favorites)
class MovieListItem {
  final String id;
  final String title;
  final String? posterPath;
  final String mediaType; // 'movie' or 'tv'
  final String genre; // Genre information
  final DateTime addedAt;
  final int? rating; // User rating (1-5)
  final String? status; // 'watching', 'watchlist', 'finished'
  final bool isFavorite;

  MovieListItem({
    required this.id,
    required this.title,
    this.posterPath,
    required this.mediaType,
    this.genre = '',
    required this.addedAt,
    this.rating,
    this.status,
    this.isFavorite = false,
  });

  // Convert to JSON for DB/Storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mediaType,
      'genre': genre,
      'addedAt': addedAt.toIso8601String(),
      'rating': rating,
      'status': status,
      'isFavorite': isFavorite
          ? 1
          : 0, // Store as int/bool in local DB if needed
    };
  }

  // Create from JSON/Map (Supabase or Local DB)
  factory MovieListItem.fromJson(Map<String, dynamic> data) {
    return MovieListItem(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? '',
      posterPath: data['posterPath'],
      mediaType: data['mediaType'] ?? 'movie',
      genre: data['genre'] ?? '',
      addedAt: data['addedAt'] is String
          ? DateTime.tryParse(data['addedAt']) ?? DateTime.now()
          : (data['addedAt'] is int
                ? DateTime.fromMillisecondsSinceEpoch(data['addedAt'])
                : DateTime.now()),
      rating: data['rating'] is int ? data['rating'] : null,
      status: data['status'],
      isFavorite: (data['isFavorite'] == 1 || data['isFavorite'] == true),
    );
  }

  // Adapter from Supabase user_titles table row
  factory MovieListItem.fromSupabase(Map<String, dynamic> data) {
    return MovieListItem(
      id: data['title_id'] ?? '',
      title: data['title'] ?? '',
      posterPath: data['poster_path'],
      mediaType: data['media_type'] ?? 'movie',
      genre: data['genre'] ?? '',
      addedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'])
          : DateTime.now(),
      rating: data['rating'],
      status: data['status'],
      isFavorite: data['is_favorite'] ?? false,
    );
  }

  // Copy with method for updates
  MovieListItem copyWith({
    String? id,
    String? title,
    String? posterPath,
    String? mediaType,
    String? genre,
    DateTime? addedAt,
    int? rating,
    String? status,
    bool? isFavorite,
  }) {
    return MovieListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      mediaType: mediaType ?? this.mediaType,
      genre: genre ?? this.genre,
      addedAt: addedAt ?? this.addedAt,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
