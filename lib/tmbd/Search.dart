



import 'package:finishd/Model/Searchdiscover.dart';
import 'package:tmdb_api/tmdb_api.dart';


class SearchDiscover {

    final TMDB tmdb = TMDB(
    ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
  );



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

