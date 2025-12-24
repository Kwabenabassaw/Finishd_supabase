import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  /// Sync preferences from Firestore and cache locally
  Future<UserPreferences> syncFromFirestore(String userId) async {
    try {
      // Auto-detect user ID if empty string passed
      String effectiveUserId = userId;
      if (userId.isEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          return UserPreferences.empty();
        }
        effectiveUserId = currentUser.uid;
      }

      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(effectiveUserId).get();

      if (!userDoc.exists) {
        return UserPreferences.empty();
      }

      final data = userDoc.data()!;
      final prefsData = data['preferences'] as Map<String, dynamic>? ?? {};

      // Extract preferred genres from onboarding selection
      final selectedGenres = List<String>.from(
        prefsData['selectedGenres'] ?? [],
      );

      print('[PrefsCache] syncing for user: $effectiveUserId');
      print('[PrefsCache] selectedGenres: ${selectedGenres.length}');

      // Get watched TMDB IDs from various collections
      final watchedIds = await _getWatchedTmdbIds(effectiveUserId);

      // Get watchlist IDs
      final watchlistIds = await _getCollectionIds(
        effectiveUserId,
        'watchlist',
      );

      // Get recommendation IDs (movies recommended to user — signals interest)
      final recommendedIds = await _getRecommendedMovieIds(effectiveUserId);

      // Merge watchlist and recommended IDs
      final combinedWatchlist = {...watchlistIds, ...recommendedIds}.toList();

      // Get liked video IDs
      final likedVideos = await _getLikedVideoIds(effectiveUserId);

      // Calculate genre weights from watch history
      final genreWeights = await _calculateGenreWeights(effectiveUserId);

      print(
        '[PrefsCache] Final sync: ${selectedGenres.length} genres, '
        '${watchedIds.length} watched, ${combinedWatchlist.length} watchlist, '
        '${genreWeights.length} weighted genres',
      );

      if (genreWeights.isNotEmpty) {
        print(
          '[PrefsCache] Top weights: ${genreWeights.entries.take(3).map((e) => "${e.key}:${e.value.toStringAsFixed(2)}").join(", ")}',
        );
      }

      final prefs = UserPreferences(
        genreWeights: genreWeights,
        preferredGenres: selectedGenres,
        dislikedGenres: [], // Can be extended with user settings
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
      // Return cached or empty on error
      return _cached ?? UserPreferences.empty();
    }
  }

  /// Calculate genre weights from user's watch history
  /// Weight multipliers:
  /// - favorites: 2.0
  /// - finished: 1.5
  /// - watching: 1.0
  /// - watchlist: 0.5
  Future<Map<String, double>> _calculateGenreWeights(String userId) async {
    final db = FirebaseFirestore.instance;
    final genreScores = <String, double>{};

    // Weight multipliers by collection
    final collectionWeights = {
      'favorites': 2.0,
      'finished': 1.5,
      'watching': 1.0,
      'watchlist': 0.5,
    };

    for (final entry in collectionWeights.entries) {
      final collectionName = entry.key;
      final multiplier = entry.value;

      try {
        final docs = await db
            .collection('users')
            .doc(userId)
            .collection(collectionName)
            .limit(100)
            .get();

        for (final doc in docs.docs) {
          final data = doc.data();

          // Extract genres from the document
          final genres = _extractGenresFromItem(data);

          for (final genre in genres) {
            genreScores[genre] = (genreScores[genre] ?? 0) + multiplier;
          }
        }
      } catch (e) {
        print('[PrefsCache] Error reading $collectionName for weights: $e');
      }
    }

    if (genreScores.isEmpty) {
      return {};
    }

    // Normalize to [0.0, 1.0]
    final maxScore = genreScores.values.reduce((a, b) => a > b ? a : b);
    final normalized = <String, double>{};

    final sortedEntries = genreScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      normalized[entry.key] = double.parse(
        (entry.value / maxScore).toStringAsFixed(3),
      );
    }

    return normalized;
  }

  /// Extract genre names from an item document
  List<String> _extractGenresFromItem(Map<String, dynamic> data) {
    final genres = <String>[];

    // Try 'genres' field (list)
    if (data['genres'] != null) {
      final raw = data['genres'];
      if (raw is List) {
        for (final g in raw) {
          if (g is String) {
            genres.add(g);
          } else if (g is Map && g['name'] != null) {
            genres.add(g['name'].toString());
          }
        }
      }
    }

    // Try 'genre' field (string, possibly comma-separated)
    if (data['genre'] != null && data['genre'] is String) {
      final genreStr = data['genre'] as String;
      for (final g in genreStr.split(',')) {
        final trimmed = g.trim();
        if (trimmed.isNotEmpty && !genres.contains(trimmed)) {
          genres.add(trimmed);
        }
      }
    }

    return genres;
  }

  Future<List<int>> _getWatchedTmdbIds(String userId) async {
    return _getCollectionIds(userId, ['watching', 'finished', 'favorites']);
  }

  Future<List<int>> _getCollectionIds(
    String userId,
    dynamic collectionOrList,
  ) async {
    final ids = <int>[];
    final db = FirebaseFirestore.instance;
    final collections = collectionOrList is List
        ? collectionOrList
        : [collectionOrList];

    for (final collection in collections) {
      try {
        final docs = await db
            .collection('users')
            .doc(userId)
            .collection(collection.toString())
            .limit(100)
            .get();

        print('[PrefsCache] Found ${docs.docs.length} items in $collection');

        for (final doc in docs.docs) {
          // MovieListItem stores TMDB ID as 'id' field (string), not 'tmdbId'
          // The document ID is also the TMDB ID
          final data = doc.data();
          final idValue = data['id'] ?? data['tmdbId'] ?? doc.id;

          if (idValue != null) {
            final parsedId = idValue is int
                ? idValue
                : int.tryParse(idValue.toString());
            if (parsedId != null && parsedId > 0) {
              ids.add(parsedId);
            }
          }
        }
      } catch (e) {
        print('[PrefsCache] Error reading $collection: $e');
        // Continue on collection errors
      }
    }

    print(
      '[PrefsCache] Total IDs from ${collections.join(",")}: ${ids.length}',
    );
    return ids;
  }

  /// Get TMDB IDs from recommendations received by the user
  Future<List<int>> _getRecommendedMovieIds(String userId) async {
    final ids = <int>[];
    final db = FirebaseFirestore.instance;

    try {
      // Recommendations are stored at root level /recommendations
      final docs = await db
          .collection('recommendations')
          .where('toUserId', isEqualTo: userId)
          .limit(50)
          .get();

      print('[PrefsCache] Found ${docs.docs.length} recommendations for user');

      for (final doc in docs.docs) {
        final movieId = doc.data()['movieId'];
        if (movieId != null) {
          final parsedId = movieId is int
              ? movieId
              : int.tryParse(movieId.toString());
          if (parsedId != null && parsedId > 0) {
            ids.add(parsedId);
          }
        }
      }
    } catch (e) {
      print('[PrefsCache] Error reading recommendations: $e');
    }

    return ids;
  }

  Future<List<String>> _getLikedVideoIds(String userId) async {
    final ids = <String>[];
    final db = FirebaseFirestore.instance;

    try {
      final docs = await db
          .collection('users')
          .doc(userId)
          .collection('liked_videos')
          .limit(100)
          .get();

      for (final doc in docs.docs) {
        ids.add(doc.id);
      }
    } catch (e) {
      // Ignore errors
    }

    return ids;
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
