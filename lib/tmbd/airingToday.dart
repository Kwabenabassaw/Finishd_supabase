import 'package:finishd/Model/trending.dart';
import 'package:tmdb_api/tmdb_api.dart';
import 'package:finishd/config/env.dart';

class Airingtoday {
  TMDB tmdb = TMDB(
    ApiKeys(Env.tmdbApiKey, Env.tmdbReadAccessToken),
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
