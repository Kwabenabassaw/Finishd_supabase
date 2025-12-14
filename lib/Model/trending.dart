class MediaItem {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final String mediaType;
  final String releaseDate;
  final List<int> genreIds;

  MediaItem({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.mediaType,
    required this.releaseDate,
    required this.genreIds,
    required String imageUrl,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json, {String? type}) {
    return MediaItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? 'No Title',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      mediaType: json['media_type'] ?? type ?? 'unknown',
      releaseDate: json['release_date'] ?? json['first_air_date'] ?? '',
      genreIds: (json['genre_ids'] as List<dynamic>? ?? [])
          .map((id) => id as int)
          .toList(),
      imageUrl: '',
    );
  }

  MediaItem copyWith({
    int? id,
    String? title,
    String? overview,
    String? posterPath,
    String? backdropPath,
    double? voteAverage,
    String? mediaType,
    String? releaseDate,
    List<int>? genreIds,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      voteAverage: voteAverage ?? this.voteAverage,
      mediaType: mediaType ?? this.mediaType,
      releaseDate: releaseDate ?? this.releaseDate,
      genreIds: genreIds ?? this.genreIds,
      imageUrl: '',
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'vote_average': voteAverage,
      'media_type': mediaType,
      'release_date': releaseDate,
      'genre_ids': genreIds,
    };
  }
}
