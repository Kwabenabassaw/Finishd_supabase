



import 'package:finishd/Model/Searchdiscover.dart';
import 'package:finishd/Model/trending.dart';
import 'package:tmdb_api/tmdb_api.dart';
import 'package:finishd/config/env.dart';


class SearchDiscover {

    final TMDB tmdb = TMDB(
    ApiKeys(Env.tmdbApiKey, Env.tmdbReadAccessToken),
  );



  Future <List<MediaItem>>getSearch(String query) async {
    try {
      final result = await tmdb.v3.search.queryMulti(query);
      final resultsList = result['results'] as List<dynamic>;

      final searchResults = resultsList.map((item) => MediaItem.fromJson(item)).toList();

      return searchResults;
    }catch(e){
      print("Error fetching search results: $e");
      rethrow;
    }
  
  }
 Future<List<Result>> getSearchitem(String query) async {
  try {
    final result = await tmdb.v3.search.queryMulti(query);
    final resultsList = result['results'] as List<dynamic>;

    final searchResults = resultsList.map((item) => Result.fromJson(item)).toList();

    return  searchResults;
  } catch (e) {
    print("Error fetching search results: $e");
    rethrow;
  }
}

}

