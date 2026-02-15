import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/recommendation_model.dart';
// import 'package:finishd/services/chat_service.dart'; // Chat temporarily disabled during migration
import 'package:finishd/db/app_database.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:async';
import 'package:finishd/services/cache/recommendation_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecommendationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  // final ChatService _chatService = ChatService(); // Chat disabled

  /// Check if a movie/show has already been recommended to a specific friend
  Future<bool> hasAlreadyRecommended({
    required String fromUserId,
    required String toUserId,
    required String movieId,
  }) async {
    final response = await _supabase
        .from('recommendations')
        .select()
        .eq('from_user_id', fromUserId)
        .eq('to_user_id', toUserId)
        .eq('movie_id', movieId)
        .maybeSingle();

    return response != null;
  }

  /// Get list of friend IDs who have already received this recommendation
  Future<Set<String>> getAlreadyRecommendedFriends({
    required String fromUserId,
    required String movieId,
  }) async {
    final cacheKey = '${fromUserId}_$movieId';
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. Check SQLite cache first
      final cached = await db.query(
        'recommendation_cache',
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
        limit: 1,
      );

      if (cached.isNotEmpty) {
        final timestamp = cached.first['timestamp'] as int;
        final ageSeconds = (now - timestamp) / 1000;

        if (ageSeconds < 60) {
          final friendIdsJson = cached.first['friend_ids'] as String;
          final List<dynamic> friendIdsList = json.decode(friendIdsJson);
          return friendIdsList.cast<String>().toSet();
        } else {
          await db.delete(
            'recommendation_cache',
            where: 'cache_key = ?',
            whereArgs: [cacheKey],
          );
        }
      }

      // 2. Cache miss - fetch from Supabase
      final response = await _supabase
          .from('recommendations')
          .select('to_user_id')
          .eq('from_user_id', fromUserId)
          .eq('movie_id', movieId);

      final friendIds = (response as List)
          .map((row) => row['to_user_id'] as String)
          .toSet();

      // 3. Store in cache
      await db.insert('recommendation_cache', {
        'cache_key': cacheKey,
        'friend_ids': json.encode(friendIds.toList()),
        'timestamp': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return friendIds;
    } catch (e) {
      print('[RecommendationCache] Error: $e');
      return {};
    }
  }

  // Send a recommendation to multiple friends
  Future<Map<String, dynamic>> sendRecommendation({
    required String fromUserId,
    required List<String> toUserIds,
    required MovieListItem movie,
  }) async {
    // Get already recommended friends
    final alreadyRecommended = await getAlreadyRecommendedFriends(
      fromUserId: fromUserId,
      movieId: movie.id,
    );

    // Filter new friends
    final newFriends = toUserIds
        .where((id) => !alreadyRecommended.contains(id))
        .toList();
    final skippedCount = toUserIds.length - newFriends.length;

    if (newFriends.isEmpty) {
      return {
        'sent': 0,
        'skipped': skippedCount,
        'alreadyRecommended': alreadyRecommended.toList(),
      };
    }

    // Batch insert into Supabase
    final insertData = newFriends
        .map(
          (toUserId) => {
            'from_user_id': fromUserId,
            'to_user_id': toUserId,
            'movie_id': movie.id,
            'title': movie.title,
            'poster_path': movie.posterPath,
            'media_type': movie.mediaType,
            // 'status': 'unread', // Default
          },
        )
        .toList();

    await _supabase.from('recommendations').insert(insertData);

    // Invalidate cache
    await _invalidateCache(fromUserId, movie.id);

    // TEMPORARILY DISABLED CHAT NOTIFICATION
    /*
    for (String toUserId in newFriends) {
      try {
        final chatId = await _chatService.createChat(fromUserId, toUserId);
        await _chatService.sendRecommendation(
          chatId: chatId,
          senderId: fromUserId,
          receiverId: toUserId,
          movieId: movie.id,
          movieTitle: movie.title,
          moviePoster: movie.posterPath,
          mediaType: movie.mediaType,
        );
      } catch (e) {
        print('Error sending recommendation chat message: $e');
      }
    }
    */

    return {
      'sent': newFriends.length,
      'skipped': skippedCount,
      'alreadyRecommended': alreadyRecommended.toList(),
    };
  }

  Future<void> _invalidateCache(String fromUserId, String movieId) async {
    try {
      final cacheKey = '${fromUserId}_$movieId';
      final db = await AppDatabase.instance.database;
      await db.delete(
        'recommendation_cache',
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
      );
    } catch (e) {
      print('[RecommendationCache] Error invalidating cache: $e');
    }
  }

  // Get recommendations received by a user
  Stream<List<Recommendation>> getRecommendations(String userId) {
    return _supabase
        .from('recommendations')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (data) => data
              .where((json) => json['to_user_id'] == userId)
              .map((json) => Recommendation.fromMap(json, json['id']))
              .toList(),
        );
  }

  // Get unread recommendation count stream
  Stream<int> getUnreadCountStream(String userId) {
    return _supabase
        .from('recommendations')
        .stream(primaryKey: ['id'])
        .map(
          (data) => data
              .where(
                (json) =>
                    json['to_user_id'] == userId && json['status'] == 'unread',
              )
              .length,
        );
  }

  // Get recommendations for a specific movie (to show "Recommended By")
  Stream<List<Recommendation>> getMyRecommendationsForMovie(
    String userId,
    String movieId,
  ) {
    return _supabase
        .from('recommendations')
        .stream(primaryKey: ['id'])
        .map(
          (data) => data
              .where(
                (json) =>
                    json['to_user_id'] == userId && json['movie_id'] == movieId,
              )
              .map((json) => Recommendation.fromMap(json, json['id']))
              .toList(),
        );
  }

  // Mark recommendation as seen
  Future<void> markAsSeen(String recommendationId) async {
    await _supabase
        .from('recommendations')
        .update({'status': 'seen'})
        .eq('id', recommendationId);
    await RecommendationCacheService.markAsSeenLocally(recommendationId);
  }

  // ==========================================================================
  // HYBRID APPROACH (Cached + Real-Time) - Adapted for Supabase
  // ==========================================================================

  Stream<List<Recommendation>> getRecommendationsHybrid(String userId) async* {
    // 1. Emit Cache
    final localRecs = await RecommendationCacheService.getLocalRecommendations(
      userId,
    );
    yield localRecs;

    // 2. Fetch Fresh & Update Cache
    try {
      final lastSync = await RecommendationCacheService.getLastSyncTime(userId);
      dynamic response;

      if (localRecs.isEmpty || lastSync == null) {
        // Full sync
        response = await _supabase
            .from('recommendations')
            .select()
            .eq('to_user_id', userId)
            .order('created_at', ascending: false)
            .limit(100);
      } else {
        // Incremental (Newer than last sync)
        response = await _supabase
            .from('recommendations')
            .select()
            .eq('to_user_id', userId)
            .gt('created_at', lastSync.toIso8601String())
            .order('created_at', ascending: false);
      }

      final freshRecs = (response as List)
          .map((json) => Recommendation.fromMap(json, json['id']))
          .toList();

      if (freshRecs.isNotEmpty) {
        await RecommendationCacheService.saveRecommendations(
          userId,
          freshRecs,
        ); // Append/Overwrite
        await RecommendationCacheService.updateLastSyncTime(
          userId,
          DateTime.now(),
        );

        final updated =
            await RecommendationCacheService.getLocalRecommendations(userId);
        yield updated;
      }
    } catch (e) {
      print('Error in hybrid recommendations: $e');
    }
  }

  Stream<List<Recommendation>> getMyRecommendationsForMovieHybrid(
    String userId,
    String movieId,
  ) async* {
    await for (final allRecs in getRecommendationsHybrid(userId)) {
      final filtered = allRecs.where((r) => r.movieId == movieId).toList();
      yield filtered;
    }
  }

  Future<List<Recommendation>> refreshRecommendations(String userId) async {
    await RecommendationCacheService.clearUserRecommendations(userId);

    final response = await _supabase
        .from('recommendations')
        .select()
        .eq('to_user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);

    final recs = (response as List)
        .map((json) => Recommendation.fromMap(json, json['id']))
        .toList();

    await RecommendationCacheService.saveRecommendations(userId, recs);
    await RecommendationCacheService.updateLastSyncTime(userId, DateTime.now());

    return recs;
  }
}
