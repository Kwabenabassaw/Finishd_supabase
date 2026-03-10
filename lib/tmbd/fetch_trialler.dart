import 'package:tmdb_api/tmdb_api.dart';
import 'package:finishd/config/env.dart';

class TvService {
  final TMDB tmdb = TMDB(
    ApiKeys(Env.tmdbApiKey, Env.tmdbReadAccessToken),
  );

  Future<String?> getTvShowTrailerKey(String name) async {
    try {
      // Search for the TV show
      final searchResults = await tmdb.v3.search.queryTvShows(name);
      final results = List.from(searchResults['results'] ?? []);
      if (results.isEmpty) return null;

      // Find closest match
      final lowerName = name.toLowerCase();
      final matchedResult = results.firstWhere(
        (r) {
          final tvName = (r['name'] ?? '').toString().toLowerCase();
          return tvName == lowerName || tvName.contains(lowerName);
        },
        orElse: () => results.first,
      );

      // Get show ID
      final int showId = matchedResult['id'] is int
          ? matchedResult['id']
          : int.tryParse(matchedResult['id'].toString()) ?? 0;

      if (showId == 0) return null;

      // Get videos for this TV show
      final videos = await tmdb.v3.tv.getVideos(showId.toString());
      final videoResults = List.from(videos['results'] ?? []);
      if (videoResults.isEmpty) return null;

      // Find YouTube trailer
      final trailer = videoResults.cast<Map<String, dynamic>>().firstWhere(
        (v) =>
            v['site'] == 'YouTube' &&
            v['type'] == 'Trailer' &&
            (v['name']?.toString().toLowerCase().contains('trailer') ?? false),
        orElse: () => {},
      );

      if (trailer.isEmpty) return null;

      // Return only the key
      return trailer['key']?.toString();
    } catch (e) {
      print('❌ Error fetching trailer key: $e');
      return null;
    }
  }

  Future<String?> getMovieTrailerKey(movieid) async {
    try {
      final videos = await tmdb.v3.movies.getVideos(movieid);
      final videoResults = List.from(videos['results'] ?? []);
      if (videoResults.isEmpty) return null;

      // Find YouTube trailer
       final trailer = videoResults.firstWhere(
      (video) =>
          video['site'] == 'YouTube' &&
          video['type'] == 'Trailer' &&
          video['key'] != null,
      orElse: () => null,
    );

    if (trailer == null) return null;

    return trailer['key']; // YouTube key

    }
    catch(e){
      print('❌ Error fetching trailer key: $e');
      return null;
    }

  }
  Future<String?> getTVShowTrailerKey(showId) async {
  try {
    final videos = await tmdb.v3.tv.getVideos(showId);

    final List<dynamic> videoResults = videos['results'] ?? [];

    if (videoResults.isEmpty) return null;

    // Find the first YouTube trailer
    final trailer = videoResults.firstWhere(
      (video) =>
          video['site'] == 'YouTube' &&
          video['type'] == 'Trailer' &&
          video['key'] != null,
      orElse: () => null,
    );

    if (trailer == null) return null;

    return trailer['key']; // Return YouTube key
  } catch (e) {
    print('❌ Error fetching TV trailer key: $e');
    return null;
  }
}

}
