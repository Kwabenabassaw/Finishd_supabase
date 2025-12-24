import 'package:finishd/Model/tmdb_extras.dart';

class SeasonDetail {
  final String id;
  final String airDate;
  final List<Episode> episodes;
  final String name;
  final String overview;
  final int seasonDetailId;
  final String posterPath;
  final int seasonNumber;
  final double voteAverage;

  SeasonDetail({
    required this.id,
    required this.airDate,
    required this.episodes,
    required this.name,
    required this.overview,
    required this.seasonDetailId,
    required this.posterPath,
    required this.seasonNumber,
    required this.voteAverage,
  });

  factory SeasonDetail.fromJson(Map<String, dynamic> json) {
    return SeasonDetail(
      id: json['_id'] ?? '',
      airDate: json['air_date'] ?? '',
      episodes: List<Episode>.from(
        (json['episodes'] ?? []).map((x) => Episode.fromJson(x)),
      ),
      name: json['name'] ?? '',
      overview: json['overview'] ?? '',
      seasonDetailId: json['id'] ?? 0,
      posterPath: json['poster_path'] ?? '',
      seasonNumber: json['season_number'] ?? 0,
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
    );
  }
}

class Episode {
  final String airDate;
  final int episodeNumber;
  final int id;
  final String name;
  final String overview;
  final String productionCode;
  final int runtime;
  final int seasonNumber;
  final int showId;
  final String stillPath;
  final double voteAverage;
  final int voteCount;
  final List<Cast> guestStars;
  final List<Crew> crew;

  Episode({
    required this.airDate,
    required this.episodeNumber,
    required this.id,
    required this.name,
    required this.overview,
    required this.productionCode,
    required this.runtime,
    required this.seasonNumber,
    required this.showId,
    required this.stillPath,
    required this.voteAverage,
    required this.voteCount,
    this.guestStars = const [],
    this.crew = const [],
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      airDate: json['air_date'] ?? '',
      episodeNumber: json['episode_number'] ?? 0,
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      overview: json['overview'] ?? '',
      productionCode: json['production_code'] ?? '',
      runtime: json['runtime'] ?? 0,
      seasonNumber: json['season_number'] ?? 0,
      showId: json['show_id'] ?? 0,
      stillPath: json['still_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      guestStars: (json['guest_stars'] as List<dynamic>? ?? [])
          .map((x) => Cast.fromJson(x))
          .toList(),
      crew: (json['crew'] as List<dynamic>? ?? [])
          .map((x) => Crew.fromJson(x))
          .toList(),
    );
  }
}

class Crew {
  final int id;
  final String name;
  final String job;
  final String department;
  final String? profilePath;

  Crew({
    required this.id,
    required this.name,
    required this.job,
    required this.department,
    this.profilePath,
  });

  factory Crew.fromJson(Map<String, dynamic> json) {
    return Crew(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      job: json['job'] ?? '',
      department: json['department'] ?? '',
      profilePath: json['profile_path'],
    );
  }

  String get profileUrl =>
      profilePath != null ? 'https://image.tmdb.org/t/p/w185$profilePath' : '';
}
