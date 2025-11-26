import 'package:finishd/Model/trending.dart';
import 'package:tmdb_api/tmdb_api.dart';

class Airingtoday {
  TMDB tmdb = TMDB(
    ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
  );

  Future<List<MediaItem>> fetchAiringToday() async {
    try {
      Map data = await tmdb.v3.tv.getAiringToday();
      List<dynamic> results = data['results'];
      // Explicitly set type to 'tv' for TV shows from airing today API
      List<MediaItem> airingToday = results
          .map((item) => MediaItem.fromJson(item, type: 'tv'))
          .toList();
      return airingToday;
    } catch (e) {
      print(e);
      return [];
    }
  }
}
