import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/recommendation_model.dart';
import 'package:finishd/services/chat_service.dart';
import 'package:finishd/db/app_database.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:async';
import 'package:finishd/services/cache/recommendation_cache_service.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  /// Check if a movie/show has already been recommended to a specific friend
  Future<bool> hasAlreadyRecommended({
    required String fromUserId,
    required String toUserId,
    required String movieId,
  }) async {
    final query = await _firestore
        .collection('recommendations')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('movieId', isEqualTo: movieId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  /// Get list of friend IDs who have already received this recommendation
  /// Uses SQLite cache with 60-second TTL for performance
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

        // If cache is fresh (< 60 seconds), use it
        if (ageSeconds < 60) {
          final friendIdsJson = cached.first['friend_ids'] as String;
          final List<dynamic> friendIdsList = json.decode(friendIdsJson);
          print(
            '[RecommendationCache] Cache HIT for $cacheKey (age: ${ageSeconds.toStringAsFixed(1)}s)',
          );
          return friendIdsList.cast<String>().toSet();
        } else {
          // Cache expired, delete it
          await db.delete(
            'recommendation_cache',
            where: 'cache_key = ?',
            whereArgs: [cacheKey],
          );
          print(
            '[RecommendationCache] Cache EXPIRED for $cacheKey (age: ${ageSeconds.toStringAsFixed(1)}s)',
          );
        }
      }

      // 2. Cache miss or expired - fetch from Firestore
      print(
        '[RecommendationCache] Cache MISS for $cacheKey - fetching from Firestore',
      );
      final query = await _firestore
          .collection('recommendations')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('movieId', isEqualTo: movieId)
          .get();

      final friendIds = query.docs
          .map((doc) => doc.data()['toUserId'] as String)
          .toSet();

      // 3. Store in cache
      await db.insert('recommendation_cache', {
        'cache_key': cacheKey,
        'friend_ids': json.encode(friendIds.toList()),
        'timestamp': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print(
        '[RecommendationCache] Cached ${friendIds.length} friend IDs for $cacheKey',
      );
      return friendIds;
    } catch (e) {
      print('[RecommendationCache] Error: $e');
      // Fallback to Firestore on cache error
      final query = await _firestore
          .collection('recommendations')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('movieId', isEqualTo: movieId)
          .get();

      return query.docs.map((doc) => doc.data()['toUserId'] as String).toSet();
    }
  }

  // Send a recommendation to multiple friends (skips already recommended)
  Future<Map<String, dynamic>> sendRecommendation({
    required String fromUserId,
    required List<String> toUserIds,
    required MovieListItem movie,
  }) async {
    // Get already recommended friends for this movie
    final alreadyRecommended = await getAlreadyRecommendedFriends(
      fromUserId: fromUserId,
      movieId: movie.id,
    );

    // Filter out friends who already received this recommendation
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

    final batch = _firestore.batch();

    for (String toUserId in newFriends) {
      final docRef = _firestore.collection('recommendations').doc();
      final recommendation = Recommendation(
        id: docRef.id,
        fromUserId: fromUserId,
        toUserId: toUserId,
        movieId: movie.id,
        movieTitle: movie.title,
        moviePosterPath: movie.posterPath,
        mediaType: movie.mediaType,
        timestamp: DateTime.now(),
      );

      batch.set(docRef, recommendation.toMap());
    }

    await batch.commit();

    // Invalidate cache after sending recommendations
    await _invalidateCache(fromUserId, movie.id);

    // Also send a chat message to each friend
    for (String toUserId in newFriends) {
      try {
        // Create or get chat ID
        final chatId = await _chatService.createChat(fromUserId, toUserId);

        // Send recommendation as chat message
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
        // Log error but don't fail the recommendation
        print('Error sending recommendation chat message: $e');
      }
    }

    return {
      'sent': newFriends.length,
      'skipped': skippedCount,
      'alreadyRecommended': alreadyRecommended.toList(),
    };
  }

  /// Invalidate cache for a specific user-movie combination
  Future<void> _invalidateCache(String fromUserId, String movieId) async {
    try {
      final cacheKey = '${fromUserId}_$movieId';
      final db = await AppDatabase.instance.database;

      await db.delete(
        'recommendation_cache',
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
      );

      print('[RecommendationCache] Invalidated cache for $cacheKey');
    } catch (e) {
      print('[RecommendationCache] Error invalidating cache: $e');
    }
  }

  // Get recommendations received by a user
  Stream<List<Recommendation>> getRecommendations(String userId) {
    return _firestore
        .collection('recommendations')
        .where('toUserId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Recommendation.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // Get recommendations for a specific movie (to show "Recommended By")
  // This is used to show who recommended a specific movie to the current user
  Stream<List<Recommendation>> getMyRecommendationsForMovie(
    String userId,
    String movieId,
  ) {
    return _firestore
        .collection('recommendations')
        .where('toUserId', isEqualTo: userId)
        .where('movieId', isEqualTo: movieId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Recommendation.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // Mark recommendation as seen
  Future<void> markAsSeen(String recommendationId) async {
    await _firestore.collection('recommendations').doc(recommendationId).update(
      {'status': 'seen'},
    );

    // Also update locally
    await RecommendationCacheService.markAsSeenLocally(recommendationId);
  }

  // ==========================================================================
  // HYBRID APPROACH (Cached + Real-Time for New Items Only)
  // ==========================================================================

  /// Hybrid stream: Loads cached data instantly, then listens for NEW recommendations only
  /// This reduces reads by ~90% while maintaining real-time experience
  Stream<List<Recommendation>> getRecommendationsHybrid(String userId) async* {
    print('🚀 [Hybrid] Starting recommendations stream for $userId');

    // 1. Check local cache
    final localRecs = await RecommendationCacheService.getLocalRecommendations(
      userId,
    );

    // 2. Check sync status
    final lastSync = await RecommendationCacheService.getLastSyncTime(userId);

    // 3. Determine if we need a full refresh
    // Condition:
    // - First time user (lastSync == null)
    // - OR Cache is empty (even if lastSync exists, we want to be safe and fetch again)
    final bool needsFullSync = (lastSync == null) || (localRecs.isEmpty);

    if (needsFullSync) {
      if (lastSync == null) {
        print('🔄 [Hybrid] First-time sync - fetching all recommendations');
      } else {
        print(
          '⚠️ [Hybrid] Cache mismatch (empty but synced) - forcing full re-sync',
        );
      }

      // Perform full sync
      final allRecs = await refreshRecommendations(userId);
      yield allRecs;

      // Now set up listener for NEW items from NOW
      final queryStartTime = DateTime.now();
      print(
        '📡 [Hybrid] Listening for NEW recommendations after re-sync: $queryStartTime',
      );

      await for (final snapshot
          in _firestore
              .collection('recommendations')
              .where('toUserId', isEqualTo: userId)
              .where(
                'timestamp',
                isGreaterThan: Timestamp.fromDate(queryStartTime),
              )
              .orderBy('timestamp', descending: true)
              .snapshots()) {
        if (snapshot.docs.isEmpty) continue;

        print(
          '🔔 [Hybrid] Received ${snapshot.docs.length} new recommendations',
        );
        for (final doc in snapshot.docs) {
          final rec = Recommendation.fromMap(doc.data(), doc.id);
          await RecommendationCacheService.appendRecommendation(userId, rec);
        }
        await RecommendationCacheService.updateLastSyncTime(
          userId,
          DateTime.now(),
        );

        final updated =
            await RecommendationCacheService.getLocalRecommendations(userId);
        yield updated;
      }
    } else {
      // 4. Existing user with data - emit cache then listen incrementally
      print('✅ [Hybrid] Emitting ${localRecs.length} cached recommendations');
      yield localRecs;

      print('📡 [Hybrid] Listening for recommendations after: $lastSync');

      await for (final snapshot
          in _firestore
              .collection('recommendations')
              .where('toUserId', isEqualTo: userId)
              .where('timestamp', isGreaterThan: Timestamp.fromDate(lastSync!))
              .orderBy('timestamp', descending: true)
              .snapshots()) {
        if (snapshot.docs.isEmpty) {
          print('⏸️ [Hybrid] No new recommendations');
          continue;
        }

        print(
          '🔔 [Hybrid] Received ${snapshot.docs.length} new recommendations',
        );
        for (final doc in snapshot.docs) {
          final rec = Recommendation.fromMap(doc.data(), doc.id);
          await RecommendationCacheService.appendRecommendation(userId, rec);
        }
        await RecommendationCacheService.updateLastSyncTime(
          userId,
          DateTime.now(),
        );

        final updated =
            await RecommendationCacheService.getLocalRecommendations(userId);
        print('📤 [Hybrid] Emitting ${updated.length} total recommendations');
        yield updated;
      }
    }
  }

  /// Hybrid stream for movie-specific recommendations
  /// Filters locally after loading from cache
  Stream<List<Recommendation>> getMyRecommendationsForMovieHybrid(
    String userId,
    String movieId,
  ) async* {
    await for (final allRecs in getRecommendationsHybrid(userId)) {
      final filtered = allRecs.where((r) => r.movieId == movieId).toList();
      yield filtered;
    }
  }

  /// Force refresh recommendations (bypass cache)
  Future<List<Recommendation>> refreshRecommendations(String userId) async {
    print('🔄 [Hybrid] Force refreshing recommendations for $userId');

    try {
      // Clear cache
      await RecommendationCacheService.clearUserRecommendations(userId);

      // Fetch all from Firestore
      print('📡 [Hybrid] Querying Firestore for toUserId=$userId');
      final snapshot = await _firestore
          .collection('recommendations')
          .where('toUserId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      print('📥 [Hybrid] Firestore returned ${snapshot.docs.length} docs');

      final recommendations = snapshot.docs
          .map((doc) => Recommendation.fromMap(doc.data(), doc.id))
          .toList();

      // Save to cache
      await RecommendationCacheService.saveRecommendations(
        userId,
        recommendations,
      );
      await RecommendationCacheService.updateLastSyncTime(
        userId,
        DateTime.now(),
      );

      print('✅ [Hybrid] Refreshed ${recommendations.length} recommendations');
      return recommendations;
    } catch (e, stackTrace) {
      print('❌ [Hybrid] ERROR refreshing recommendations: $e');
      print('❌ [Hybrid] Stack trace: $stackTrace');
      // Return empty list but don't crash
      return [];
    }
  }
}
