
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/Watchprovider.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Model/season_detail_model.dart';
import 'package:tmdb_api/tmdb_api.dart';

class Trending {
  final TMDB tmdb = TMDB(
    ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
  );

  /// GENRE MAP
  Map<int, String> genreMap = {};

  // ---------------------------------------------------------------------------
  // ✅ FETCH TRENDING TV SHOWS
  // ---------------------------------------------------------------------------
  Future<List<MediaItem>> fetchTrendingShow() async {
    try {
      Map result = await tmdb.v3.trending.getTrending(
        mediaType: MediaType.tv,
        timeWindow: TimeWindow.week,
        language: 'en-US',
      );

      List list = result['results'] ?? [];

      return list.map((json) => MediaItem.fromJson(json)).toList();
    } catch (e) {
      print("Error fetching trending shows: $e");
      return [];
    }
  }

  Future<List<MediaItem>> getNowPlaying() async {
    try {
      final nowPlaying = await tmdb.v3.movies.getNowPlaying(
        language: "en-US",
        region: "US",
        page: 2,
      );
      final results = List.from(nowPlaying['results'] ?? []);
      return results.map((e) => MediaItem.fromJson(e)).toList();
    } catch (e) {
      print(e);
      return [];
    }
  }

  Future<List<MediaItem>> TopRatedTv() async {
    try {
      Map result = await tmdb.v3.tv.getTopRated();
      List list = result['results'] ?? [];
      return list.map((json) => MediaItem.fromJson(json)).toList();
    } catch (e) {
      print(e);
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ FETCH TRENDING MOVIES
  // ---------------------------------------------------------------------------
  Future<List<MediaItem>> fetchTrendingMovie() async {
    try {
      Map result = await tmdb.v3.trending.getTrending(
        mediaType: MediaType.movie,
        timeWindow: TimeWindow.week,
        language: 'en-US',
      );

      List list = result['results'] ?? [];

      return list.map((json) => MediaItem.fromJson(json)).toList();
    } catch (e) {
      print("Error fetching trending movies: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ LOAD GENRES (MOVIE + TV)
  // ---------------------------------------------------------------------------
  Future<void> loadGenres() async {
    try {
      // Movie genres
      final movieGenres = await tmdb.v3.genres.getMovieList();
      // TV genres (⚠ correct function is getTvList)
      final tvGenres = await tmdb.v3.genres.getTvlist();

      List movieList = movieGenres['genres'] ?? [];
      List tvList = tvGenres['genres'] ?? [];

      // store all genres
      for (var g in movieList) {
        genreMap[g['id']] = g['name'];
      }
      for (var g in tvList) {
        genreMap[g['id']] = g['name'];
      }

      print("Loaded genres: $genreMap");
    } catch (e) {
      print("Genre load error: $e");
    }
  }

  Future<List<MediaItem>> fetchpopularMovies() async {
    try {
      Map result = await tmdb.v3.movies.getPopular();
      List list = result['results'] ?? [];
      return list
          .map((json) => MediaItem.fromJson(json).copyWith(mediaType: "movie"))
          .toList();
    } catch (e) {
      print("Genre load error: $e");
      return [];
    }
  }

  Future<List<MediaItem>> fetchUpcoming() async {
    try {
      Map result = await tmdb.v3.movies.getUpcoming();
      List list = result['results'] ?? [];
      return list
          .map((json) => MediaItem.fromJson(json).copyWith(mediaType: "movie"))
          .toList();
    } catch (e) {
      print("Genre load error: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ GET GENRE NAME BY ID
  // ---------------------------------------------------------------------------
  String getGenreName(int id) {
    return genreMap[id] ?? "Unknown";
  }

  // ---------------------------------------------------------------------------
  // ✅ GET LIST OF GENRE NAMES FOR A MOVIE/SHOW
  // ---------------------------------------------------------------------------
  List<String> getGenreNames(List<int> ids) {
    return ids.map((id) => getGenreName(id)).toList();
  }

  // ---------------------------------------------------------------------------
  // ✅ FETCH Movie Details
  // ---------------------------------------------------------------------------

  Future<MovieDetails> fetchMovieDetails(int movieId) async {
    try {
      final result = await tmdb.v3.movies.getDetails(
        movieId,
        appendToResponse: 'videos,credits,watch/providers',
      );

      // Cast Map<dynamic, dynamic> to Map<String, dynamic>
      final data = Map<String, dynamic>.from(result);

      return MovieDetails.fromJson(data);
    } catch (e) {
      print("Error fetching movie details: $e");
      rethrow;
    }
  }
  // ---------------------------------------------------------------------------
  // ✅ FETCH Shows Details
  // ---------------------------------------------------------------------------

  Future<TvShowDetails?> fetchDetailsTvShow(int showId) async {
    try {
      final result = await tmdb.v3.tv.getDetails(
        showId,
        appendToResponse: 'videos,credits,watch/providers',
      );
      final data = Map<String, dynamic>.from(result);
      return TvShowDetails.fromJson(data);
    } catch (e) {
      print("Error fetching TV show details: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ FETCH Streaming Details
  // ---------------------------------------------------------------------------

  Future<WatchProvidersResponse> fetchStreamingDetails(String showId) async {
    try {
      final result = await tmdb.v3.tv.getWatchProviders(showId);
      final data = Map<String, dynamic>.from(result);
      return WatchProvidersResponse.fromJson(data);
    } catch (e) {
      print("Error fetching streaming details: $e");
      rethrow;
    }
  }

  Future<WatchProvidersResponse> fetchStreamingDetailsMovie(int movieId) async {
    try {
      final result = await tmdb.v3.movies.getWatchProviders(movieId);

      // Ensure result is a Map
      if (result is Map<String, dynamic>) {
        return WatchProvidersResponse.fromJson(result);
      } else {
        throw Exception("Invalid data format received from TMDB API");
      }
    } catch (e) {
      print("Error fetching streaming details: $e");
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ FETCH RELATED MOVIES
  // ---------------------------------------------------------------------------
  Future<List<MediaItem>> fetchRelatedMovies(int movieId) async {
    try {
      final result = await tmdb.v3.movies.getSimilar(movieId);
      List list = result['results'] ?? [];
      return list
          .map((json) => MediaItem.fromJson(json).copyWith(mediaType: "movie"))
          .toList();
    } catch (e) {
      print("Error fetching related movies: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ FETCH RELATED TV SHOWS
  // ---------------------------------------------------------------------------
  Future<List<MediaItem>> fetchRelatedTVShows(int showId) async {
    try {
      final result = await tmdb.v3.tv.getSimilar(showId);
      List list = result['results'] ?? [];
      return list
          .map((json) => MediaItem.fromJson(json).copyWith(mediaType: "tv"))
          .toList();
    } catch (e) {
      print("Error fetching related TV shows: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ FETCH SEASON DETAILS
  // ---------------------------------------------------------------------------
  Future<SeasonDetail?> fetchSeasonDetails(int tvId, int seasonNumber) async {
    try {
      final result = await tmdb.v3.tvSeasons.getDetails(tvId, seasonNumber);
      final data = Map<String, dynamic>.from(result);
      return SeasonDetail.fromJson(data);
    } catch (e) {
      print("Error fetching season details: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ FETCH EPISODE DETAILS
  // ---------------------------------------------------------------------------
  Future<Episode?> fetchEpisodeDetails(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    try {
      final result = await tmdb.v3.tvEpisodes.getDetails(
        tvId,
        seasonNumber,
        episodeNumber,
        appendToResponse: 'credits,videos,images',
      );
      final data = Map<String, dynamic>.from(result);
      return Episode.fromJson(data);
    } catch (e) {
      print("Error fetching episode details: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ PAGINATED FETCH METHODS FOR SEE ALL SCREEN
  // ---------------------------------------------------------------------------

  Future<List<MediaItem>> fetchTrendingMoviePaginated(int page) async {
    try {
      Map result = await tmdb.v3.trending.getTrending(
        mediaType: MediaType.movie,
        timeWindow: TimeWindow.week,
        language: 'en-US',
        page: page,
      );
      List list = result['results'] ?? [];
      return list.map((json) => MediaItem.fromJson(json)).toList();
    } catch (e) {
      print("Error fetching trending movies page $page: $e");
      return [];
    }
  }

  Future<List<MediaItem>> fetchTrendingShowPaginated(int page) async {
    try {
      Map result = await tmdb.v3.trending.getTrending(
        mediaType: MediaType.tv,
        timeWindow: TimeWindow.week,
        language: 'en-US',
        page: page,
      );
      List list = result['results'] ?? [];
      return list.map((json) => MediaItem.fromJson(json)).toList();
    } catch (e) {
      print("Error fetching trending shows page $page: $e");
      return [];
    }
  }

  Future<List<MediaItem>> fetchPopularMoviesPaginated(int page) async {
    try {
      Map result = await tmdb.v3.movies.getPopular(page: page);
      List list = result['results'] ?? [];
      return list
          .map((json) => MediaItem.fromJson(json).copyWith(mediaType: "movie"))
          .toList();
    } catch (e) {
      print("Error fetching popular movies page $page: $e");
      return [];
    }
  }

  Future<List<MediaItem>> getNowPlayingPaginated(int page) async {
    try {
      final result = await tmdb.v3.movies.getNowPlaying(
        language: "en-US",
        region: "US",
        page: page,
      );
      final results = List.from(result['results'] ?? []);
      return results
          .map((e) => MediaItem.fromJson(e).copyWith(mediaType: "movie"))
          .toList();
    } catch (e) {
      print("Error fetching now playing page $page: $e");
      return [];
    }
  }

  Future<List<MediaItem>> fetchUpcomingPaginated(int page) async {
    try {
      Map result = await tmdb.v3.movies.getUpcoming(page: page);
      List list = result['results'] ?? [];
      return list
          .map((json) => MediaItem.fromJson(json).copyWith(mediaType: "movie"))
          .toList();
    } catch (e) {
      print("Error fetching upcoming page $page: $e");
      return [];
    }
  }

  Future<List<MediaItem>> fetchAiringTodayPaginated(int page) async {
    try {
      Map result = await tmdb.v3.tv.getAiringToday(page: page);
      List list = result['results'] ?? [];
      return list
          .map((json) => MediaItem.fromJson(json).copyWith(mediaType: "tv"))
          .toList();
    } catch (e) {
      print("Error fetching airing today page $page: $e");
      return [];
    }
  }

  Future<List<MediaItem>> fetchTopRatedTvPaginated(int page) async {
    try {
      Map result = await tmdb.v3.tv.getTopRated(page: page);
      List list = result['results'] ?? [];
      return list
          .map((json) => MediaItem.fromJson(json).copyWith(mediaType: "tv"))
          .toList();
    } catch (e) {
      print("Error fetching top rated TV page $page: $e");
      return [];
    }
  }

  Future<List<MediaItem>> fetchDiscoverPaginated(int page) async {
    try {
      Map result = await tmdb.v3.discover.getMovies(page: page);
      List list = result['results'] ?? [];
      return list
          .map((json) => MediaItem.fromJson(json).copyWith(mediaType: "movie"))
          .toList();
    } catch (e) {
      print("Error fetching discover page $page: $e");
      return [];
    }
  }

  Future<List<MediaItem>> searchMedia(String query) async {
    try {
      Map result = await tmdb.v3.search.queryMulti(
        query,
        language: 'en-US',
        includeAdult: false,
      );
      List list = result['results'] ?? [];
      return list
          .where((item) => item['media_type'] == 'tv' || item['media_type'] == 'movie')
          .map((json) => MediaItem.fromJson(json))
          .toList();
    } catch (e) {
      print("Error searching media: $e");
      return [];
    }
  }
}
