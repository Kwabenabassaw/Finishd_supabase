


import 'package:finishd/Model/Watchprovider.dart';
import 'package:tmdb_api/tmdb_api.dart';
import 'package:finishd/config/env.dart';

class Getproviders {
    final TMDB tmdb = TMDB(
    ApiKeys(Env.tmdbApiKey, Env.tmdbReadAccessToken),
  );

  Future <List<WatchProvider>> getMovieprovide  ()async{
    try {
      Map provider = await tmdb.v3.watchProviders.getMovieProviders(watchRegion: "US",language: "en");
      List result = provider['results'];
      
      return result.map((json)=>WatchProvider.fromJson(json)).toList();
    } catch (e) {
      print(e);
      rethrow;
    }
  }
}