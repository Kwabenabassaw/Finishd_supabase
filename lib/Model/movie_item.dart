class MovieItem {
  final int id;
  final String? title;
  final String? posterPath;
  final String? mediaType; // 'movie' or 'tv'
  final String? genre; // Simplified for display

  MovieItem({
    required this.id,
    this.title,
    this.posterPath,
    this.genre,
    this.mediaType,
  });

  // Example fromJson if you're using TMDB Result
  factory MovieItem.fromTmdbResult(Map<String, dynamic> json) {
    return MovieItem(
      id: json['id'] as int,
      title:
          json['title'] as String? ??
          json['name'] as String?, // handle movie/tv title
      posterPath: json['poster_path'] as String?,
      genre: 'Genre Genre Genre', // Placeholder for actual genre logic
      mediaType: json['media_type'] as String?,
    );
  }
}

// Utility for TMDB image URLs
String getTmdbImageUrl(String? path, {String size = 'w500'}) {
  if (path == null || path.isEmpty) {
    return 'https://via.placeholder.com/200x300?text=No+Image';
  }
  return 'https://image.tmdb.org/t/p/$size$path';
}
