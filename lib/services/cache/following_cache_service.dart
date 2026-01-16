import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:finishd/db/app_database.dart';
import 'package:finishd/Model/user_model.dart';

/// SQLite cache service for social graph data
/// - Following IDs: 24h TTL
/// - Followers IDs: 24h TTL
/// - User Profiles: 7 day TTL
class FollowingCacheService {
  static const int _followingTtlHours = 24;
  static const int _followersTtlHours = 24;
  static const int _profileTtlDays = 7;

  // =========================================================================
  // FOLLOWING CACHE
  // =========================================================================

  /// Get cached following IDs for a user (24h TTL)
  static Future<List<String>?> getFollowingIds(String userId) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'following_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _followingTtlHours * 60 * 60 * 1000;

      // Check TTL
      if (currentTime - timestamp < ttlMillis) {
        final jsonStr = row['following_ids'] as String;
        try {
          final List<dynamic> decoded = jsonDecode(jsonStr);
          return decoded.cast<String>();
        } catch (e) {
          print('Error decoding following cache: $e');
          return null;
        }
      } else {
        // Expired - delete
        await invalidateFollowing(userId);
        return null;
      }
    }

    return null;
  }

  /// Save following IDs to cache
  static Future<void> saveFollowingIds(
    String userId,
    List<String> followingIds,
  ) async {
    final db = await AppDatabase.instance.database;
    final jsonStr = jsonEncode(followingIds);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.insert('following_cache', {
        'user_id': userId,
        'following_ids': jsonStr,
        'timestamp': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error saving following cache: $e');
    }
  }

  /// Invalidate following cache for a user
  static Future<void> invalidateFollowing(String userId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'following_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // =========================================================================
  // FOLLOWERS CACHE
  // =========================================================================

  /// Get cached followers IDs for a user (24h TTL)
  static Future<List<String>?> getFollowersIds(String userId) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'followers_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _followersTtlHours * 60 * 60 * 1000;

      // Check TTL
      if (currentTime - timestamp < ttlMillis) {
        final jsonStr = row['follower_ids'] as String;
        try {
          final List<dynamic> decoded = jsonDecode(jsonStr);
          return decoded.cast<String>();
        } catch (e) {
          print('Error decoding followers cache: $e');
          return null;
        }
      } else {
        // Expired - delete
        await invalidateFollowers(userId);
        return null;
      }
    }

    return null;
  }

  /// Save followers IDs to cache
  static Future<void> saveFollowersIds(
    String userId,
    List<String> followerIds,
  ) async {
    final db = await AppDatabase.instance.database;
    final jsonStr = jsonEncode(followerIds);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.insert('followers_cache', {
        'user_id': userId,
        'follower_ids': jsonStr,
        'timestamp': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error saving followers cache: $e');
    }
  }

  /// Invalidate followers cache for a user
  static Future<void> invalidateFollowers(String userId) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'followers_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // =========================================================================
  // USER PROFILE CACHE
  // =========================================================================

  /// Get cached user profile (7 day TTL)
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'user_profile_cache',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      final timestamp = row['timestamp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final ttlMillis = _profileTtlDays * 24 * 60 * 60 * 1000;

      // Check TTL
      if (currentTime - timestamp < ttlMillis) {
        final jsonStr = row['profile_data'] as String;
        try {
          return jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (e) {
          print('Error decoding user profile cache: $e');
          return null;
        }
      } else {
        // Expired - delete
        await db.delete(
          'user_profile_cache',
          where: 'uid = ?',
          whereArgs: [uid],
        );
        return null;
      }
    }

    return null;
  }

  /// Save multiple user profiles to cache
  static Future<void> saveUserProfiles(List<UserModel> users) async {
    if (users.isEmpty) return;

    final db = await AppDatabase.instance.database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      final batch = db.batch();

      for (final user in users) {
        final jsonStr = jsonEncode(user.toJson());
        batch.insert('user_profile_cache', {
          'uid': user.uid,
          'profile_data': jsonStr,
          'timestamp': timestamp,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);
    } catch (e) {
      print('Error saving user profiles cache: $e');
    }
  }

  /// Save a single user profile to cache
  static Future<void> saveUserProfile(UserModel user) async {
    await saveUserProfiles([user]);
  }

  /// Invalidate a specific user profile cache
  static Future<void> invalidateUserProfile(String uid) async {
    final db = await AppDatabase.instance.database;
    await db.delete('user_profile_cache', where: 'uid = ?', whereArgs: [uid]);
  }

  // =========================================================================
  // CLEAR ALL
  // =========================================================================

  /// Clear all social graph caches (for logout/debugging)
  static Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('following_cache');
    await db.delete('followers_cache');
    await db.delete('user_profile_cache');
  }
}
