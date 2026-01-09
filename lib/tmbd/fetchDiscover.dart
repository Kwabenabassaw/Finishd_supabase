import 'package:finishd/Model/trending.dart';
import 'package:tmdb_api/tmdb_api.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
      Map movieData = await tmdb.v3.discover.getMovies(page: 5);
      Map tvData = await tmdb.v3.discover.getTvShows(page: 5);

      // Map movie results to MediaItem
      List<MediaItem> movies =
          (movieData['results'] as List<dynamic>?)
              ?.map((item) => MediaItem.fromJson(item, type: 'movie'))
              .toList() ??
          [];

      // Map TV results to MediaItem
      List<MediaItem> tvShows =
          (tvData['results'] as List<dynamic>?)
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

  Future<List<MediaItem>> fetchContentByProvider(
    int providerId, {
    int page = 1,
    String? sortBy = 'popularity.desc',
  }) async {
    const apiKey = '829afd9e186fc15a71a6dfe50f3d00ad';

    // Fetch Movies
    final movieResponse = await http.get(
      Uri.parse(
        'https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_watch_providers=$providerId&watch_region=US&sort_by=$sortBy&page=$page',
      ),
    );

    // Fetch TV Shows
    final tvResponse = await http.get(
      Uri.parse(
        'https://api.themoviedb.org/3/discover/tv?api_key=$apiKey&with_watch_providers=$providerId&watch_region=US&sort_by=$sortBy&page=$page',
      ),
    );

    List<MediaItem> content = [];

    if (movieResponse.statusCode == 200) {
      final decodedData = json.decode(movieResponse.body)['results'] as List;
      content.addAll(
        decodedData.map((m) => MediaItem.fromJson(m, type: 'movie')),
      );
    }

    if (tvResponse.statusCode == 200) {
      final decodedData = json.decode(tvResponse.body)['results'] as List;
      content.addAll(decodedData.map((m) => MediaItem.fromJson(m, type: 'tv')));
    }

    // Shuffle only for the default discovery, otherwise keep the sort order (e.g., for popularity or date)
    if (sortBy == 'popularity.desc' && page == 1) {
      // Keep order if we want Top 10 to be consistent
    } else {
      content.shuffle();
    }

    return content;
  }

  Future<MediaItem?> fetchHeroContent(int providerId) async {
    final results = await fetchContentByProvider(
      providerId,
      sortBy: 'popularity.desc',
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<List<MediaItem>> fetchTop10(int providerId) async {
    final results = await fetchContentByProvider(
      providerId,
      sortBy: 'popularity.desc',
    );
    return results.take(10).toList();
  }

  Future<List<MediaItem>> fetchNewArrivals(int providerId) async {
    final results = await fetchContentByProvider(
      providerId,
      sortBy: 'primary_release_date.desc',
    );
    return results;
  }

  /// Fetch trending content (based on popularity)
  Future<List<MediaItem>> fetchTrending(int providerId) async {
    final results = await fetchContentByProvider(
      providerId,
      sortBy: 'popularity.desc',
      page: 2, // Different page for variety
    );
    return results;
  }

  /// Fetch award-winning content (high vote average)
  Future<List<MediaItem>> fetchAwardWinning(int providerId) async {
    final results = await fetchContentByProvider(
      providerId,
      sortBy: 'vote_average.desc',
    );
    // Filter for items with high vote count to ensure quality
    return results
        .where((item) => item.voteCount > 500 && item.voteAverage > 7.5)
        .toList();
  }

  /// Fetch content by genre
  Future<List<MediaItem>> fetchByGenre(
    int providerId,
    int genreId, {
    String? mediaType,
  }) async {
    const apiKey = '829afd9e186fc15a71a6dfe50f3d00ad';
    List<MediaItem> content = [];

    if (mediaType == null || mediaType == 'movie') {
      final movieResponse = await http.get(
        Uri.parse(
          'https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_watch_providers=$providerId&watch_region=US&with_genres=$genreId&sort_by=popularity.desc',
        ),
      );
      if (movieResponse.statusCode == 200) {
        final decodedData = json.decode(movieResponse.body)['results'] as List;
        content.addAll(
          decodedData.map((m) => MediaItem.fromJson(m, type: 'movie')),
        );
      }
    }

    if (mediaType == null || mediaType == 'tv') {
      final tvResponse = await http.get(
        Uri.parse(
          'https://api.themoviedb.org/3/discover/tv?api_key=$apiKey&with_watch_providers=$providerId&watch_region=US&with_genres=$genreId&sort_by=popularity.desc',
        ),
      );
      if (tvResponse.statusCode == 200) {
        final decodedData = json.decode(tvResponse.body)['results'] as List;
        content.addAll(
          decodedData.map((m) => MediaItem.fromJson(m, type: 'tv')),
        );
      }
    }

    content.shuffle();
    return content;
  }

  /// Fetch High School / Teen content (using keywords)
  Future<List<MediaItem>> fetchHighSchool(int providerId) async {
    const apiKey = '829afd9e186fc15a71a6dfe50f3d00ad';
    // TMDB keyword IDs for high school content
    const highSchoolKeywords =
        '9826|210024|6091'; // high school, teenager, coming of age

    List<MediaItem> content = [];

    final movieResponse = await http.get(
      Uri.parse(
        'https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_watch_providers=$providerId&watch_region=US&with_keywords=$highSchoolKeywords&sort_by=popularity.desc',
      ),
    );
    if (movieResponse.statusCode == 200) {
      final decodedData = json.decode(movieResponse.body)['results'] as List;
      content.addAll(
        decodedData.map((m) => MediaItem.fromJson(m, type: 'movie')),
      );
    }

    final tvResponse = await http.get(
      Uri.parse(
        'https://api.themoviedb.org/3/discover/tv?api_key=$apiKey&with_watch_providers=$providerId&watch_region=US&with_keywords=$highSchoolKeywords&sort_by=popularity.desc',
      ),
    );
    if (tvResponse.statusCode == 200) {
      final decodedData = json.decode(tvResponse.body)['results'] as List;
      content.addAll(decodedData.map((m) => MediaItem.fromJson(m, type: 'tv')));
    }

    content.shuffle();
    return content;
  }
}
