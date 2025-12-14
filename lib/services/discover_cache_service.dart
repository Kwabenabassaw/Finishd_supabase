import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:finishd/db/app_database.dart';
import 'package:finishd/Model/trending.dart';

/// Service to cache Discover page data in SQLite with 6-hour TTL
class DiscoverCacheService {
  static const String _table = 'trending_cache';
  static const int _ttlHours = 6; // Cache valid for 6 hours

  // Cache keys for each category
  static const String keyTrendingMovies = 'discover_trending_movies';
  static const String keyTrendingShows = 'discover_trending_shows';
  static const String keyPopular = 'discover_popular';
  static const String keyNowPlaying = 'discover_now_playing';
  static const String keyUpcoming = 'discover_upcoming';
  static const String keyAiringToday = 'discover_airing_today';
  static const String keyTopRatedTv = 'discover_top_rated_tv';
  static const String keyDiscover = 'discover_discover';

  /// Get cached data for a category
  Future<List<MediaItem>?> getCached(String key) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(_table, where: 'id = ?', whereArgs: [key]);

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _ttlHours * 60 * 60 * 1000;

      if (currentTime - timestamp < ttlMillis) {
        try {
          final jsonStr = row['json'] as String;
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          return jsonList.map((e) => MediaItem.fromJson(e)).toList();
        } catch (e) {
          print('Error parsing cached discover data: $e');
          // Delete corrupted cache
          await db.delete(_table, where: 'id = ?', whereArgs: [key]);
        }
      } else {
        // Expired, delete
        await db.delete(_table, where: 'id = ?', whereArgs: [key]);
      }
    }
    return null;
  }

  /// Save data to cache
  Future<void> saveToCache(String key, List<MediaItem> items) async {
    final db = await AppDatabase.instance.database;
    final jsonList = items.map((e) => e.toJson()).toList();
    final jsonStr = jsonEncode(jsonList);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.insert(_table, {
      'id': key,
      'type': 'discover',
      'json': jsonStr,
      'timestamp': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Clear all discover cache
  Future<void> clearCache() async {
    final db = await AppDatabase.instance.database;
    await db.delete(_table, where: 'id LIKE ?', whereArgs: ['discover_%']);
  }

  /// Check if cache is valid (not expired)
  Future<bool> isCacheValid(String key) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(_table, where: 'id = ?', whereArgs: [key]);

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _ttlHours * 60 * 60 * 1000;
      return currentTime - timestamp < ttlMillis;
    }
    return false;
  }
}
