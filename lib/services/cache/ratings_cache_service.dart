import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:finishd/db/app_database.dart';

class RatingsCacheService {
  static const String _table = 'ratings_cache';
  static const int _ttlDays = 30;

  /// Get cached ratings for a movie
  static Future<Map<String, dynamic>?> getRatings(String movieId) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      _table,
      where: 'movieId = ?',
      whereArgs: [movieId],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _ttlDays * 24 * 60 * 60 * 1000;

      if (currentTime - timestamp < ttlMillis) {
        try {
          if (row['json'] != null) {
            return jsonDecode(row['json'] as String) as Map<String, dynamic>;
          }
           // Fallback if we just stored fields but no full JSON blob (though requirement says json column exists)
           return {
             'imdbRating': row['imdbRating'],
             'metascore': row['metascore'],
             'tomatoRating': row['tomatoRating'],
           };
        } catch (e) {
          print('Error decoding ratings cache for $movieId: $e');
          return null;
        }
      } else {
        // Expired
        await clear(movieId);
        return null;
      }
    }
    return null;
  }

  /// Save ratings (runs in microtask)
  static Future<void> saveRatings(String movieId, Map<String, dynamic> data) async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      final jsonStr = jsonEncode(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      try {
        await db.insert(
          _table,
          {
            'movieId': movieId,
            'imdbRating': data['imdbRating']?.toString(), // Handle potential numbers
            'metascore': data['Metascore']?.toString() ?? data['metascore']?.toString(), // Handle case variations
            'tomatoRating': data['tomatoRating']?.toString(),
            'json': jsonStr,
            'timestamp': timestamp,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        print('Error saving ratings cache for $movieId: $e');
      }
    });
  }

  /// Clear ratings for specific movie
  static Future<void> clear(String movieId) async {
    await Future.microtask(() async {
      final db = await AppDatabase.instance.database;
      await db.delete(
        _table,
        where: 'movieId = ?',
        whereArgs: [movieId],
      );
    });
  }
}
