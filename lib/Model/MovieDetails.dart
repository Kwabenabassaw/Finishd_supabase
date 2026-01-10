import 'package:finishd/Model/tmdb_extras.dart';
import 'package:finishd/Model/Watchprovider.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/trending.dart';

class MovieDetails {
  final bool adult;
  final String? backdropPath;
  final int? budget;
  final List<Genre> genres;
  final String? homepage;
  final int id;
  final String? imdbId;
  final String? originalLanguage;
  final String? originalTitle;
  final String? overview;
  final double? popularity;
  final String? posterPath;
  final List<ProductionCompany> productionCompanies;
  final List<ProductionCountry> productionCountries;
  final String? releaseDate;
  final int? revenue;
  final int? runtime;
  final List<SpokenLanguage> spokenLanguages;
  final String? status;
  final String? tagline;
  final String title;
  final bool? video;
  final double? voteAverage;
  final int? voteCount;
  final List<Video> videos;
  final List<Cast> cast;
  final WatchProvidersResponse? watchProviders;
  final String? mediaType;

  MovieDetails({
    required this.adult,
    this.backdropPath,
    this.budget,
    required this.genres,
    this.homepage,
    required this.id,
    this.imdbId,
    this.originalLanguage,
    this.originalTitle,
    this.overview,
    this.popularity,
    this.posterPath,
    required this.productionCompanies,
    required this.productionCountries,
    this.releaseDate,
    this.revenue,
    this.runtime,
    required this.spokenLanguages,
    this.status,
    this.tagline,
    required this.title,
    this.video,
    this.voteAverage,
    this.voteCount,
    this.videos = const [],
    this.cast = const [],
    this.watchProviders,
    this.mediaType,
  });

  /// Create a shallow MovieDetails object from a MovieListItem
  factory MovieDetails.shallowFromListItem(MovieListItem item) {
    return MovieDetails(
      adult: false,
      genres: [],
      id: int.parse(item.id),
      productionCompanies: [],
      productionCountries: [],
      spokenLanguages: [],
      title: item.title,
      posterPath: item.posterPath,
      mediaType: 'movie', // Helper for detail screens if needed
      releaseDate: '',
      overview: '',
    );
  }

  /// Create a shallow MovieDetails object from a MediaItem
  factory MovieDetails.shallowFromMediaItem(MediaItem item) {
    return MovieDetails(
      adult: false,
      genres: item.genreIds.map((id) => Genre(id: id, name: '')).toList(),
      id: item.id,
      productionCompanies: [],
      productionCountries: [],
      spokenLanguages: [],
      title: item.title,
      posterPath: item.posterPath,
      backdropPath: item.backdropPath,
      voteAverage: item.voteAverage,
      releaseDate: item.releaseDate,
      overview: item.overview,
    );
  }

  factory MovieDetails.fromJson(Map<String, dynamic> json) {
    var videosList = <Video>[];
    if (json['videos'] != null && json['videos']['results'] != null) {
      videosList = (json['videos']['results'] as List)
          .map((v) => Video.fromJson(v))
          .toList();
    }

    var castList = <Cast>[];
    if (json['credits'] != null && json['credits']['cast'] != null) {
      castList = (json['credits']['cast'] as List)
          .map((c) => Cast.fromJson(c))
          .toList();
    }

    WatchProvidersResponse? providers;
    if (json['watch/providers'] != null &&
        json['watch/providers']['results'] != null) {
      providers = WatchProvidersResponse.fromJson(json['watch/providers']);
    }

    return MovieDetails(
      adult: json['adult'] ?? false,
      backdropPath: json['backdrop_path'],
      budget: json['budget'],
      genres: (json['genres'] as List<dynamic>? ?? [])
          .map((e) => Genre.fromJson(e))
          .toList(),
      homepage: json['homepage'],
      id: json['id'] ?? 0,
      imdbId: json['imdb_id'],
      originalLanguage: json['original_language'],
      originalTitle: json['original_title'],
      overview: json['overview'],
      popularity: (json['popularity'] ?? 0).toDouble(),
      posterPath: json['poster_path'],
      productionCompanies:
          (json['production_companies'] as List<dynamic>? ?? [])
              .map((e) => ProductionCompany.fromJson(e))
              .toList(),
      productionCountries:
          (json['production_countries'] as List<dynamic>? ?? [])
              .map((e) => ProductionCountry.fromJson(e))
              .toList(),
      releaseDate: json['release_date'],
      revenue: json['revenue'],
      runtime: json['runtime'],
      spokenLanguages: (json['spoken_languages'] as List<dynamic>? ?? [])
          .map((e) => SpokenLanguage.fromJson(e))
          .toList(),
      status: json['status'],
      tagline: json['tagline'],
      title: json['title'] ?? 'Unknown',
      video: json['video'],
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'],
      videos: videosList,
      cast: castList,
      watchProviders: providers,
      mediaType: json['media_type'] ?? 'movie',
    );
  }
}

// --- Nested classes ---

class Genre {
  final int id;
  final String name;

  Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(id: json['id'] ?? 0, name: json['name'] ?? 'Unknown');
  }
}

class ProductionCompany {
  final int id;
  final String? logoPath;
  final String name;
  final String? originCountry;

  ProductionCompany({
    required this.id,
    this.logoPath,
    required this.name,
    this.originCountry,
  });

  factory ProductionCompany.fromJson(Map<String, dynamic> json) {
    return ProductionCompany(
      id: json['id'] ?? 0,
      logoPath: json['logo_path'],
      name: json['name'] ?? 'Unknown',
      originCountry: json['origin_country'],
    );
  }
}

class ProductionCountry {
  final String? iso31661;
  final String? name;

  ProductionCountry({this.iso31661, this.name});

  factory ProductionCountry.fromJson(Map<String, dynamic> json) {
    return ProductionCountry(iso31661: json['iso_3166_1'], name: json['name']);
  }
}

class SpokenLanguage {
  final String? englishName;
  final String? iso6391;
  final String? name;

  SpokenLanguage({this.englishName, this.iso6391, this.name});

  factory SpokenLanguage.fromJson(Map<String, dynamic> json) {
    return SpokenLanguage(
      englishName: json['english_name'],
      iso6391: json['iso_639_1'],
      name: json['name'],
    );
  }
}
