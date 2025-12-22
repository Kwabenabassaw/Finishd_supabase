import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:finishd/db/app_database.dart';

class StreamingCacheService {
  static const String _table = 'streaming_cache';
  static const int _ttlHours = 24;

  /// Get cached streaming availability for a movie or TV show
  static Future<Map<String, dynamic>?> getStreamingAvailability(
    String tmdbId,
  ) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(_table, where: 'id = ?', whereArgs: [tmdbId]);

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _ttlHours * 60 * 60 * 1000;

      if (currentTime - timestamp < ttlMillis) {
        try {
          return jsonDecode(row['json'] as String) as Map<String, dynamic>;
        } catch (e) {
          print('Error decoding streaming cache for $tmdbId: $e');
          return null;
        }
      } else {
        // Expired
        await clear(tmdbId);
        return null;
      }
    }
    return null;
  }

  /// Save streaming availability data to SQLite
  static Future<void> saveStreamingAvailability(
    String tmdbId,
    Map<String, dynamic> data,
  ) async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      final jsonStr = jsonEncode(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      try {
        await db.insert(_table, {
          'id': tmdbId,
          'json': jsonStr,
          'timestamp': timestamp,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        print('Error saving streaming cache for $tmdbId: $e');
      }
    });
  }

  /// Clear cache for a specific item
  static Future<void> clear(String tmdbId) async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      try {
        await db.delete(_table, where: 'id = ?', whereArgs: [tmdbId]);
      } catch (e) {
        print('Error clearing streaming cache for $tmdbId: $e');
      }
    });
  }

  /// Clear all streaming cache entries
  /// Useful for forcing a refresh of all streaming data
  static Future<void> clearAll() async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      try {
        final count = await db.delete(_table);
        print('🗑️ Cleared $count streaming cache entries');
      } catch (e) {
        print('Error clearing all streaming cache: $e');
      }
    });
  }
}
