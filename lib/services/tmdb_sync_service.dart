import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:tmdb_api/tmdb_api.dart';
import 'package:finishd/db/app_database.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';

class TmdbSyncService {
  static const String _table = 'tmdb_cache';
  static const int _ttlHours = 48; // Cache valid for 48 hours

  // Reuse the keys from fetchtrending.dart (Ideally these should be in a config file)
  final TMDB tmdb = TMDB(
    ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
  );

  /// Get Movie Details, trying cache first
  Future<MovieDetails?> getMovieDetails(int id) async {
    final cacheKey = 'movie_$id';

    // 1. Try Cache
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null && cachedData.containsKey('watch/providers')) {
      try {
        return MovieDetails.fromJson(cachedData);
      } catch (e) {
        print('Error parsing cached movie details: $e');
      }
    }

    // 2. Fetch from Network
    try {
      final result =
          await tmdb.v3.movies.getDetails(
                id,
                appendToResponse: 'videos,credits,watch/providers',
              )
              as Map<String, dynamic>;

      await _saveToCache(cacheKey, 'movie', result);
      return MovieDetails.fromJson(result);
    } catch (e) {
      print('Error fetching movie details: $e');
      return null;
    }
  }

  /// Get TV Show Details, trying cache first
  Future<TvShowDetails?> getTvShowDetails(int id) async {
    final cacheKey = 'tv_$id';

    // 1. Try Cache
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null && cachedData.containsKey('watch/providers')) {
      try {
        return TvShowDetails.fromJson(cachedData);
      } catch (e) {
        print('Error parsing cached tv details: $e');
      }
    }

    // 2. Fetch from Network
    try {
      final result =
          await tmdb.v3.tv.getDetails(
                id,
                appendToResponse: 'videos,credits,watch/providers',
              )
              as Map<String, dynamic>;

      await _saveToCache(cacheKey, 'tv', result);
      return TvShowDetails.fromJson(result);
    } catch (e) {
      print('Error fetching tv details: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getFromCache(String id) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(_table, where: 'id = ?', whereArgs: [id]);

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _ttlHours * 60 * 60 * 1000;

      if (currentTime - timestamp < ttlMillis) {
        final jsonStr = row['json'] as String;
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      } else {
        // Expired
        await db.delete(_table, where: 'id = ?', whereArgs: [id]);
      }
    }
    return null;
  }

  Future<void> _saveToCache(
    String id,
    String type,
    Map<String, dynamic> data,
  ) async {
    final db = await AppDatabase.instance.database;
    final jsonStr = jsonEncode(data);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.insert(_table, {
      'id': id,
      'type': type,
      'json': jsonStr,
      'timestamp': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
