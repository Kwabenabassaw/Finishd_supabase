import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:finishd/services/user_preferences_service.dart';
import 'package:flutter/foundation.dart';

class OnboardingProvider with ChangeNotifier {
  final UserPreferencesService _preferencesService = UserPreferencesService();

  // Genre selections
  final Set<String> _selectedGenres = {};
  final Set<int> _selectedGenreIds = {};

  // Movie/Show selections
  final List<SelectedMedia> _selectedMovies = [];
  final List<SelectedMedia> _selectedShows = [];

  // Streaming provider selections
  final List<SelectedProvider> _selectedProviders = [];

  // Loading state
  bool _isSaving = false;
  String? _errorMessage;

  // Getters
  Set<String> get selectedGenres => _selectedGenres;
  Set<int> get selectedGenreIds => _selectedGenreIds;
  List<SelectedMedia> get selectedMovies => _selectedMovies;
  List<SelectedMedia> get selectedShows => _selectedShows;
  List<SelectedProvider> get selectedProviders => _selectedProviders;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  // Genre management
  void toggleGenre(String genreName, int genreId) {
    if (_selectedGenres.contains(genreName)) {
      _selectedGenres.remove(genreName);
      _selectedGenreIds.remove(genreId);
    } else {
      _selectedGenres.add(genreName);
      _selectedGenreIds.add(genreId);
    }
    notifyListeners();
  }

  bool isGenreSelected(String genreName) {
    return _selectedGenres.contains(genreName);
  }

  // Movie/Show management
  void toggleMedia(SelectedMedia media) {
    if (media.mediaType == 'movie') {
      final index = _selectedMovies.indexWhere((m) => m.id == media.id);
      if (index != -1) {
        _selectedMovies.removeAt(index);
      } else {
        _selectedMovies.add(media);
      }
    } else {
      final index = _selectedShows.indexWhere((s) => s.id == media.id);
      if (index != -1) {
        _selectedShows.removeAt(index);
      } else {
        _selectedShows.add(media);
      }
    }
    notifyListeners();
  }

  bool isMediaSelected(int mediaId, String mediaType) {
    if (mediaType == 'movie') {
      return _selectedMovies.any((m) => m.id == mediaId);
    } else {
      return _selectedShows.any((s) => s.id == mediaId);
    }
  }

  // Streaming provider management
  void toggleProvider(SelectedProvider provider) {
    final index = _selectedProviders.indexWhere(
      (p) => p.providerId == provider.providerId,
    );
    if (index != -1) {
      _selectedProviders.removeAt(index);
    } else {
      _selectedProviders.add(provider);
    }
    notifyListeners();
  }

  bool isProviderSelected(int providerId) {
    return _selectedProviders.any((p) => p.providerId == providerId);
  }

  // Save all preferences to Firestore
  Future<bool> saveToFirestore() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'No user logged in';
      }

      final preferences = UserPreferences(
        selectedGenres: _selectedGenres.toList(),
        selectedGenreIds: _selectedGenreIds.toList(),
        selectedMovies: _selectedMovies,
        selectedShows: _selectedShows,
        streamingProviders: _selectedProviders,
      );

      await _preferencesService.saveUserPreferences(user.uid, preferences);

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // Clear all selections (useful for testing or reset)
  void clearAll() {
    _selectedGenres.clear();
    _selectedGenreIds.clear();
    _selectedMovies.clear();
    _selectedShows.clear();
    _selectedProviders.clear();
    _errorMessage = null;
    notifyListeners();
  }

  // Load existing preferences (if user returns to onboarding)
  Future<void> loadPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final preferences = await _preferencesService.getUserPreferences(
        user.uid,
      );
      if (preferences != null) {
        _selectedGenres.clear();
        _selectedGenres.addAll(preferences.selectedGenres);

        _selectedGenreIds.clear();
        _selectedGenreIds.addAll(preferences.selectedGenreIds);

        _selectedMovies.clear();
        _selectedMovies.addAll(preferences.selectedMovies);

        _selectedShows.clear();
        _selectedShows.addAll(preferences.selectedShows);

        _selectedProviders.clear();
        _selectedProviders.addAll(preferences.streamingProviders);

        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
