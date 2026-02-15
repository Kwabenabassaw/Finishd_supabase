import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local cache for user preferences to enable offline personalization.
///
/// This service stores user preferences locally for fast access during
/// feed scoring without requiring network calls.
class UserPreferencesCache {
  static const String _cacheKey = 'user_preferences_v1';
  static const Duration _cacheTtl = Duration(hours: 24);

  static UserPreferencesCache? _instance;
  UserPreferences? _cached;
  DateTime? _lastFetched;

  UserPreferencesCache._();

  static UserPreferencesCache get instance {
    _instance ??= UserPreferencesCache._();
    return _instance!;
  }

  /// Get cached preferences (fast, local-only)
  Future<UserPreferences?> getCached() async {
    if (_cached != null) return _cached;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);

      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        _cached = UserPreferences.fromJson(data);
        return _cached;
      }
    } catch (e) {
      // Ignore cache read errors
    }

    return null;
  }

  /// Save preferences to local cache
  Future<void> save(UserPreferences prefs) async {
    try {
      final prefsStore = await SharedPreferences.getInstance();
      await prefsStore.setString(_cacheKey, jsonEncode(prefs.toJson()));
      _cached = prefs;
      _lastFetched = DateTime.now();
    } catch (e) {
      // Ignore cache write errors
    }
  }

  /// Sync preferences from Supabase and cache locally
  Future<UserPreferences> syncFromFirestore(String userId) async {
    try {
      // Auto-detect user ID if empty string passed
      String effectiveUserId = userId;
      if (userId.isEmpty) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null) {
          return UserPreferences.empty();
        }
        effectiveUserId = currentUser.id;
      }

      final supabase = Supabase.instance.client;

      // 1. Fetch User Profile for explicit genres
      final profileResponse = await supabase
          .from('profiles')
          .select('preferences')
          .eq('id', effectiveUserId)
          .maybeSingle();

      List<String> selectedGenres = [];
      if (profileResponse != null && profileResponse['preferences'] != null) {
        final prefsMap = profileResponse['preferences'];
        if (prefsMap is Map && prefsMap['selectedGenres'] != null) {
          selectedGenres = List<String>.from(prefsMap['selectedGenres']);
        }
      }

      print('[PrefsCache] syncing for user: $effectiveUserId');

      // 2. Fetch User Titles (Watching, Finished, Favorites, Watchlist)
      // We can fetch all in one query for efficiency
      final userTitlesResponse = await supabase
          .from('user_titles')
          .select()
          .eq('user_id', effectiveUserId);

      final List<Map<String, dynamic>> userTitles =
          List<Map<String, dynamic>>.from(userTitlesResponse);

      final watchedIds = <int>[];
      final watchlistIds = <int>[];
      final favoriteIds = <int>[];
      final finishedIds = <int>[];
      final watchingIds = <int>[];

      // Extract IDs based on status/favorite
      for (final title in userTitles) {
        final tmdbId = int.tryParse(title['title_id']?.toString() ?? '');
        if (tmdbId == null || tmdbId == 0) continue;

        final status = title['status'] as String?;
        final isFavorite = title['is_favorite'] as bool? ?? false;

        if (status == 'watching') {
          watchingIds.add(tmdbId);
          watchedIds.add(tmdbId); // Watching counts as watched/engaged
        } else if (status == 'finished') {
          finishedIds.add(tmdbId);
          watchedIds.add(tmdbId);
        } else if (status == 'watchlist') {
          watchlistIds.add(tmdbId);
        }

        if (isFavorite) {
          favoriteIds.add(tmdbId);
          if (!watchedIds.contains(tmdbId)) watchedIds.add(tmdbId);
        }
      }

      // 3. Fetch Recommendations
      final recommendationsResponse = await supabase
          .from('recommendations')
          .select('movie_id')
          .eq('to_user_id', effectiveUserId)
          .limit(50);

      final recommendedIds = (recommendationsResponse as List)
          .map((r) => int.tryParse(r['movie_id'].toString()) ?? 0)
          .where((id) => id > 0)
          .toList();

      // Merge watchlist and recommended IDs
      final combinedWatchlist = {...watchlistIds, ...recommendedIds}.toList();

      // 4. Fetch Liked Videos (Reactions)
      final likesResponse = await supabase
          .from('video_reactions')
          .select('video_id')
          .eq('user_id', effectiveUserId)
          .eq('reaction_type', 'like');

      final likedVideos = (likesResponse as List)
          .map((r) => r['video_id'] as String)
          .toList();

      // 5. Calculate Genre Weights (Client-side aggregation logic reused)
      // Since 'user_titles' has a 'genre' column (string or json), we can use it.
      // Assuming 'genre' column in user_titles is a comma-separated string or simple string.

      final genreScores = <String, double>{};

      // Helper to process weights
      void addWeights(List<Map<String, dynamic>> items, double multiplier) {
        for (final item in items) {
          final genreField = item['genre'];
          if (genreField != null) {
            final genres = _extractGenres(genreField);
            for (final g in genres) {
              genreScores[g] = (genreScores[g] ?? 0) + multiplier;
            }
          }
        }
      }

      // Filter lists from the fetched userTitles
      final favoritesList = userTitles
          .where((t) => t['is_favorite'] == true)
          .toList();
      final finishedList = userTitles
          .where((t) => t['status'] == 'finished')
          .toList();
      final watchingList = userTitles
          .where((t) => t['status'] == 'watching')
          .toList();
      final watchlistList = userTitles
          .where((t) => t['status'] == 'watchlist')
          .toList();

      addWeights(favoritesList, 2.0);
      addWeights(finishedList, 1.5);
      addWeights(watchingList, 1.0);
      addWeights(watchlistList, 0.5);

      // Normalize weights
      final genreWeights = _normalizeWeights(genreScores);

      print(
        '[PrefsCache] Final sync: ${selectedGenres.length} genres, '
        '${watchedIds.length} watched, ${combinedWatchlist.length} watchlist, '
        '${genreWeights.length} weighted genres',
      );

      final prefs = UserPreferences(
        genreWeights: genreWeights,
        preferredGenres: selectedGenres,
        dislikedGenres: [],
        watchedTmdbIds: watchedIds,
        watchlistTmdbIds: combinedWatchlist,
        likedVideoIds: likedVideos,
        lastSynced: DateTime.now(),
      );

      // Cache locally
      await save(prefs);

      return prefs;
    } catch (e) {
      print('[PrefsCache] Error syncing: $e');
      return _cached ?? UserPreferences.empty();
    }
  }

  // Helper to extract genres from Supabase 'genre' field
  List<String> _extractGenres(dynamic genreField) {
    if (genreField == null) return [];
    if (genreField is String) {
      return genreField
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList();
    }
    // Handle JSON array if applicable
    if (genreField is List) {
      return genreField.map((g) => g.toString()).toList();
    }
    return [];
  }

  Map<String, double> _normalizeWeights(Map<String, double> scores) {
    if (scores.isEmpty) return {};
    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    final normalized = <String, double>{};
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedEntries) {
      normalized[entry.key] = double.parse(
        (entry.value / maxScore).toStringAsFixed(3),
      );
    }
    return normalized;
  }

  /// Check if cache needs refresh
  bool get needsRefresh {
    if (_lastFetched == null) return true;
    return DateTime.now().difference(_lastFetched!) > _cacheTtl;
  }

  /// Clear local cache
  Future<void> clear() async {
    _cached = null;
    _lastFetched = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}

