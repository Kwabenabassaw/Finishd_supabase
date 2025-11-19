class TrendingMovies {
    int? page;
    List<Result>? results; // List of nested Result objects
    int? totalPages;
    int? totalResults;

    TrendingMovies({
        this.page,
        this.results,
        this.totalPages,
        this.totalResults,
    });

    // Factory constructor to create an object from a JSON Map
    factory TrendingMovies.fromJson(Map<String, dynamic> json) {
        return TrendingMovies(
            page: json['page'] as int?,
            // Map each item in the 'results' list to a Result object
            results: (json['results'] as List<dynamic>?)
                ?.map((e) => Result.fromJson(e as Map<String, dynamic>))
                .toList(),
            totalPages: json['total_pages'] as int?,
            totalResults: json['total_results'] as int?,
        );
    }

    // Method to convert the object back into a JSON Map
    Map<String, dynamic> toJson() {
        return <String, dynamic>{
            'page': page,
            // Convert each Result object back to a Map using its toJson() method
            'results': results?.map((e) => e?.toJson()).toList(),
            'total_pages': totalPages,
            'total_results': totalResults,
        };
    }
}
// Helper function to safely parse language enum with fallback
OriginalLanguage? _parseLanguage(String languageCode) {
    try {
        return OriginalLanguage.values.byName(languageCode);
    } catch (e) {
        // If language code is not recognized, default to EN or null
        return null;
    }
}

class Result {
    bool? adult;
    String? backdropPath;
    int? id;
    String? title;
    OriginalLanguage? originalLanguage;
    String? originalTitle;
    String? overview;
    String? posterPath;
    MediaType? mediaType;
    List<int>? genreIds;
    double? popularity;
    DateTime? releaseDate;
    bool? video;
    double? voteAverage;
    int? voteCount;

    Result({
        this.adult,
        this.backdropPath,
        this.id,
        this.title,
        this.originalLanguage,
        this.originalTitle,
        this.overview,
        this.posterPath,
        this.mediaType,
        this.genreIds,
        this.popularity,
        this.releaseDate,
        this.video,
        this.voteAverage,
        this.voteCount,
    });

    // Factory constructor to create an object from a JSON Map
    factory Result.fromJson(Map<String, dynamic> json) {
        return Result(
            adult: json['adult'] as bool?,
            backdropPath: json['backdrop_path'] as String?,
            id: json['id'] as int?,
            title: json['title'] as String?,
            // Convert String to enum, or null if key doesn't exist or unknown
            originalLanguage: (json['original_language'] as String?) != null 
                ? _parseLanguage(json['original_language'].toString().toUpperCase())
                : null,
            originalTitle: json['original_title'] as String?,
            overview: json['overview'] as String?,
            posterPath: json['poster_path'] as String?,
            // Convert String to enum (handling optionality)
            mediaType: (json['media_type'] as String?) != null
                ? MediaType.values.byName(json['media_type'].toString().toUpperCase())
                : null,
            genreIds: (json['genre_ids'] as List<dynamic>?)?.map((e) => e as int).toList(),
            // Ensure vote_average is treated as double, using null-aware casting
            popularity: json['popularity'] as double?,
            // NOTE: Dates from TMDB are strings, you may need a DateFormat or simply treat it as a String
            // For simplicity in toJson, we leave this as a basic nullable field.
            releaseDate: (json['release_date'] as String?) != null 
                ? DateTime.tryParse(json['release_date'] as String) : null,
            video: json['video'] as bool?,
            // Ensure vote_average is correctly cast (it might come as an int from JSON)
            voteAverage: (json['vote_average'] as num?)?.toDouble(),
            voteCount: json['vote_count'] as int?,
        );
    }

    // Method to convert the object back into a JSON Map
    Map<String, dynamic> toJson() {
        return <String, dynamic>{
            'adult': adult,
            'backdrop_path': backdropPath,
            'id': id,
            'title': title,
            // Convert enum back to its String name
            'original_language': originalLanguage?.name.toLowerCase(),
            'original_title': originalTitle,
            'overview': overview,
            'poster_path': posterPath,
            // Convert enum back to its String name
            'media_type': mediaType?.name.toLowerCase(),
            'genre_ids': genreIds,
            'popularity': popularity,
            'release_date': releaseDate?.toIso8601String().split('T').first, // Format date back to 'YYYY-MM-DD' string
            'video': video,
            'vote_average': voteAverage,
            'vote_count': voteCount,
        };
    }
}
enum MediaType {
    MOVIE
}

enum OriginalLanguage {
    EN,
    PL,
    TR,
    ZH,
    ES,
    FR,
    DE,
    IT,
    JA,
    KO,
    RU,
    PT,
    AR,
    HI,
    TV
}