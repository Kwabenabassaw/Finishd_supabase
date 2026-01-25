import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../db/objectbox/feed_entities.dart';
import '../db/objectbox/objectbox_store.dart';
import '../objectbox.g.dart';
import 'api_client.dart';
import 'movie_list_service.dart';
import 'user_preferences_service.dart';

/// Content Lake Repository - Offline-first data layer for Supabase-based feeds.
///
/// GOLDEN RULE: UI NEVER waits for network.
///
/// Flow:
/// 1. Return cached data immediately from ObjectBox
/// 2. Check pointer in background (GET /content-lake/pointer/{type})
/// 3. If version changed → fetch new feed → update ObjectBox
/// 4. UI auto-updates via reactive stream
class ContentLakeRepository {
  final ApiClient _apiClient = ApiClient();

  // No boxes for feed items or pointers anymore - we use in-memory cache
  late final Box<SeenItem> _seenBox;

  // In-memory cache for feed items and pointers
  final Map<String, List<CachedFeedItem>> _memoryCache = {};
  final Map<String, FeedPointer> _pointerCache = {};

  // Stream controller to broadcast feed updates to listeners
  final _feedUpdateController = StreamController<String>.broadcast();

  bool _initialized = false;
  Timer? _pollTimer;

  // Callbacks for UI binding
  Function(bool)? onSyncing;
  Function(String)? onError;

  // Polling interval
  static const Duration _pollInterval = Duration(minutes: 5);

  // Singleton pattern for easier access from providers
  static final ContentLakeRepository _instance =
      ContentLakeRepository._internal();
  factory ContentLakeRepository() => _instance;
  ContentLakeRepository._internal();

  // =========================================================================
  // SESSION PROFILE (In-Memory)
  // =========================================================================
  SessionProfile sessionProfile = SessionProfile();

  // User's preferred genres (loaded from Firestore, cached locally)
  List<String> _userGenres = [
    'action',
    'scifi',
    'drama',
  ]; // Defaults until loaded
  List<String> get userGenres => _userGenres;

  // List-derived genres with weights (from finished/favorites/watchlist)
  // Key = genre name (lowercase), Value = weight (higher = stronger signal)
  Map<String, double> _listDerivedGenres = {};

  void updateSessionProfile({String? dominantGenre}) {
    if (dominantGenre != null) {
      sessionProfile.dominantGenre = dominantGenre;
    }
    // Update other signals automatically
    sessionProfile.hourOfDay = DateTime.now().hour;
    sessionProfile.isWeekend = [
      DateTime.saturday,
      DateTime.sunday,
    ].contains(DateTime.now().weekday);
  }

  // =========================================================================
  // INITIALIZATION
  // =========================================================================

  void initialize() {
    if (_initialized) return;

    final store = ObjectBoxStore.instance.store;
    // We only keep the seen items in the local database
    _seenBox = store.box<SeenItem>();
    _initialized = true;

    print('[ContentLakeRepo] Initialized (In-Memory Feed)');
  }

