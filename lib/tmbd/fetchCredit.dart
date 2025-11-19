import 'package:finishd/Model/MovieCredit.dart';
import 'package:finishd/Model/TvShowcredit.dart';
import 'package:tmdb_api/tmdb_api.dart';


class Fetchcredit {
  final TMDB tmdb = TMDB(
    ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
  );

  Future<TvShowCredit> fetchTvShowCredit(int showId) async {
    try {
      final result = await tmdb.v3.tv.getCredits(showId);
      final data = Map<String, dynamic>.from(result);
      return TvShowCredit.fromJson(data);
    } catch (e) {
      print("Error fetching TV show credits: $e");
      rethrow;
    }
  }
  Future <MovieCredit> fetchMovieCredit(int movieId) async {

    try {
      final result = await tmdb.v3.movies.getCredits(movieId);
      final data = Map<String, dynamic>.from(result);
      return MovieCredit.fromJson(data);
    } catch (e) {
      print(  "Error fetching TV show credits: $e");
      rethrow;
    
    }
  }

}