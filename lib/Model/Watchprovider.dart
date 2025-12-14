// Individual provider (flatrate / ads)
class WatchProvider {
  final String? logoPath;
  final int providerId;
  final String providerName;
  final int displayPriority;

  WatchProvider({
    required this.logoPath,
    required this.providerId,
    required this.providerName,
    required this.displayPriority,
  });

  factory WatchProvider.fromJson(Map<String, dynamic> json) {
    return WatchProvider(
      logoPath: json['logo_path'],
      providerId: json['provider_id'] ?? 0,
      providerName: json['provider_name'] ?? 'Unknown',
      displayPriority: json['display_priority'] ?? 0,
    );
  }
}

// Country-specific watch info
class CountryWatchInfo {
  final String link;
  final List<WatchProvider> flatrate;
  final List<WatchProvider> ads;

  CountryWatchInfo({
    required this.link,
    required this.flatrate,
    required this.ads,
  });

  factory CountryWatchInfo.fromJson(Map<String, dynamic> json) {
    return CountryWatchInfo(
      link: json['link'] ?? "",
      flatrate: (json['flatrate'] ?? [])
          .map<WatchProvider>((p) => WatchProvider.fromJson(p))
          .toList(),
      ads: (json['ads'] ?? [])
          .map<WatchProvider>((p) => WatchProvider.fromJson(p))
          .toList(),
    );
  }
}

// Full response from TMDB
class WatchProvidersResponse {
  final int id;
  final Map<String, CountryWatchInfo> results;

  WatchProvidersResponse({required this.id, required this.results});

  factory WatchProvidersResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as Map<String, dynamic>? ?? {};
    return WatchProvidersResponse(
      id: json['id'] ?? 0,
      results: rawResults.map(
        (countryCode, countryData) =>
            MapEntry(countryCode, CountryWatchInfo.fromJson(countryData)),
      ),
    );
  }
}
