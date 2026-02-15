import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/Model/user_preferences.dart';

class UserPreferencesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Save all user preferences to Supabase (profiles table)
  Future<void> saveUserPreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'preferences': preferences.toJson(),
            // 'onboarding_completed': true, // Assuming column exists or handled elsewhere
          })
          .eq('id', userId);
    } catch (e) {
      throw 'Failed to save preferences: $e';
    }
  }

  /// Get user preferences from Supabase
  Future<UserPreferences?> getUserPreferences(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('preferences')
          .eq('id', userId)
          .maybeSingle();

      if (response == null || response['preferences'] == null) {
        return null;
      }

      return UserPreferences.fromJson(response['preferences']);
    } catch (e) {
      print('Error loading preferences: $e');
      return null;
    }
  }

  /// Update only genres
  Future<void> updateGenres(
    String userId,
    List<String> genres,
    List<int> genreIds,
  ) async {
    // In Supabase, partial JSON updates using jsonb_set are complex via client SDK directly.
    // Easier to fetch, merge, and update, or just update the specific fields if we struct them inside JSON.
    // For simplicity/reliability: Fetch -> Merge -> Save

    // OPTIMIZATION: We can pass the FULL new preferences object from the Provider instead of doing partial updates here.
    // But adhering to the interface:
    try {
      final current = await getUserPreferences(userId) ?? UserPreferences();
      final updated = current.copyWith(
        selectedGenres: genres,
        selectedGenreIds: genreIds,
      );
      await saveUserPreferences(userId, updated);
    } catch (e) {
      throw 'Failed to update genres: $e';
    }
  }

  /// Update only streaming providers
  Future<void> updateStreamingProviders(
    String userId,
    List<Map<String, dynamic>> providersRaw,
  ) async {
    try {
      final providers = providersRaw
          .map((p) => SelectedProvider.fromJson(p))
          .toList();
      final current = await getUserPreferences(userId) ?? UserPreferences();
      final updated = current.copyWith(streamingProviders: providers);
      await saveUserPreferences(userId, updated);
    } catch (e) {
      throw 'Failed to update streaming providers: $e';
    }
  }

  /// Update selected movies
  Future<void> updateSelectedMovies(
    String userId,
    List<Map<String, dynamic>> moviesRaw,
  ) async {
    try {
      final movies = moviesRaw.map((m) => SelectedMedia.fromJson(m)).toList();
      final current = await getUserPreferences(userId) ?? UserPreferences();
      final updated = current.copyWith(selectedMovies: movies);
      await saveUserPreferences(userId, updated);
    } catch (e) {
      throw 'Failed to update movies: $e';
    }
  }

  /// Update selected shows
  Future<void> updateSelectedShows(
    String userId,
    List<Map<String, dynamic>> showsRaw,
  ) async {
    try {
      final shows = showsRaw.map((s) => SelectedMedia.fromJson(s)).toList();
      final current = await getUserPreferences(userId) ?? UserPreferences();
      final updated = current.copyWith(selectedShows: shows);
      await saveUserPreferences(userId, updated);
    } catch (e) {
      throw 'Failed to update shows: $e';
    }
  }
}
