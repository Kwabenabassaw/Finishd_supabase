import 'package:finishd/Model/MovieCredit.dart';
import 'package:finishd/Model/TvShowcredit.dart';
import 'package:tmdb_api/tmdb_api.dart';
import 'package:finishd/config/env.dart';


class Fetchcredit {
  final TMDB tmdb = TMDB(
    ApiKeys(Env.tmdbApiKey, Env.tmdbReadAccessToken),
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