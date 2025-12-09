import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/reaction_data.dart';

/// Service for managing video reactions in Firestore
///
/// Firestore Structure:
/// video_reactions/{videoId}/reactions/{userId} -> {type, emoji, timestamp, userId, videoId}
/// video_reactions/{videoId} -> {reactionCounts: {heart: 10, laugh: 4, ...}}
class ReactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection reference for video reactions
  CollectionReference get _reactionsCollection =>
      _firestore.collection('video_reactions');

  /// React to a video (creates or updates reaction)
  ///
  /// Uses batch write to atomically update both the reaction document
  /// and the reaction counts.
  Future<void> reactToVideo({
    required String videoId,
    required String userId,
    required String reactionType,
    required String emoji,
  }) async {
    final videoDocRef = _reactionsCollection.doc(videoId);
    final userReactionRef = videoDocRef.collection('reactions').doc(userId);

    // Check if user already has a reaction (to update counts correctly)
    final existingReaction = await userReactionRef.get();
    final existingData = existingReaction.data();
    final String? previousType = existingData?['type'] as String?;

    // Use batch write for atomicity
    final batch = _firestore.batch();

    // Set the new reaction
    batch.set(userReactionRef, {
      'type': reactionType,
      'emoji': emoji,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
      'videoId': videoId,
    });

    // Update reaction counts
    if (previousType != null && previousType != reactionType) {
      // Decrement old type, increment new type
      batch.set(videoDocRef, {
        'reactionCounts': {
          previousType: FieldValue.increment(-1),
          reactionType: FieldValue.increment(1),
        },
      }, SetOptions(merge: true));
    } else if (previousType == null) {
      // First reaction - just increment
      batch.set(videoDocRef, {
        'reactionCounts': {reactionType: FieldValue.increment(1)},
      }, SetOptions(merge: true));
    }
    // If same type, no count change needed

    await batch.commit();
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
    final videoDocRef = _reactionsCollection.doc(videoId);
    final userReactionRef = videoDocRef.collection('reactions').doc(userId);

    // Get current reaction to decrement correct count
    final existingReaction = await userReactionRef.get();
    if (!existingReaction.exists) return;

    final String? reactionType = existingReaction.data()?['type'] as String?;

    final batch = _firestore.batch();

    // Delete the reaction
    batch.delete(userReactionRef);

    // Decrement the count
    if (reactionType != null) {
      batch.set(videoDocRef, {
        'reactionCounts': {reactionType: FieldValue.increment(-1)},
      }, SetOptions(merge: true));
    }

    await batch.commit();
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
      final doc = await _reactionsCollection
          .doc(videoId)
          .collection('reactions')
          .doc(userId)
          .get();

      if (!doc.exists || doc.data() == null) return null;

      return ReactionData.fromJson(doc.data()!, doc.id);
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
    return _reactionsCollection
        .doc(videoId)
        .collection('reactions')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return ReactionData.fromJson(doc.data()!, doc.id);
        });
  }

  /// Get reaction counts for a video
  Future<Map<String, int>> getReactionCounts(String videoId) async {
    try {
      final doc = await _reactionsCollection.doc(videoId).get();
      if (!doc.exists) return _emptyCountsMap();

      final data = doc.data() as Map<String, dynamic>?;
      final counts = data?['reactionCounts'] as Map<String, dynamic>?;

      if (counts == null) return _emptyCountsMap();

      return {
        'heart': (counts['heart'] ?? 0) as int,
        'laugh': (counts['laugh'] ?? 0) as int,
        'wow': (counts['wow'] ?? 0) as int,
        'sad': (counts['sad'] ?? 0) as int,
        'angry': (counts['angry'] ?? 0) as int,
      };
    } catch (e) {
      print('Error getting reaction counts: $e');
      return _emptyCountsMap();
    }
  }

  /// Stream reaction counts (for real-time updates)
  Stream<Map<String, int>> getReactionCountsStream(String videoId) {
    return _reactionsCollection.doc(videoId).snapshots().map((doc) {
      if (!doc.exists) return _emptyCountsMap();

      final data = doc.data() as Map<String, dynamic>?;
      final counts = data?['reactionCounts'] as Map<String, dynamic>?;

      if (counts == null) return _emptyCountsMap();

      return {
        'heart': (counts['heart'] ?? 0) as int,
        'laugh': (counts['laugh'] ?? 0) as int,
        'wow': (counts['wow'] ?? 0) as int,
        'sad': (counts['sad'] ?? 0) as int,
        'angry': (counts['angry'] ?? 0) as int,
      };
    });
  }

  /// Get total reaction count for a video
  Future<int> getTotalReactionCount(String videoId) async {
    final counts = await getReactionCounts(videoId);
    return counts.values.fold<int>(0, (sum, count) => sum + count);
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
