import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:finishd/db/app_database.dart';

/// SQLite cache service for notifications.
/// Provides instant notification loading on app open.
class NotificationCacheService {
  static const String _table = 'notifications_cache';
  static const int _ttlMinutes = 30; // Cache valid for 30 mins

  /// Get cached notifications by type
  /// Types: 'all', 'tv', 'episodes', 'recommendations'
  static Future<List<Map<String, dynamic>>?> getNotifications(
    String type,
  ) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(_table, where: 'type = ?', whereArgs: [type]);

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _ttlMinutes * 60 * 1000;

      if (currentTime - timestamp < ttlMillis) {
        final jsonStr = row['json'] as String;
        try {
          final decoded = jsonDecode(jsonStr) as List<dynamic>;
          return decoded.cast<Map<String, dynamic>>();
        } catch (e) {
          print('❌ Error decoding notification cache for $type: $e');
          return null;
        }
      } else {
        // Expired
        print('📦 Notification cache expired for $type');
        await clearNotifications(type);
        return null;
      }
    }
    return null;
  }

  /// Save notifications to cache
  static Future<void> saveNotifications(String type, List<dynamic> data) async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      final jsonStr = jsonEncode(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      try {
        await db.insert(_table, {
          'id': type, // Using type as ID for uniqueness
          'type': type,
          'json': jsonStr,
          'timestamp': timestamp,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        print('📦 Cached ${data.length} notifications for type: $type');
      } catch (e) {
        print('❌ Error saving notification cache for $type: $e');
      }
    });
  }

  /// Clear notification cache for specific type
  static Future<void> clearNotifications(String type) async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      await db.delete(_table, where: 'type = ?', whereArgs: [type]);
    });
  }

  /// Clear all notification caches
  static Future<void> clearAll() async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      await db.delete(_table);
      print('📦 Cleared all notification caches');
    });
  }

  /// Check if we have valid cached notifications
  static Future<bool> hasCachedNotifications(String type) async {
    final cached = await getNotifications(type);
    return cached != null && cached.isNotEmpty;
  }
}
