class TvShowDetails {
  final int id;
  final String name;
  final String originalName;
  final String overview;
  final String? backdropPath;
  final String? posterPath;
  final String firstAirDate;
  final String? lastAirDate;
  final bool inProduction;
  final List<Genre> genres;
  final List<String> languages;
  final List<Network> networks;
  final int numberOfEpisodes;
  final int numberOfSeasons;
  final List<Season> seasons;
  final String status;
  final String? tagline;
  final String type;
  final double voteAverage;
  final int voteCount;

  TvShowDetails({
    required this.id,
    required this.name,
    required this.originalName,
    required this.overview,
    this.backdropPath,
    this.posterPath,
    required this.firstAirDate,
    this.lastAirDate,
    required this.inProduction,
    required this.genres,
    required this.languages,
    required this.networks,
    required this.numberOfEpisodes,
    required this.numberOfSeasons,
    required this.seasons,
    required this.status,
    this.tagline,
    required this.type,
    required this.voteAverage,
    required this.voteCount,
  });

  factory TvShowDetails.fromJson(Map<String, dynamic> json) {
    return TvShowDetails(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      originalName: json['original_name'] ?? 'Unknown',
      overview: json['overview'] ?? 'No overview',
      backdropPath: json['backdrop_path'],
      posterPath: json['poster_path'],
      firstAirDate: json['first_air_date'] ?? 'Unknown',
      lastAirDate: json['last_air_date'],
      inProduction: json['in_production'] ?? false,
      genres: (json['genres'] as List<dynamic>? ?? [])
          .map((g) => Genre.fromJson(g))
          .toList(),
      languages: (json['languages'] as List<dynamic>? ?? [])
          .map((l) => l.toString())
          .toList(),
      networks: (json['networks'] as List<dynamic>? ?? [])
          .map((n) => Network.fromJson(n))
          .toList(),
      numberOfEpisodes: json['number_of_episodes'] ?? 0,
      numberOfSeasons: json['number_of_seasons'] ?? 0,
      seasons: (json['seasons'] as List<dynamic>? ?? [])
          .map((s) => Season.fromJson(s))
          .toList(),
      status: json['status'] ?? 'Unknown',
      tagline: json['tagline'],
      type: json['type'] ?? 'Unknown',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
    );
  }
}

class Genre {
  final int id;
  final String name;

  Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
    );
  }
}

class Network {
  final int id;
  final String name;
  final String? logoPath;
  final String originCountry;

  Network({
    required this.id,
    required this.name,
    this.logoPath,
    required this.originCountry,
  });

  factory Network.fromJson(Map<String, dynamic> json) {
    return Network(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      logoPath: json['logo_path'],
      originCountry: json['origin_country'] ?? '',
    );
  }
}

class Season {
  final int id;
  final String name;
  final int seasonNumber;
  final int episodeCount;
  final String? airDate;
  final String? overview;
  final String? posterPath;
  final double voteAverage;

  Season({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.episodeCount,
    this.airDate,
    this.overview,
    this.posterPath,
    required this.voteAverage,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      seasonNumber: json['season_number'] ?? 0,
      episodeCount: json['episode_count'] ?? 0,
      airDate: json['air_date'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
    );
  }
}
