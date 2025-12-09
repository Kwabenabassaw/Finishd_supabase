import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:finishd/db/app_database.dart';

class FeedCacheService {
  static const String _table = 'feed_cache';
  static const String _feedId = 'feed';
  static const int _ttlHours = 24;

  /// Alias for getCachedFeed (for API consistency)
  static Future<List<Map<String, dynamic>>?> getFeed() async {
    final result = await getCachedFeed();
    return result?.cast<Map<String, dynamic>>();
  }

  /// Get cached feed if valid
  static Future<List<dynamic>?> getCachedFeed() async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [_feedId],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _ttlHours * 60 * 60 * 1000;

      // Check TTL
      if (currentTime - timestamp < ttlMillis) {
        final jsonStr = row['json'] as String;
        try {
          return jsonDecode(jsonStr) as List<dynamic>;
        } catch (e) {
          print('Error decoding feed cache: $e');
          return null;
        }
      } else {
        // Expired
        await clearFeed();
        return null;
      }
    }

    return null;
  }

  /// Save feed to cache (runs in microtask/non-blocking)
  static Future<void> saveFeed(List<dynamic> feed) async {
    await Future.microtask(() async {
      await _writeToDb(feed);
    });
  }

  /// Append to feed cache
  static Future<void> appendFeed(List<dynamic> newItems) async {
    await Future.microtask(() async {
      final current = await getCachedFeed() ?? [];

      // Create a set of existing IDs for deduplication
      final existingIds = <String>{};
      for (var item in current) {
        final id =
            item['id']?.toString() ??
            item['youtubeKey'] ??
            item['tmdbId']?.toString();
        if (id != null) existingIds.add(id);
      }

      // Filter new items that aren't already in cache
      final uniqueNew = <dynamic>[];
      for (var item in newItems) {
        final id =
            item['id']?.toString() ??
            item['youtubeKey'] ??
            item['tmdbId']?.toString();
        if (id == null || !existingIds.contains(id)) {
          uniqueNew.add(item);
          if (id != null) existingIds.add(id);
        }
      }

      if (uniqueNew.isEmpty) return;

      // Append
      final updatedFeed = [...current, ...uniqueNew];

      // Limit size (Remove old ones from start if > 100)
      if (updatedFeed.length > 100) {
        updatedFeed.removeRange(0, updatedFeed.length - 100);
      }

      await _writeToDb(updatedFeed);
    });
  }

  static Future<void> _writeToDb(List<dynamic> feed) async {
    final db = await AppDatabase.instance.database;
    final jsonStr = jsonEncode(feed);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.insert(_table, {
        'id': _feedId,
        'json': jsonStr,
        'timestamp': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error saving feed cache: $e');
    }
  }

  /// Clear feed cache
  static Future<void> clearFeed() async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      await db.delete(_table, where: 'id = ?', whereArgs: [_feedId]);
    });
  }
}
