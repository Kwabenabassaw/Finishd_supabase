import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/comment_data.dart';

/// Service for managing video comments in Firestore
///
/// Firestore Structure:
/// video_comments/{videoId} -> {commentCount: int}
/// video_comments/{videoId}/comments/{commentId} -> CommentData
class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection reference for video comments
  CollectionReference get _commentsCollection =>
      _firestore.collection('video_comments');

  /// Add a comment to a video
  ///
  /// Uses batch write to atomically add the comment and update the count.
  Future<CommentData> addComment({
    required String videoId,
    required String userId,
    required String userName,
    String? userAvatar,
    required String text,
    String? parentId,
  }) async {
    final videoDocRef = _commentsCollection.doc(videoId);
    final commentsRef = videoDocRef.collection('comments');
    final newCommentRef = commentsRef.doc(); // Auto-generate ID

    final commentData = CommentData(
      id: newCommentRef.id,
      text: text,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      videoId: videoId,
      timestamp: DateTime.now(),
      parentId: parentId,
      replyCount: 0,
    );

    final batch = _firestore.batch();

    // Add the comment
    batch.set(newCommentRef, {
      ...commentData.toJson(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update comment count
    batch.set(videoDocRef, {
      'commentCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // If it's a reply, update parent's reply count
    if (parentId != null) {
      batch.update(commentsRef.doc(parentId), {
        'replyCount': FieldValue.increment(1),
      });
    }

    await batch.commit();
    return commentData;
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String videoId,
    required String commentId,
    String? parentId,
  }) async {
    final videoDocRef = _commentsCollection.doc(videoId);
    final commentRef = videoDocRef.collection('comments').doc(commentId);

    final batch = _firestore.batch();

    // Delete the comment
    batch.delete(commentRef);

    // Decrement comment count
    batch.set(videoDocRef, {
      'commentCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));

    // If it's a reply, decrement parent's reply count
    if (parentId != null) {
      batch.update(videoDocRef.collection('comments').doc(parentId), {
        'replyCount': FieldValue.increment(-1),
      });
    }

    await batch.commit();
  }

  /// Get paginated comments for a video
  Future<List<CommentData>> getComments({
    required String videoId,
    int limit = 20,
    DocumentSnapshot? startAfter,
    bool repliesOnly = false,
    String? parentId,
  }) async {
    try {
      Query query = _commentsCollection
          .doc(videoId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (repliesOnly && parentId != null) {
        query = query.where('parentId', isEqualTo: parentId);
      } else if (!repliesOnly) {
        query = query.where('parentId', isNull: true);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => CommentData.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  /// Stream comments for real-time updates
  Stream<List<CommentData>> getCommentsStream({
    required String videoId,
    int limit = 50,
  }) {
    return _commentsCollection
        .doc(videoId)
        .collection('comments')
        .where('parentId', isNull: true)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommentData.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get comment count for a video
  Future<int> getCommentCount(String videoId) async {
    try {
      final doc = await _commentsCollection.doc(videoId).get();
      if (!doc.exists) return 0;

      final data = doc.data() as Map<String, dynamic>?;
      return (data?['commentCount'] ?? 0) as int;
    } catch (e) {
      print('Error getting comment count: $e');
      return 0;
    }
  }

  /// Stream comment count for real-time updates
  Stream<int> getCommentCountStream(String videoId) {
    return _commentsCollection.doc(videoId).snapshots().map((doc) {
      if (!doc.exists) return 0;
      final data = doc.data() as Map<String, dynamic>?;
      return (data?['commentCount'] ?? 0) as int;
    });
  }

  /// Get a single comment by ID
  Future<CommentData?> getComment({
    required String videoId,
    required String commentId,
  }) async {
    try {
      final doc = await _commentsCollection
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!doc.exists || doc.data() == null) return null;
      return CommentData.fromJson(doc.data()!, doc.id);
    } catch (e) {
      print('Error getting comment: $e');
      return null;
    }
  }
}
