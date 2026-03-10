import 'package:dio/dio.dart';
import 'package:finishd/models/simkl/simkl_models.dart';

class SimklService {
  final Dio _dio;

  SimklService({Dio? dio}) : _dio = dio ?? Dio(
    BaseOptions(
      baseUrl: 'https://api.simkl.com',
      headers: {
        'simkl-api-key': const String.fromEnvironment('simkl', defaultValue: ''),
        'Content-Type': 'application/json',
      },
    ),
  );

  /// Fetch TV Calendar (returns upcoming episodes for 30 days)
  Future<List<ShowRelease>> fetchTvCalendar() async {
    try {
      final response = await _dio.get('/tv/calendar');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          // Try to handle both flat structure (as per prompt) and nested 'show' structure
          final showTitle = json['title'] ?? json['show']?['title'] ?? '';
          final date = json['aired'] ?? json['date'] ?? '';

          int? episode;
          int? season;

          if (json['episode'] is Map) {
            episode = json['episode']['episode'];
            season = json['episode']['season'];
          } else {
            episode = json['episode'];
            season = json['season'];
          }

          int? tmdbId;
          final ids = json['ids'] ?? json['show']?['ids'];
          if (ids != null && ids['tmdb'] != null) {
            tmdbId = int.tryParse(ids['tmdb'].toString());
          }

          return ShowRelease(
            title: showTitle,
            season: season,
            episode: episode,
            date: date,
            tmdbId: tmdbId,
            isMovie: false,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching TV Calendar from SIMKL: $e');
      return [];
    }
  }

  /// Fetch Trending TV Shows
  Future<List<ShowRelease>> fetchTrendingTv() async {
    try {
      final response = await _dio.get('/tv/trending');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final showTitle = json['title'] ?? '';
          int? tmdbId;
          if (json['ids']?['tmdb'] != null) {
            tmdbId = int.tryParse(json['ids']['tmdb'].toString());
          }
          return ShowRelease(
            title: showTitle,
            date: DateTime.now().toIso8601String().split('T')[0], // For trending, we use today's date
            tmdbId: tmdbId,
            isMovie: false,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching Trending TV from SIMKL: $e');
      return [];
    }
  }

  /// Fetch Trending Movies
  Future<List<ShowRelease>> fetchTrendingMovies() async {
    try {
      final response = await _dio.get('/movies/trending');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final showTitle = json['title'] ?? '';
          int? tmdbId;
          if (json['ids']?['tmdb'] != null) {
            tmdbId = int.tryParse(json['ids']['tmdb'].toString());
          }
          return ShowRelease(
            title: showTitle,
            date: DateTime.now().toIso8601String().split('T')[0],
            tmdbId: tmdbId,
            isMovie: true,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching Trending Movies from SIMKL: $e');
      return [];
    }
  }
}
