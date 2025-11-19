class Searchdiscover {
    Searchdiscover({
        required this.page,
        required this.results,
        required this.totalPages,
        required this.totalResults,
    });

    final int? page;
    final List<Result> results;
    final int? totalPages;
    final int? totalResults;

    Searchdiscover copyWith({
        int? page,
        List<Result>? results,
        int? totalPages,
        int? totalResults,
    }) {
        return Searchdiscover(
            page: page ?? this.page,
            results: results ?? this.results,
            totalPages: totalPages ?? this.totalPages,
            totalResults: totalResults ?? this.totalResults,
        );
    }

    factory Searchdiscover.fromJson(Map<String, dynamic> json){ 
        return Searchdiscover(
            page: json["page"],
            results: json["results"] == null ? [] : List<Result>.from(json["results"]!.map((x) => Result.fromJson(x))),
            totalPages: json["total_pages"],
            totalResults: json["total_results"],
        );
    }

    Map<String, dynamic> toJson() => {
        "page": page,
        "results": results.map((x) => x.toJson()).toList(),
        "total_pages": totalPages,
        "total_results": totalResults,
    };

    @override
    String toString(){
        return "$page, $results, $totalPages, $totalResults, ";
    }
}

class Result {
    Result({
        required this.adult,
        required this.backdropPath,
        required this.id,
        required this.title,
        required this.originalLanguage,
        required this.originalTitle,
        required this.overview,
        required this.posterPath,
        required this.mediaType,
        required this.genreIds,
        required this.popularity,
        required this.releaseDate,
        required this.video,
        required this.voteAverage,
        required this.voteCount,
        required this.name,
        required this.originalName,
        required this.firstAirDate,
        required this.originCountry,
    });

    final bool? adult;
    final String? backdropPath;
    final int? id;
    final String? title;
    final String? originalLanguage;
    final String? originalTitle;
    final String? overview;
    final String? posterPath;
    final String? mediaType;
    final List<int> genreIds;
    final double? popularity;
    final DateTime? releaseDate;
    final bool? video;
    final double? voteAverage;
    final int? voteCount;
    final String? name;
    final String? originalName;
    final DateTime? firstAirDate;
    final List<String> originCountry;

    Result copyWith({
        bool? adult,
        String? backdropPath,
        int? id,
        String? title,
        String? originalLanguage,
        String? originalTitle,
        String? overview,
        String? posterPath,
        String? mediaType,
        List<int>? genreIds,
        double? popularity,
        DateTime? releaseDate,
        bool? video,
        double? voteAverage,
        int? voteCount,
        String? name,
        String? originalName,
        DateTime? firstAirDate,
        List<String>? originCountry,
    }) {
        return Result(
            adult: adult ?? this.adult,
            backdropPath: backdropPath ?? this.backdropPath,
            id: id ?? this.id,
            title: title ?? this.title,
            originalLanguage: originalLanguage ?? this.originalLanguage,
            originalTitle: originalTitle ?? this.originalTitle,
            overview: overview ?? this.overview,
            posterPath: posterPath ?? this.posterPath,
            mediaType: mediaType ?? this.mediaType,
            genreIds: genreIds ?? this.genreIds,
            popularity: popularity ?? this.popularity,
            releaseDate: releaseDate ?? this.releaseDate,
            video: video ?? this.video,
            voteAverage: voteAverage ?? this.voteAverage,
            voteCount: voteCount ?? this.voteCount,
            name: name ?? this.name,
            originalName: originalName ?? this.originalName,
            firstAirDate: firstAirDate ?? this.firstAirDate,
            originCountry: originCountry ?? this.originCountry,
        );
    }

    factory Result.fromJson(Map<String, dynamic> json){ 
        return Result(
            adult: json["adult"],
            backdropPath: json["backdrop_path"],
            id: json["id"],
            title: json["title"],
            originalLanguage: json["original_language"],
            originalTitle: json["original_title"],
            overview: json["overview"],
            posterPath: json["poster_path"],
            mediaType: json["media_type"],
            genreIds: json["genre_ids"] == null ? [] : List<int>.from(json["genre_ids"]!.map((x) => x)),
            popularity: json["popularity"],
            releaseDate: DateTime.tryParse(json["release_date"] ?? ""),
            video: json["video"],
            voteAverage: json["vote_average"],
            voteCount: json["vote_count"],
            name: json["name"],
            originalName: json["original_name"],
            firstAirDate: DateTime.tryParse(json["first_air_date"] ?? ""),
            originCountry: json["origin_country"] == null ? [] : List<String>.from(json["origin_country"]!.map((x) => x)),
        );
    }

  get profilePath => null;

    Map<String, dynamic> toJson() => {
        "adult": adult,
        "backdrop_path": backdropPath,
        "id": id,
        "title": title,
        "original_language": originalLanguage,
        "original_title": originalTitle,
        "overview": overview,
        "poster_path": posterPath,
        "media_type": mediaType,
        "genre_ids": genreIds.map((x) => x).toList(),
        "popularity": popularity,
        "release_date": "${releaseDate?.year.toString().padLeft(4,'0')}-${releaseDate?.month.toString().padLeft(2,'0')}-${releaseDate?.day.toString().padLeft(2,'0')}",
        "video": video,
        "vote_average": voteAverage,
        "vote_count": voteCount,
        "name": name,
        "original_name": originalName,
        "first_air_date": "${firstAirDate?.year.toString().padLeft(4,'0')}-${firstAirDate?.month.toString().padLeft(2,'0')}-${firstAirDate?.day.toString().padLeft(2,'0')}",
        "origin_country": originCountry.map((x) => x).toList(),
    };

    @override
    String toString(){
        return "$adult, $backdropPath, $id, $title, $originalLanguage, $originalTitle, $overview, $posterPath, $mediaType, $genreIds, $popularity, $releaseDate, $video, $voteAverage, $voteCount, $name, $originalName, $firstAirDate, $originCountry, ";
    }
}
