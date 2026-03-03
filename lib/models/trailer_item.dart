class TrailerItem {
  final String id;
  final String title;
  final String posterUrl;
  final String backdropUrl;
  final String description;
  final String youtubeKey;
  final double voteAverage;
  final String mediaType;
  final DateTime? releaseDate;

  TrailerItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.backdropUrl,
    required this.description,
    required this.youtubeKey,
    required this.voteAverage,
    required this.mediaType,
    this.releaseDate,
  });

  factory TrailerItem.fromJson(Map<String, dynamic> json) {
    return TrailerItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['name'] ?? '',
      posterUrl: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}'
          : '',
      backdropUrl: json['backdrop_path'] != null
          ? 'https://image.tmdb.org/t/p/original${json['backdrop_path']}'
          : '',
      description: json['overview'] ?? '',
      youtubeKey:
          json['youtube_key'] ??
          '', // To be filled by fetching videos if not present
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      mediaType: json['media_type'] ?? 'movie',
      releaseDate: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'])
          : null,
    );
  }

  TrailerItem copyWith({
    String? id,
    String? title,
    String? posterUrl,
    String? backdropUrl,
    String? description,
    String? youtubeKey,
    double? voteAverage,
    String? mediaType,
    DateTime? releaseDate,
  }) {
    return TrailerItem(
      id: id ?? this.id,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      description: description ?? this.description,
      youtubeKey: youtubeKey ?? this.youtubeKey,
      voteAverage: voteAverage ?? this.voteAverage,
      mediaType: mediaType ?? this.mediaType,
      releaseDate: releaseDate ?? this.releaseDate,
    );
  }
}
