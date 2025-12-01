import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/recommendation_model.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send a recommendation to multiple friends
  Future<void> sendRecommendation({
    required String fromUserId,
    required List<String> toUserIds,
    required MovieListItem movie,
  }) async {
    final batch = _firestore.batch();

    for (String toUserId in toUserIds) {
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
  }
}
