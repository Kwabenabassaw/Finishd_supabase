import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/Model/reaction_data.dart';

/// Service for managing video reactions in Supabase
///
/// Schema:
/// table: video_reactions (id, video_id, user_id, reaction_type, emoji, created_at)
/// counts: retrieved via get_reaction_counts RPC
class ReactionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// React to a video (creates or updates reaction)
  Future<void> reactToVideo({
    required String videoId,
    required String userId,
    required String reactionType,
    required String emoji,
  }) async {
    try {
      await _supabase.from('video_reactions').upsert({
        'video_id': videoId,
        'user_id': userId,
        'reaction_type': reactionType,
      }, onConflict: 'video_id,user_id');
    } catch (e) {
      print('❌ Error reacting to video: $e');
      rethrow;
    }
  }

  /// Quick heart reaction (tap to like)
  Future<void> quickReact({
    required String videoId,
    required String userId,
  }) async {
    await reactToVideo(
      videoId: videoId,
      userId: userId,
      reactionType: 'heart',
      emoji: '❤️',
    );
  }

  /// Remove user's reaction from a video
  Future<void> removeReaction({
    required String videoId,
    required String userId,
  }) async {
    try {
      await _supabase.from('video_reactions').delete().match({
        'video_id': videoId,
        'user_id': userId,
      });
    } catch (e) {
      print('❌ Error removing reaction: $e');
    }
  }

  /// Toggle reaction - if same reaction exists, remove it; otherwise set it
  Future<bool> toggleReaction({
    required String videoId,
    required String userId,
    required String reactionType,
    required String emoji,
  }) async {
    final existingReaction = await getUserReaction(
      videoId: videoId,
      userId: userId,
    );

    if (existingReaction != null && existingReaction.type == reactionType) {
      // Same reaction - remove it
      await removeReaction(videoId: videoId, userId: userId);
      return false; // Reaction removed
    } else {
      // Different or no reaction - set new one
      await reactToVideo(
        videoId: videoId,
        userId: userId,
        reactionType: reactionType,
        emoji: emoji,
      );
      return true; // Reaction added
    }
  }

  /// Get user's current reaction to a video
  Future<ReactionData?> getUserReaction({
    required String videoId,
    required String userId,
  }) async {
    try {
      final response = await _supabase.from('video_reactions').select().match({
        'video_id': videoId,
        'user_id': userId,
      }).maybeSingle();

      if (response == null) return null;

      return ReactionData.fromJson(response, response['id'].toString());
    } catch (e) {
      print('Error getting user reaction: $e');
      return null;
    }
  }

  /// Stream user's reaction (for real-time updates)
  Stream<ReactionData?> getUserReactionStream({
    required String videoId,
    required String userId,
  }) {
    return _supabase.from('video_reactions').stream(primaryKey: ['id']).map((
      data,
    ) {
      final filtered = data.where(
        (row) => row['video_id'] == videoId && row['user_id'] == userId,
      );
      if (filtered.isEmpty) return null;
      return ReactionData.fromJson(
        filtered.first,
        filtered.first['id'].toString(),
      );
    });
  }

  /// Get reaction counts for a video via direct query
  Future<Map<String, int>> getReactionCounts(String videoId) async {
    try {
      final response = await _supabase
          .from('video_reactions')
          .select('reaction_type')
          .eq('video_id', videoId);

      final counts = _emptyCountsMap();
      for (final row in (response as List)) {
        final type = row['reaction_type'] as String?;
        if (type != null && counts.containsKey(type)) {
          counts[type] = counts[type]! + 1;
        }
      }
      return counts;
    } catch (e) {
      print('Error getting reaction counts: $e');
      return _emptyCountsMap();
    }
  }

  /// Stream reaction counts
  /// Note: Supabase doesn't support streaming aggregation directly.
  /// Ideally, we would stream the raw table filter by video_id and aggregate client-side,
  /// OR use a trigger-updated aggregator table.
  /// For now, to keep it simple and consistent with the interface, we'll stream raw insertions
  /// and re-fetch counts, or just stream the raw list if volume is low.
  ///
  /// Given the potential volume, it's better to just return a Stream that emits regularly or on changes.
  /// We'll use a simplified approach: Stream the raw table filtered by video_id, and aggregate client-side.
  Stream<Map<String, int>> getReactionCountsStream(String videoId) {
    return _supabase.from('video_reactions').stream(primaryKey: ['id']).map((
      List<Map<String, dynamic>> data,
    ) {
      // Client-side filtering because .eq() isn't supported on stream() in this SDK version
      final filteredData = data.where((row) => row['video_id'] == videoId);

      final counts = _emptyCountsMap();
      for (var row in filteredData) {
        final type = row['reaction_type'] as String?;
        if (type != null && counts.containsKey(type)) {
          counts[type] = (counts[type]! + 1);
        }
      }
      return counts;
    });
  }

  /// Get total reaction count for a video (reads denormalized counter)
  Future<int> getTotalReactionCount(String videoId) async {
    try {
      final response = await _supabase
          .from('creator_videos')
          .select('like_count')
          .eq('id', videoId)
          .maybeSingle();
      return (response?['like_count'] ?? 0) as int;
    } catch (e) {
      // Fallback: count from reactions table
      final counts = await getReactionCounts(videoId);
      return counts.values.fold<int>(0, (sum, count) => sum + count);
    }
  }

  /// Stream total reaction count
  Stream<int> getTotalReactionCountStream(String videoId) {
    return getReactionCountsStream(
      videoId,
    ).map((counts) => counts.values.fold<int>(0, (sum, count) => sum + count));
  }

  /// Helper to create empty counts map
  Map<String, int> _emptyCountsMap() {
    return {'heart': 0, 'laugh': 0, 'wow': 0, 'sad': 0, 'angry': 0};
  }
}
