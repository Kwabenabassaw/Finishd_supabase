import 'package:cloud_firestore/cloud_firestore.dart';

class UserTitleRecord {
  final String userId;
  final String titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final int? rating;
  final String? status;
  final DateTime? ratedAt;

  UserTitleRecord({
    required this.userId,
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.rating,
    this.status,
    this.ratedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'titleId': titleId,
      'mediaType': mediaType,
      'title': title,
      'posterPath': posterPath,
      'rating': rating,
      'status': status,
      'ratedAt': ratedAt != null ? Timestamp.fromDate(ratedAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserTitleRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserTitleRecord(
      userId: data['userId'] ?? '',
      titleId: data['titleId'] ?? '',
      mediaType: data['mediaType'] ?? '',
      title: data['title'] ?? '',
      posterPath: data['posterPath'],
      rating: data['rating'] as int?,
      status: data['status'],
      ratedAt: (data['ratedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class UserTitlesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get a user's record for a specific title
  Future<UserTitleRecord?> getUserTitle(String uid, String titleId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('user_titles')
          .doc(titleId)
          .get();

      if (doc.exists) {
        return UserTitleRecord.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user title: $e');
      return null;
    }
  }

  /// Update rating for a title
  Future<void> updateRating({
    required String uid,
    required String titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    required int rating,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('user_titles')
          .doc(titleId);

      await docRef.set({
        'userId': uid,
        'titleId': titleId,
        'mediaType': mediaType,
        'title': title,
        'posterPath': posterPath,
        'rating': rating,
        'ratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update in other lists to maintain compatibility with legacy systems
      await _syncWithLegacyLists(uid, titleId, rating);
    } catch (e) {
      print('Error updating rating: $e');
      rethrow;
    }
  }

  /// Syncs the rating with legacy collections (watching, finished, etc.)
  Future<void> _syncWithLegacyLists(
    String uid,
    String titleId,
    int rating,
  ) async {
    final lists = ['watching', 'watchlist', 'finished', 'favorites'];
    final batch = _firestore.batch();

    for (final list in lists) {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection(list)
          .doc(titleId);

      final doc = await docRef.get();
      if (doc.exists) {
        batch.update(docRef, {'rating': rating});
      }
    }

    await batch.commit();
  }

  /// Stream a user's title record
  Stream<UserTitleRecord?> streamUserTitle(String uid, String titleId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('user_titles')
        .doc(titleId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return UserTitleRecord.fromFirestore(doc);
          }
          return null;
        });
  }

  /// Get top rated titles (rating >= 4) for personalization
  Future<List<UserTitleRecord>> getTopRatedTitles(String uid) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(uid)
          .collection('user_titles')
          .where('rating', isGreaterThanOrEqualTo: 4)
          .orderBy('rating', descending: true)
          .limit(10)
          .get();

      return query.docs
          .map((doc) => UserTitleRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting top rated titles: $e');
      return [];
    }
  }
}
