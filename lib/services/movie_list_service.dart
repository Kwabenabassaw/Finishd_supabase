import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/services/social_database_helper.dart';
import 'dart:async';

/// Service to manage user's movie lists in Firestore + SQLite cache
/// Collections: users/{uid}/watching, watchlist, finished, favorites
class MovieListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SocialDatabaseHelper _dbHelper = SocialDatabaseHelper();

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

      // Write to SQLite first (instant UI update)
      await _dbHelper.insertListItem(_watchingCollection, movie);

      // Then write to Firestore
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_watchingCollection)
          .doc(movie.id)
          .set(movie.toJson());
    } catch (e) {
      print('Error adding to watching: $e');
      rethrow;
    }
  }

  /// Add movie to "Watch Later" list
  Future<void> addToWatchlist(String uid, MovieListItem movie) async {
    try {
      // Remove from other lists (except favorites)
      await _removeFromOtherLists(uid, movie.id, _watchlistCollection);

      // Write to SQLite first
      await _dbHelper.insertListItem(_watchlistCollection, movie);

      // Then write to Firestore
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_watchlistCollection)
          .doc(movie.id)
          .set(movie.toJson());
    } catch (e) {
      print('Error adding to watchlist: $e');
      rethrow;
    }
  }

  /// Add movie to "Finished" list
  Future<void> addToFinished(String uid, MovieListItem movie) async {
    try {
      // Remove from other lists (except favorites)
      await _removeFromOtherLists(uid, movie.id, _finishedCollection);

      // Write to SQLite first
      await _dbHelper.insertListItem(_finishedCollection, movie);

      // Then write to Firestore
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_finishedCollection)
          .doc(movie.id)
          .set(movie.toJson());
    } catch (e) {
      print('Error adding to finished: $e');
      rethrow;
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
        // Remove from favorites (SQLite first)
        await _dbHelper.removeListItem(_favoritesCollection, movie.id);
        await docRef.delete();
      } else {
        // Add to favorites (SQLite first)
        await _dbHelper.insertListItem(_favoritesCollection, movie);
        await docRef.set(movie.toJson());
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      rethrow;
    }
  }

  /// Remove movie from a specific list
  Future<void> removeFromList(
    String uid,
    String movieId,
    String listType,
  ) async {
    try {
      // Remove from SQLite first
      await _dbHelper.removeListItem(listType, movieId);

      // Then remove from Firestore
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(listType)
          .doc(movieId)
          .delete();
    } catch (e) {
      print('Error removing from $listType: $e');
      rethrow;
    }
  }

  /// Update rating for a movie in any list it exists in
  Future<void> updateRating(String uid, String movieId, int rating) async {
    try {
      final status = await getMovieStatus(uid, movieId);
      final lists = ['watching', 'watchlist', 'finished', 'favorites'];

      final batch = _firestore.batch();
      for (final list in lists) {
        if (status[list] == true) {
          batch.update(
            _firestore
                .collection('users')
                .doc(uid)
                .collection(list)
                .doc(movieId),
            {'rating': rating},
          );
        }
      }
      await batch.commit();
    } catch (e) {
      print('Error updating rating: $e');
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

  /// Get all movies from a specific list (from Firestore - legacy)
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

  /// Get all movies from a specific list (LOCAL-FIRST from SQLite)
  Future<List<MovieListItem>> getMoviesFromListLocal(String listType) async {
    return await _dbHelper.getListItems(listType);
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
          // Remove from SQLite
          await _dbHelper.removeListItem(list, movieId);
          // Remove from Firestore
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

  /// Listen to a list and sync changes to SQLite + notify UI
  /// Returns a StreamSubscription that should be cancelled when done
  StreamSubscription<QuerySnapshot> listenToList(
    String uid,
    String listType,
    Function(List<MovieListItem>) onUpdate,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection(listType)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
          final items = snapshot.docs
              .map((doc) => MovieListItem.fromDocument(doc))
              .toList();

          // Sync to SQLite
          await _dbHelper.syncList(listType, items);

          // Notify UI
          onUpdate(items);
        });
  }
}
