import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:finishd/db/app_database.dart';
import 'package:finishd/Model/recommendation_model.dart';

/// Hybrid cache service for recommendations
/// Stores ALL received recommendations locally and only listens for NEW ones
class RecommendationCacheService {
  // =========================================================================
  // RECOMMENDATIONS CACHE
  // =========================================================================

  /// Get all cached recommendations for a user
  static Future<List<Recommendation>> getLocalRecommendations(
    String userId,
  ) async {
    final db = await AppDatabase.instance.database;

    try {
      final result = await db.query(
        'recommendations_received_cache',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'timestamp DESC',
      );

      if (result.isEmpty) return [];

      final recommendations = <Recommendation>[];
      for (final row in result) {
        try {
          final jsonStr = row['recommendation_data'] as String;
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final recId = row['recommendation_id'] as String;
          recommendations.add(Recommendation.fromMap(data, recId));
        } catch (e) {
          print('Error decoding recommendation: $e');
        }
      }

      return recommendations;
    } catch (e) {
      print('Error getting local recommendations: $e');
      return [];
    }
  }

  /// Append a single new recommendation to cache
  static Future<void> appendRecommendation(
    String userId,
    Recommendation rec,
  ) async {
    final db = await AppDatabase.instance.database;

    try {
      final jsonStr = jsonEncode(rec.toMap());
      await db.insert(
        'recommendations_received_cache',
        {
          'user_id': userId,
          'recommendation_id': rec.id,
          'recommendation_data': jsonStr,
          'timestamp': rec.timestamp.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error appending recommendation: $e');
    }
  }

  /// Batch save recommendations (for initial sync)
  static Future<void> saveRecommendations(
    String userId,
    List<Recommendation> recommendations,
  ) async {
    if (recommendations.isEmpty) return;

    final db = await AppDatabase.instance.database;

    try {
      final batch = db.batch();

      for (final rec in recommendations) {
        final jsonStr = jsonEncode(rec.toMap());
        batch.insert(
          'recommendations_received_cache',
          {
            'user_id': userId,
            'recommendation_id': rec.id,
            'recommendation_data': jsonStr,
            'timestamp': rec.timestamp.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      print('Error saving recommendations batch: $e');
    }
  }

  /// Mark a recommendation as seen (update in cache)
  static Future<void> markAsSeenLocally(String recommendationId) async {
    final db = await AppDatabase.instance.database;

    try {
      final result = await db.query(
        'recommendations_received_cache',
        where: 'recommendation_id = ?',
        whereArgs: [recommendationId],
      );

      if (result.isNotEmpty) {
        final jsonStr = result.first['recommendation_data'] as String;
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        data['status'] = 'seen';

        await db.update(
          'recommendations_received_cache',
          {'recommendation_data': jsonEncode(data)},
          where: 'recommendation_id = ?',
          whereArgs: [recommendationId],
        );
      }
    } catch (e) {
      print('Error marking as seen locally: $e');
    }
  }

  // =========================================================================
  // SYNC STATUS TRACKING
  // =========================================================================

  /// Get last sync timestamp for a user
  static Future<DateTime?> getLastSyncTime(String userId) async {
    final db = await AppDatabase.instance.database;

    try {
      final result = await db.query(
        'recommendation_sync_status',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      if (result.isEmpty) return null;

      final timestamp = result.first['last_sync_timestamp'] as int;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      print('Error getting last sync time: $e');
      return null;
    }
  }

  /// Update last sync timestamp
  static Future<void> updateLastSyncTime(
    String userId,
    DateTime syncTime,
  ) async {
    final db = await AppDatabase.instance.database;

    try {
      await db.insert('recommendation_sync_status', {
        'user_id': userId,
        'last_sync_timestamp': syncTime.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error updating last sync time: $e');
    }
  }

  // =========================================================================
  // CACHE MANAGEMENT
  // =========================================================================

  /// Clear all recommendations for a user
  static Future<void> clearUserRecommendations(String userId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'recommendations_received_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'recommendation_sync_status',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Clear all recommendation caches
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('recommendations_received_cache');
    await db.delete('recommendation_sync_status');
  }
}
