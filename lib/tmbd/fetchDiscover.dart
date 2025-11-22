

import 'package:finishd/Model/trending.dart';
import 'package:tmdb_api/tmdb_api.dart';

class Fetchdiscover {

  TMDB tmdb = TMDB(
   ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
  );

 Future<List<MediaItem>> fetchDiscover() async {
  try {
    // Fetch movies and TV shows from TMDB
    Map movieData = await tmdb.v3.discover.getMovies();
    Map tvData = await tmdb.v3.discover.getTvShows();

    // Map movie results to MediaItem
    List<MediaItem> movies = (movieData['results'] as List<dynamic>?)
            ?.map((item) => MediaItem.fromJson(item, type: 'movie'))
            .toList() ??
        [];

    // Map TV results to MediaItem
    List<MediaItem> tvShows = (tvData['results'] as List<dynamic>?)
            ?.map((item) => MediaItem.fromJson(item, type: 'tv'))
            .toList() ??
        [];

    // Combine movies and TV shows into a single list
    List<MediaItem> combined = [];
     combined.addAll(tvShows);
    combined.addAll(movies);
   combined.shuffle();

    return combined;
  } catch (e) {
    print(e);
    return [];
  }
}

}