

import 'dart:convert';

import 'package:finishd/Model/Watchprovider.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:tmdb_api/tmdb_api.dart';

class Getproviders {
    final TMDB tmdb = TMDB(
    ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
  );

  Future <List<WatchProvider>> getMovieprovide  ()async{
    try {
      Map provider = await tmdb.v3.watchProviders.getMovieProviders(watchRegion: "US");
      List result = provider['results'];
      
      return result.map((json)=>WatchProvider.fromJson(json)).toList();
    } catch (e) {
      print(e);
      rethrow;
    }
  }
}