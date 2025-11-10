import 'package:tmdb_api/tmdb_api.dart';

class TvService {
  final TMDB tmdb = TMDB(
    ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
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
}