/// User preferences for feed personalization
class UserPreferences {
  /// Weighted genre affinities from taste profile (0.0 to 1.0)
  /// Higher values = stronger preference
  final Map<String, double> genreWeights;

  final List<String> preferredGenres;
  final List<String> dislikedGenres;
  final List<int> watchedTmdbIds;
  final List<int> watchlistTmdbIds;
  final List<String> likedVideoIds;
  final DateTime? lastSynced;

  UserPreferences({
    this.genreWeights = const {},
    required this.preferredGenres,
    required this.dislikedGenres,
    required this.watchedTmdbIds,
    required this.watchlistTmdbIds,
    required this.likedVideoIds,
    this.lastSynced,
  });

  factory UserPreferences.empty() {
    return UserPreferences(
      genreWeights: {},
      preferredGenres: [],
      dislikedGenres: [],
      watchedTmdbIds: [],
      watchlistTmdbIds: [],
      likedVideoIds: [],
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    // Parse genreWeights carefully
    Map<String, double> weights = {};
    if (json['genreWeights'] != null) {
      final raw = json['genreWeights'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        weights[key] = (value as num).toDouble();
      });
    }

    return UserPreferences(
      genreWeights: weights,
      preferredGenres: List<String>.from(json['preferredGenres'] ?? []),
      dislikedGenres: List<String>.from(json['dislikedGenres'] ?? []),
      watchedTmdbIds: List<int>.from(json['watchedTmdbIds'] ?? []),
      watchlistTmdbIds: List<int>.from(json['watchlistTmdbIds'] ?? []),
      likedVideoIds: List<String>.from(json['likedVideoIds'] ?? []),
      lastSynced: json['lastSynced'] != null
          ? DateTime.parse(json['lastSynced'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'genreWeights': genreWeights,
      'preferredGenres': preferredGenres,
      'dislikedGenres': dislikedGenres,
      'watchedTmdbIds': watchedTmdbIds,
      'watchlistTmdbIds': watchlistTmdbIds,
      'likedVideoIds': likedVideoIds,
      'lastSynced': lastSynced?.toIso8601String(),
    };
  }

  /// Check if user has any preferences set
  bool get hasPreferences =>
      genreWeights.isNotEmpty ||
      preferredGenres.isNotEmpty ||
      watchedTmdbIds.isNotEmpty ||
      watchlistTmdbIds.isNotEmpty;

  /// Get the weight for a specific genre (0.0 if not found)
  /// Uses partial matching for compatibility with different genre naming
  double getGenreWeight(String genre) {
    final lowerGenre = genre.toLowerCase();

    // Try exact match first
    for (final entry in genreWeights.entries) {
      if (entry.key.toLowerCase() == lowerGenre) {
        return entry.value;
      }
    }

    // Try partial match
    for (final entry in genreWeights.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (lowerGenre.contains(lowerKey) || lowerKey.contains(lowerGenre)) {
        return entry.value;
      }
    }

    return 0.0;
  }

  /// Check if a genre is preferred (uses partial matching for compatibility)
  bool isPreferredGenre(String genre) {
    // If we have genre weights, use those
    if (genreWeights.isNotEmpty) {
      return getGenreWeight(genre) > 0.3; // Threshold for "preferred"
    }

    // Fallback to preferredGenres list
    final lowerGenre = genre.toLowerCase();
    return preferredGenres.any((g) {
      final lowerPref = g.toLowerCase();
      // Partial match: "Action" matches "Action", "Sci-Fi" matches "Sci-Fi & Fantasy"
      return lowerGenre.contains(lowerPref) || lowerPref.contains(lowerGenre);
    });
  }

  /// Check if a genre is disliked
  bool isDislikedGenre(String genre) {
    return dislikedGenres.any((g) => g.toLowerCase() == genre.toLowerCase());
  }

  /// Check if a TMDB ID has been watched
  bool hasWatched(int tmdbId) => watchedTmdbIds.contains(tmdbId);

  /// Check if a TMDB ID is in watchlist
  bool isInWatchlist(int tmdbId) => watchlistTmdbIds.contains(tmdbId);

  /// Check if a video has been liked
  bool hasLiked(String videoId) => likedVideoIds.contains(videoId);
}
