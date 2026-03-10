import 'package:tmdb_api/tmdb_api.dart';
import 'package:finishd/config/env.dart';

class NowPlaying {
final TMDB tmdb = TMDB(
    ApiKeys(Env.tmdbApiKey, Env.tmdbReadAccessToken),
  );


  
}