  /// Load user's preferred genres from Firestore.
  /// Call this during provider initialization.
  Future<void> loadUserGenres() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('[ContentLakeRepo] No user logged in, using default genres');
        return;
      }

      final prefsService = UserPreferencesService();
      final prefs = await prefsService.getUserPreferences(userId);

      if (prefs != null && prefs.selectedGenres.isNotEmpty) {
        // Convert to lowercase for matching with feed item genres
        _userGenres = prefs.selectedGenres.map((g) => g.toLowerCase()).toList();
        print('[ContentLakeRepo] ✅ Loaded user genres: $_userGenres');
      } else {
        print('[ContentLakeRepo] No user preferences, using defaults');
      }
    } catch (e) {
      print('[ContentLakeRepo] Error loading user genres: $e');
      // Keep defaults on error
    }
  }

  /// Load genres derived from user's lists (finished, favorites, watchlist).
  /// Call this during provider initialization.
  Future<void> loadListDerivedGenres() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('[ContentLakeRepo] No user logged in, skipping list genres');
        return;
      }

      final movieListService = MovieListService();

      // Fetch items from each list with different weights
      // Finished = highest signal (user completed)
      // Favorites = strong signal (explicit preference)
      // Watchlist = intent signal (wants to watch)
      final finished = await movieListService.getMoviesFromList(
        userId,
        'finished',
      );
      final favorites = await movieListService.getMoviesFromList(
        userId,
        'favorites',
      );
      final watchlist = await movieListService.getMoviesFromList(
        userId,
        'watchlist',
      );

      final genreWeights = <String, double>{};

      // Helper to add genre with weight
      void addGenre(String genreStr, double weight) {
        if (genreStr.isEmpty) return;
        // Handle comma-separated genres
        final genres = genreStr.split(',').map((g) => g.trim().toLowerCase());
        for (final genre in genres) {
          if (genre.isNotEmpty) {
            genreWeights[genre] = (genreWeights[genre] ?? 0) + weight;
          }
        }
      }

      // Weight: Finished = 1.4, Favorites = 1.3, Watchlist = 1.15
      for (final item in finished) {
        addGenre(item.genre, 1.4);
      }
      for (final item in favorites) {
        addGenre(item.genre, 1.3);
      }
      for (final item in watchlist) {
        addGenre(item.genre, 1.15);
      }

      _listDerivedGenres = genreWeights;
      print(
        '[ContentLakeRepo] ✅ Loaded list-derived genres: $_listDerivedGenres',
      );
    } catch (e) {
      print('[ContentLakeRepo] Error loading list genres: $e');
      // Keep empty on error
    }
  }

  // =========================================================================
  // PUBLIC API - UI uses these methods
  // =========================================================================

  /// Get reactive feed stream. UI subscribes to this.
  ///
  /// Returns cached data immediately, then updates when new content arrives.
  Stream<List<CachedFeedItem>> watchFeed(String feedType) async* {
    if (!_initialized) initialize();

    // Initial emission
    yield getVisibleFeed(feedType);

    // Watch for changes in the in-memory cache for this specific type
    yield* _feedUpdateController.stream
        .where((type) => type == feedType || feedType == 'for_you')
        .map((_) => getVisibleFeed(feedType));
  }

  /// Get current cached items (synchronous, for immediate display).
  List<CachedFeedItem> getCachedFeed(String feedType) {
    if (!_initialized) initialize();

    final items = _memoryCache[feedType] ?? [];
    print(
      '[ContentLakeRepo] 📦 getCachedFeed($feedType): ${items.length} items (In-Memory)',
    );
    return items;
  }

  /// Check if we have cached data for a feed type.
  bool hasCachedData(String feedType) {
    return getCachedFeed(feedType).isNotEmpty;
  }

  /// Get visible feed (excludes suppressed items and items without youtubeKey).
  List<CachedFeedItem> getVisibleFeed(String feedType) {
    if (!_initialized) initialize();

    if (feedType == 'for_you') {
      return buildForYouFeed();
    }

    final suppressed = _getSuppressedIds();
    return getCachedFeed(feedType)
        .where((i) => !suppressed.contains(i.id))
        .where(
          (i) => i.youtubeKey != null && i.youtubeKey!.isNotEmpty,
        ) // Bug fix: filter out unplayable items
        .toList();
  }

  /// Start background sync for a feed type.
  ///
  /// Does NOT block. Returns immediately, sync happens in background.
  Future<void> startSync(String feedType) async {
    if (!_initialized) initialize();

    // Cancel existing timer
    _pollTimer?.cancel();

    // If 'for_you', we actually want to ensure dependencies are synced
    if (feedType == 'for_you') {
      unawaited(_syncFeed('trending'));
      unawaited(_syncFeed('latest'));
    } else {
      unawaited(_syncFeed(feedType));
    }

    // Then poll every 5 minutes
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (feedType == 'for_you') {
        _syncFeed('trending');
        _syncFeed('latest');
      } else {
        _syncFeed(feedType);
      }
    });

    print(
      '[ContentLakeRepo] Started sync for $feedType (poll: ${_pollInterval.inMinutes}m)',
    );
  }

  /// Force refresh (bypasses version check).
  Future<void> forceRefresh(String feedType) async {
    if (!_initialized) initialize();

    // Clear local pointer to force fetch
    _pointerCache.remove(feedType);

    await _syncFeed(feedType);
  }

  /// Get current local version for a feed type.
  String? getCurrentVersion(String feedType) {
    if (!_initialized) initialize();

    return _pointerCache[feedType]?.version;
  }

  // =========================================================================
  // SYNC LOGIC
  // =========================================================================

  Future<void> _syncFeed(String feedType) async {
    try {
      onSyncing?.call(true);

      // 1. Fetch pointer from Content Lake API (Public)
      final pointerRes = await _apiClient.getPublic(
        '/content-lake/pointer/$feedType',
      );

      if (pointerRes.statusCode != 200) {
        print(
          '[ContentLakeRepo] Pointer fetch failed: ${pointerRes.statusCode}',
        );
        return;
      }

      // Bug fix: wrap JSON parsing in try-catch
      late final Map<String, dynamic> serverPointer;
      try {
        serverPointer = jsonDecode(pointerRes.body) as Map<String, dynamic>;
      } catch (e) {
        print('[ContentLakeRepo] Invalid pointer JSON: $e');
        return;
      }
      final serverVersion = serverPointer['version'] as String? ?? '';
      if (serverVersion.isEmpty) {
        print('[ContentLakeRepo] Missing version in pointer');
        return;
      }

      // 2. Compare with local pointer
      final localPointer = _pointerCache[feedType];

      if (localPointer?.version == serverVersion) {
        print('[ContentLakeRepo] Already up to date ($serverVersion)');
        return;
      }

      print('''
[ContentLakeRepo] 🚀 NEW VERSION DETECTED
------------------------------------------
Feed: $feedType
Local: ${localPointer?.version ?? 'none'}
Server: $serverVersion
Action: Downloading feed...
------------------------------------------
''');

      // 3. Fetch full feed from Content Lake API (Public)
      final feedRes = await _apiClient.getPublic(
        '/content-lake/feed/$feedType',
        queryParams: {'limit': '200'},
      );

      if (feedRes.statusCode != 200) {
        print('[ContentLakeRepo] Feed fetch failed: ${feedRes.statusCode}');
        return;
      }

      // Bug fix: wrap JSON parsing in try-catch
      late final Map<String, dynamic> feedData;
      try {
        feedData = jsonDecode(feedRes.body) as Map<String, dynamic>;
      } catch (e) {
        print('[ContentLakeRepo] Invalid feed JSON: $e');
        return;
      }
      final itemsList = feedData['items'] as List? ?? [];

      final items = itemsList.asMap().entries.map((entry) {
        return _parseItem(
          entry.value as Map<String, dynamic>,
          feedType,
          serverVersion,
          entry.key,
        );
      }).toList();

      // 4. Update ObjectBox (UI auto-updates via reactive stream)
      await _updateCache(feedType, serverVersion, items, serverPointer);

      print(
        '[ContentLakeRepo] ✅ Synced ${items.length} items for $feedType (First ID: ${items.isNotEmpty ? items.first.id : 'N/A'})',
      );
    } catch (e) {
      print('[ContentLakeRepo] Sync error: $e');
      onError?.call(e.toString());
      // Silent fail - user still sees cached content
    } finally {
      onSyncing?.call(false);
    }
  }

  Future<void> _updateCache(
    String feedType,
    String version,
    List<CachedFeedItem> items,
    Map<String, dynamic> pointerData,
  ) async {
    // Update memory items
    _memoryCache[feedType] = items;

    // Parse expiry time
    DateTime? expiresAt;
    if (pointerData['expiresAt'] != null) {
      try {
        expiresAt = DateTime.parse(pointerData['expiresAt'] as String);
      } catch (_) {
        expiresAt = DateTime.now().add(const Duration(hours: 6));
      }
    }

    // Update memory pointer
    _pointerCache[feedType] = FeedPointer(
      feedType: feedType,
      version: version,
      itemCount: items.length,
      checkedAt: DateTime.now(),
      expiresAt: expiresAt,
    );

    // Notify listeners that this feed has updated
    _feedUpdateController.add(feedType);

    print('''
[ContentLakeRepo] 💾 MEMORY CACHE UPDATED
------------------------------------------
Feed Type: $feedType
Version:   $version
Items:     ${items.length}
Expires:   $expiresAt
------------------------------------------
''');
  }

  CachedFeedItem _parseItem(
    Map<String, dynamic> json,
    String feedType,
    String version,
    int position,
  ) {
    final genres = json['genres'] as List?;

    return CachedFeedItem(
      id: json['id']?.toString() ?? 'item_$position',
      tmdbId: json['tmdbId'] as int?,
      mediaType: json['mediaType'] as String?,
      title: json['title'] as String? ?? '',
      overview: json['overview'] as String?,
      poster: json['poster'] as String?,
      backdrop: json['backdrop'] as String?,
      releaseDate: json['releaseDate'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      voteAverage: (json['voteAverage'] as num?)?.toDouble(),
      youtubeKey: json['youtubeKey'] as String?,
      videoType: json['videoType'] as String?,
      type: json['type'] as String?,
      fallbackThumbnail: json['fallback']?['thumbnail'] as String?,
      fallbackChannel: json['fallback']?['channel'] as String?,
      source: json['source'] as String? ?? 'unknown',
      feedType: feedType,
      position: position,
      version: version,
      cachedAt: DateTime.now(),
      genresJson: genres?.join(','),
    );
  }

  // =========================================================================
  // SEEN/SUPPRESSION TRACKING
  // =========================================================================

  Set<String> _getSuppressedIds() {
    return _seenBox
        .query(SeenItem_.suppressed.equals(true))
        .build()
        .find()
        .map((s) => s.itemId)
        .toSet();
  }

  /// Mark an item as seen (for analytics).
  void markSeen(String itemId) {
    recordEngagement(itemId: itemId);
  }

  /// Record engagement (duration, liked status).
  void recordEngagement({
    required String itemId,
    int? viewDurationMs,
    bool? liked,
  }) {
    if (!_initialized) return;

    final existing = _seenBox
        .query(SeenItem_.itemId.equals(itemId))
        .build()
        .findFirst();

    final now = DateTime.now();
    if (existing == null) {
      _seenBox.put(
        SeenItem(
          itemId: itemId,
          seenAt: now,
          lastSeenAt: now,
          viewDurationMs: viewDurationMs ?? 0,
          liked: liked ?? false,
        ),
      );
    } else {
      existing.lastSeenAt = now;
      if (viewDurationMs != null) {
        existing.viewDurationMs += viewDurationMs;
      }
      if (liked != null) {
        existing.liked = liked;
      }
      _seenBox.put(existing);
    }
  }

  /// Suppress an item (user dismissed it, don't show again).
  void suppress(String itemId) {
    if (!_initialized) return;

    final existing = _seenBox
        .query(SeenItem_.itemId.equals(itemId))
        .build()
        .findFirst();

    if (existing != null) {
      existing.suppressed = true;
      existing.lastSeenAt = DateTime.now();
      _seenBox.put(existing);
    } else {
      final now = DateTime.now();
      _seenBox.put(
        SeenItem(
          itemId: itemId,
          seenAt: now,
          lastSeenAt: now,
          suppressed: true,
        ),
      );
    }
  }

  /// Clear all seen/suppression data.
  void clearSeenData() {
    if (!_initialized) return;
    _seenBox.removeAll();
  }

  // =========================================================================
  // CLIENT-SIDE FEED MIXING (For You tab)
  // =========================================================================

  /// Build "For You" feed with weighted scoring and session awareness.
  List<CachedFeedItem> buildForYouFeed() {
    if (!_initialized) initialize();

    // Use cached user genres (loaded via loadUserGenres)
    final genres = _userGenres;

    final allItems = <CachedFeedItem>[];
    final trending = getCachedFeed('trending');
    final latest = getCachedFeed('latest');

    // Add items from preferred genres
    final genreItems = <CachedFeedItem>[];
    for (final genre in genres) {
      genreItems.addAll(getCachedFeed(genre));
    }

    // Combine all potential items
    allItems.addAll(trending);
    allItems.addAll(latest);
    allItems.addAll(genreItems);

    // Dedup by ID and filter out unplayable items
    final seenIds = <String>{};
    final uniqueItems = allItems
        .where((i) => seenIds.add(i.id))
        .where(
          (i) => i.youtubeKey != null && i.youtubeKey!.isNotEmpty,
        ) // Bug fix: filter out unplayable
        .toList();

    // 1. Calculate Scores
    final scoredItems = uniqueItems.map((item) {
      final score = _calculateScore(item, genres);
      return _ScoredItem(item, score);
    }).toList();

    // 2. Sort by Score (descending)
    scoredItems.sort((a, b) => b.score.compareTo(a.score));

    // 3. Apply Multi-Source Mixing with Wildcards
    final result = <CachedFeedItem>[];
    final usedIds = <String>{};

    // Seeded Shuffle for the top pool to keep variety in a session
    final seed = DateTime.now().day + 12345; // Simulated userId seed
    final topPool = scoredItems.take(100).toList()..shuffle(Random(seed));

    for (var si in topPool) {
      if (result.length >= 200) break;
      result.add(si.item);
      usedIds.add(si.item.id);
    }

    // 4. Start Video Guarantee Logic (Handled in YoutubeFeedProvider)

    return result;
  }

  double _calculateScore(CachedFeedItem item, List<String> userGenres) {
    // 1. Base Score (Try to find persistent meta, fallback to popularity/position)
    final store = ObjectBoxStore.instance.store;
    final metaQuery = store
        .box<FeedItemMeta>()
        .query(FeedItemMeta_.id.equals(item.id))
        .build();
    final meta = metaQuery.findFirst();
    metaQuery.close(); // Bug fix: close query to prevent memory leak

    double baseScore = meta?.baseScore ?? 0.5;

    // Boost base score based on position in source feed
    baseScore += (1.0 - (item.position / 200.0)) * 0.2;

    // 2. Freshness Multiplier (Time Decay)
    final publishedAt = meta?.publishedAt ?? item.cachedAt;
    final daysSincePublish = DateTime.now().difference(publishedAt).inDays;
    final freshnessMultiplier = (1.0 - (daysSincePublish * 0.05)).clamp(
      0.4,
      1.0,
    );

    // 3. Suppression Multiplier (Seen Decay)
    final seen = _seenBox
        .query(SeenItem_.itemId.equals(item.id))
        .build()
        .findFirst();
    double suppressionMultiplier = 1.0;

    if (seen != null) {
      if (seen.suppressed) return 0.0; // Hard suppression

      final hoursSinceSeen = DateTime.now().difference(seen.lastSeenAt).inHours;
      if (hoursSinceSeen < 24) {
        suppressionMultiplier = 0.0; // Hide completely for 24h
      } else if (hoursSinceSeen < 72) {
        suppressionMultiplier = 0.3;
      } else if (hoursSinceSeen < 168) {
        // 7 days
        suppressionMultiplier = 0.6;
      }
    }

    // 4. Interaction Multiplier
    double interactionMultiplier = 1.0;
    if (seen != null) {
      if (seen.liked) interactionMultiplier *= 1.3;
      if (seen.viewDurationMs > 30000) {
        interactionMultiplier *= 1.2; // Watched > 30s
      }
      // We don't punish skip here, that's done via session bias or hard suppression
    }

    // 5. Session & Genre Bias
    double bias = 1.0;
    final itemGenres = item.genres;

    // User Genre Bias (from onboarding)
    bool hasUserGenre = itemGenres.any(
      (g) => userGenres.contains(g.toLowerCase()),
    );
    if (hasUserGenre) bias *= 1.2;

    // Dominant Session Genre Bias
    if (sessionProfile.dominantGenre != null &&
        itemGenres.contains(sessionProfile.dominantGenre)) {
      bias *= 1.2;
    }

    // Night-time Bias (Horror/Thriller)
    if (sessionProfile.hourOfDay >= 20 || sessionProfile.hourOfDay <= 1) {
      if (itemGenres.any(
        (g) => ['horror', 'thriller'].contains(g.toLowerCase()),
      )) {
        bias *= 1.15;
      }
    }

    // 6. List-Derived Genre Bias (from finished/favorites/watchlist)
    // Items matching genres from user's lists get boosted
    if (_listDerivedGenres.isNotEmpty) {
      for (final genre in itemGenres) {
        final weight = _listDerivedGenres[genre.toLowerCase()];
        if (weight != null && weight > 0) {
          // Apply the weight, capped at 1.5x to avoid runaway boosts
          bias *= (1.0 + (weight * 0.1)).clamp(1.0, 1.5);
          break; // Only apply once per item
        }
      }
    }

    return baseScore *
        freshnessMultiplier *
        suppressionMultiplier *
        interactionMultiplier *
        bias;
  }

  // =========================================================================
  // CLEANUP
  // =========================================================================

  /// Clear all cached feed data.
  void clearAll() {
    if (!_initialized) return;
    _memoryCache.clear();
    _pointerCache.clear();
    _seenBox.removeAll();
    print('[ContentLakeRepo] Cleared all memory and seen data');
  }

  void dispose() {
    _pollTimer?.cancel();
    _feedUpdateController.close();
  }
}

// ===========================================================================
// HELPER CLASSES
// ===========================================================================

class SessionProfile {
  String? dominantGenre;
  int hourOfDay = DateTime.now().hour;
  bool isWeekend = false;

  SessionProfile({this.dominantGenre});
}

class _ScoredItem {
  final CachedFeedItem item;
  final double score;

  _ScoredItem(this.item, this.score);
}
