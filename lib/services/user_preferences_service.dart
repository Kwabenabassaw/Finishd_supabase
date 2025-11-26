import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/user_preferences.dart';

class UserPreferencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save all user preferences to Firestore
  Future<void> saveUserPreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await userRef.update({
        'preferences': preferences.toJson(),
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw 'Failed to save preferences: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred while saving preferences.';
    }
  }

  /// Get user preferences from Firestore
  Future<UserPreferences?> getUserPreferences(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final doc = await userRef.get();

      if (!doc.exists || doc.data()?['preferences'] == null) {
        return null;
      }

      return UserPreferences.fromJson(doc.data()!['preferences']);
    } on FirebaseException catch (e) {
      throw 'Failed to load preferences: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred while loading preferences.';
    }
  }

  /// Update only genres
  Future<void> updateGenres(
    String userId,
    List<String> genres,
    List<int> genreIds,
  ) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await userRef.update({
        'preferences.selectedGenres': genres,
        'preferences.selectedGenreIds': genreIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw 'Failed to update genres: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred while updating genres.';
    }
  }

  /// Update only streaming providers
  Future<void> updateStreamingProviders(
    String userId,
    List<Map<String, dynamic>> providers,
  ) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await userRef.update({
        'preferences.streamingProviders': providers,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw 'Failed to update streaming providers: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred while updating streaming providers.';
    }
  }

  /// Update selected movies
  Future<void> updateSelectedMovies(
    String userId,
    List<Map<String, dynamic>> movies,
  ) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await userRef.update({
        'preferences.selectedMovies': movies,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw 'Failed to update movies: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred while updating movies.';
    }
  }

  /// Update selected shows
  Future<void> updateSelectedShows(
    String userId,
    List<Map<String, dynamic>> shows,
  ) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await userRef.update({
        'preferences.selectedShows': shows,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw 'Failed to update shows: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred while updating shows.';
    }
  }
}
