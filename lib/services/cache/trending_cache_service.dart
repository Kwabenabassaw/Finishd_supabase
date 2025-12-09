import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:finishd/db/app_database.dart';

class TrendingCacheService {
  static const String _table = 'trending_cache';
  static const int _ttlHours = 24;

  /// Get cached trending items by type ('movie' or 'tv')
  static Future<List<dynamic>?> getTrending(String type) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      _table,
      where: 'type = ?',
      whereArgs: [type],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _ttlHours * 60 * 60 * 1000;

      if (currentTime - timestamp < ttlMillis) {
        final jsonStr = row['json'] as String;
        try {
          return jsonDecode(jsonStr) as List<dynamic>;
        } catch (e) {
          print('Error decoding trending cache for $type: $e');
          return null;
        }
      } else {
        // Expired
        await clearTrending(type);
        return null;
      }
    }
    return null;
  }

  /// Save trending items (runs in microtask)
  static Future<void> saveTrending(String type, List<dynamic> data) async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      final jsonStr = jsonEncode(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      try {
        // We use type as ID to ensure one row per type
        await db.insert(
          _table,
          {
            'id': type, // Using type as ID for uniqueness per type
            'type': type,
            'json': jsonStr,
            'timestamp': timestamp,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        print('Error saving trending cache for $type: $e');
      }
    });
  }

  /// Clear trending cache for specific type
  static Future<void> clearTrending(String type) async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      await db.delete(
        _table,
        where: 'type = ?',
        whereArgs: [type],
      );
    });
  }
}
