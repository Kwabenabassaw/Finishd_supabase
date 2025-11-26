class UserPreferences {
  final List<String> selectedGenres;
  final List<int> selectedGenreIds;
  final List<SelectedMedia> selectedMovies;
  final List<SelectedMedia> selectedShows;
  final List<SelectedProvider> streamingProviders;

  UserPreferences({
    this.selectedGenres = const [],
    this.selectedGenreIds = const [],
    this.selectedMovies = const [],
    this.selectedShows = const [],
    this.streamingProviders = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'selectedGenres': selectedGenres,
      'selectedGenreIds': selectedGenreIds,
      'selectedMovies': selectedMovies.map((m) => m.toJson()).toList(),
      'selectedShows': selectedShows.map((s) => s.toJson()).toList(),
      'streamingProviders': streamingProviders.map((p) => p.toJson()).toList(),
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      selectedGenres: List<String>.from(json['selectedGenres'] ?? []),
      selectedGenreIds: List<int>.from(json['selectedGenreIds'] ?? []),
      selectedMovies: (json['selectedMovies'] as List<dynamic>? ?? [])
          .map((m) => SelectedMedia.fromJson(m))
          .toList(),
      selectedShows: (json['selectedShows'] as List<dynamic>? ?? [])
          .map((s) => SelectedMedia.fromJson(s))
          .toList(),
      streamingProviders: (json['streamingProviders'] as List<dynamic>? ?? [])
          .map((p) => SelectedProvider.fromJson(p))
          .toList(),
    );
  }

  UserPreferences copyWith({
    List<String>? selectedGenres,
    List<int>? selectedGenreIds,
    List<SelectedMedia>? selectedMovies,
    List<SelectedMedia>? selectedShows,
    List<SelectedProvider>? streamingProviders,
  }) {
    return UserPreferences(
      selectedGenres: selectedGenres ?? this.selectedGenres,
      selectedGenreIds: selectedGenreIds ?? this.selectedGenreIds,
      selectedMovies: selectedMovies ?? this.selectedMovies,
      selectedShows: selectedShows ?? this.selectedShows,
      streamingProviders: streamingProviders ?? this.streamingProviders,
    );
  }
}

class SelectedMedia {
  final int id;
  final String title;
  final String posterPath;
  final String mediaType;

  SelectedMedia({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.mediaType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mediaType,
    };
  }

  factory SelectedMedia.fromJson(Map<String, dynamic> json) {
    return SelectedMedia(
      id: json['id'],
      title: json['title'],
      posterPath: json['posterPath'],
      mediaType: json['mediaType'],
    );
  }
}

class SelectedProvider {
  final int providerId;
  final String providerName;
  final String logoPath;

  SelectedProvider({
    required this.providerId,
    required this.providerName,
    required this.logoPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'logoPath': logoPath,
    };
  }

  factory SelectedProvider.fromJson(Map<String, dynamic> json) {
    return SelectedProvider(
      providerId: json['providerId'],
      providerName: json['providerName'],
      logoPath: json['logoPath'],
    );
  }
}
