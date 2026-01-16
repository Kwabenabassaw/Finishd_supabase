import 'package:sqflite/sqflite.dart';
import 'package:finishd/db/app_database.dart';

/// Cache service for movie lists sync tracking
/// Manages timestamps for hybrid streaming approach
class MovieListCacheService {
  // =========================================================================
  // SYNC TIMESTAMP TRACKING
  // =========================================================================

  /// Get last sync time for a user's specific list
  static Future<DateTime?> getLastSyncTime(
    String userId,
    String listType,
  ) async {
    final db = await AppDatabase.instance.database;

    try {
      final result = await db.query(
        'movie_list_sync_status',
        where: 'user_id = ? AND list_type = ?',
        whereArgs: [userId, listType],
      );

      if (result.isEmpty) return null;

      final timestamp = result.first['last_sync_timestamp'] as int;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      print('Error getting last sync time: $e');
      return null;
    }
  }

  /// Update last sync timestamp for a user's list
  static Future<void> updateLastSyncTime(
    String userId,
    String listType,
    DateTime syncTime,
  ) async {
    final db = await AppDatabase.instance.database;

    try {
      await db.insert('movie_list_sync_status', {
        'user_id': userId,
        'list_type': listType,
        'last_sync_timestamp': syncTime.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error updating last sync time: $e');
    }
  }

  /// Clear sync status for a specific list (forces refresh)
  static Future<void> clearSyncStatus(String userId, String listType) async {
    final db = await AppDatabase.instance.database;

    try {
      await db.delete(
        'movie_list_sync_status',
        where: 'user_id = ? AND list_type = ?',
        whereArgs: [userId, listType],
      );
    } catch (e) {
      print('Error clearing sync status: $e');
    }
  }

  /// Clear all sync status for a user
  static Future<void> clearAllSyncStatus(String userId) async {
    final db = await AppDatabase.instance.database;

    try {
      await db.delete(
        'movie_list_sync_status',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error clearing all sync status: $e');
    }
  }

  /// Clear all movie list sync data
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('movie_list_sync_status');
  }
}
