import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/movie_list_item.dart';

/// Service to manage user's movie lists in Firestore
/// Collections: users/{uid}/watching, watchlist, finished, favorites
class MovieListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _watchingCollection = 'watching';
  static const String _watchlistCollection = 'watchlist';
  static const String _finishedCollection = 'finished';
  static const String _favoritesCollection = 'favorites';

  /// Add movie to "Currently Watching" list
  Future<void> addToWatching(String uid, MovieListItem movie) async {
    try {
      // Remove from other lists (except favorites)
      await _removeFromOtherLists(uid, movie.id, _watchingCollection);

      // Add to watching
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_watchingCollection)
          .doc(movie.id)
          .set(movie.toJson());
    } catch (e) {
      print('Error adding to watching: $e');
      throw e;
    }
  }

  /// Add movie to "Watch Later" list
  Future<void> addToWatchlist(String uid, MovieListItem movie) async {
    try {
      // Remove from other lists (except favorites)
      await _removeFromOtherLists(uid, movie.id, _watchlistCollection);

      // Add to watchlist
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_watchlistCollection)
          .doc(movie.id)
          .set(movie.toJson());
    } catch (e) {
      print('Error adding to watchlist: $e');
      throw e;
    }
  }

  /// Add movie to "Finished" list
  Future<void> addToFinished(String uid, MovieListItem movie) async {
    try {
      // Remove from other lists (except favorites)
      await _removeFromOtherLists(uid, movie.id, _finishedCollection);

      // Add to finished
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_finishedCollection)
          .doc(movie.id)
          .set(movie.toJson());
    } catch (e) {
      print('Error adding to finished: $e');
      throw e;
    }
  }

  /// Add/remove movie to/from "Favorites" list
  /// Favorites can overlap with other lists
  Future<void> toggleFavorite(String uid, MovieListItem movie) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection(_favoritesCollection)
          .doc(movie.id);

      final doc = await docRef.get();

      if (doc.exists) {
        // Remove from favorites
        await docRef.delete();
      } else {
        // Add to favorites
        await docRef.set(movie.toJson());
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      throw e;
    }
  }

  /// Remove movie from a specific list
  Future<void> removeFromList(
    String uid,
    String movieId,
    String listType,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(listType)
          .doc(movieId)
          .delete();
    } catch (e) {
      print('Error removing from $listType: $e');
      throw e;
    }
  }

  /// Get movie status - returns which lists contain the movie
  Future<Map<String, bool>> getMovieStatus(String uid, String movieId) async {
    try {
      final results = await Future.wait([
        _firestore
            .collection('users')
            .doc(uid)
            .collection(_watchingCollection)
            .doc(movieId)
            .get(),
        _firestore
            .collection('users')
            .doc(uid)
            .collection(_watchlistCollection)
            .doc(movieId)
            .get(),
        _firestore
            .collection('users')
            .doc(uid)
            .collection(_finishedCollection)
            .doc(movieId)
            .get(),
        _firestore
            .collection('users')
            .doc(uid)
            .collection(_favoritesCollection)
            .doc(movieId)
            .get(),
      ]);

      return {
        'watching': results[0].exists,
        'watchlist': results[1].exists,
        'finished': results[2].exists,
        'favorites': results[3].exists,
      };
    } catch (e) {
      print('Error getting movie status: $e');
      return {
        'watching': false,
        'watchlist': false,
        'finished': false,
        'favorites': false,
      };
    }
  }

  /// Get all movies from a specific list
  Future<List<MovieListItem>> getMoviesFromList(
    String uid,
    String listType,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection(listType)
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MovieListItem.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error getting movies from $listType: $e');
      return [];
    }
  }

  /// Remove movie from all lists except the specified one and favorites
  Future<void> _removeFromOtherLists(
    String uid,
    String movieId,
    String keepList,
  ) async {
    final listsToCheck = [
      _watchingCollection,
      _watchlistCollection,
      _finishedCollection,
    ];

    for (final list in listsToCheck) {
      if (list != keepList) {
        try {
          await _firestore
              .collection('users')
              .doc(uid)
              .collection(list)
              .doc(movieId)
              .delete();
        } catch (e) {
          // Ignore errors - document might not exist
        }
      }
    }
  }

  /// Stream movies from a specific list for real-time updates
  Stream<List<MovieListItem>> streamMoviesFromList(
    String uid,
    String listType,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection(listType)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MovieListItem.fromDocument(doc))
              .toList();
        });
  }
}
