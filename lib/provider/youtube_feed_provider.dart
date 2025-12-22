import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/feed_video.dart';
import '../models/feed_item.dart';
import '../services/api_client.dart';

import '../services/cache/feed_cache_service.dart';

/// YouTube Feed Provider (TikTok-style with Three Tabs)
///
/// Production-ready controller management for vertical video feed.
///
/// Key Features:
/// - 3-Controller Window Strategy (prev, current, next)
/// - Three-tab support (Trending, Following, For You)
/// - Muted autoplay for browser/OS policy compliance
/// - Error recovery for restricted videos (100, 101, 105, 150)
/// - Memory-efficient disposal of out-of-window controllers
class YoutubeFeedProvider extends ChangeNotifier {
  // --- State ---
  final Map<int, YoutubePlayerController> _controllers = {};
  final Set<int> _initializing = {};

  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isMuted = false; // Start MUTED for autoplay policy
  bool _isDisposed = false;
  bool _hasError = false;
  String? _errorMessage;

  // --- NEW: Multi-tab state ---
  FeedType _activeFeedType = FeedType.forYou;

  // Separate video lists per tab
  final Map<FeedType, List<FeedVideo>> _feedsByType = {
    FeedType.trending: [],
    FeedType.following: [],
    FeedType.forYou: [],
  };

  // Separate pagination per tab
  final Map<FeedType, int> _pagesByType = {
    FeedType.trending: 1,
    FeedType.following: 1,
    FeedType.forYou: 1,
  };

  // Restricted error codes that should trigger video removal
  static const _restrictedErrorCodes = {2, 100, 101, 105, 150};

  // API Client
  final ApiClient _apiClient = ApiClient();

  // --- Getters ---
  List<FeedVideo> get videos => _feedsByType[_activeFeedType] ?? [];
  int get currentIndex => _currentIndex;
  int get currentPage => _pagesByType[_activeFeedType] ?? 1;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isMuted => _isMuted;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  FeedType get activeFeedType => _activeFeedType; // NEW

  /// Get controller for specific index (null if not in window)
  YoutubePlayerController? getController(int index) => _controllers[index];

  /// Check if controller exists for index
  bool hasController(int index) => _controllers.containsKey(index);

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initialize provider - load from cache first, then network
  Future<void> initialize() async {
    if (_isLoading) return;

    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      // TEMP FIX: Clear stale cache that may not have youtubeKeys
      // TODO: Remove this after confirming the fix works
      debugPrint('[YTFeed] 🗑️ Clearing stale cache to force fresh data');
      await FeedCacheService.clearFeed();

      // Try cache first for instant display (only for ForYou feed)
      final cached = await FeedCacheService.getFeed();
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[YTFeed] 📦 Found ${cached.length} cached items');

        // DEBUG: Check first item's youtubeKey
        if (cached.isNotEmpty) {
          final firstCached = cached[0];
          debugPrint(
            '[YTFeed] 🔍 First cached item: ${firstCached['title']}, youtubeKey: ${firstCached['youtubeKey']}',
          );
        }

        final feedVideos = _convertToFeedVideos(cached);

        if (feedVideos.isEmpty) {
          debugPrint(
            '[YTFeed] ⚠️ All cached items filtered out (no valid youtubeKey), loading from network',
          );
          await _loadFromNetwork();
        } else {
          _feedsByType[FeedType.forYou]!.addAll(feedVideos);
          _isLoading = false;
          notifyListeners();

          // Initialize first window
          _updateControllerWindow(0);

          // Background refresh
          _refreshInBackground();
          return;
        }
      } else {
        debugPrint('[YTFeed] 📭 No cached feed, loading from network');
        // Load from network
        await _loadFromNetwork();
      }
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error initializing: $e');
      _hasError = true;
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Switch to a different feed type (Trending, Following, For You)
  Future<void> switchFeedType(FeedType type) async {
    if (type == _activeFeedType) return;

    debugPrint(
      '[YTFeed] 🔄 Switching feed: ${_activeFeedType.value} → ${type.value}',
    );

    // 1. Pause current video
    _pauseController(_currentIndex);

    // 2. Dispose all controllers (clean slate for new tab)
    _disposeAllControllers();

    // 3. Update active feed type
    _activeFeedType = type;
    _currentIndex = 0;

    // 4. Check if we have content for this tab
    final currentFeed = _feedsByType[type]!;

    if (currentFeed.isEmpty) {
      // Load from network for this feed type
      _isLoading = true;
      notifyListeners();

      await _loadFromNetwork();

      _isLoading = false;
    } else {
      // Use cached content, initialize controllers
      _updateControllerWindow(0);
    }

    notifyListeners();
  }

  Future<void> _loadFromNetwork() async {
    try {
      final feedType = _activeFeedType;
      final page = _pagesByType[feedType] ?? 1;

      final items = await _apiClient.getPersonalizedFeedV2(
        refresh: false,
        limit: 50,
        page: page,
        feedType: feedType, // NEW: Pass feed type to API
      );

      // DEBUG: Log raw API response count and youtubeKey status
      final itemsWithKey = items
          .where((i) => i.youtubeKey != null && i.youtubeKey!.isNotEmpty)
          .length;
      debugPrint(
        '[YTFeed] 📊 API returned ${items.length} items, ${itemsWithKey} have youtubeKey',
      );

      final feedVideos = _convertFeedItemsToVideos(items);
      _feedsByType[feedType]!.clear();
      _feedsByType[feedType]!.addAll(feedVideos);

      // Cache for later (only ForYou feed)
      if (feedType == FeedType.forYou) {
        await FeedCacheService.saveFeed(items.map((e) => e.toJson()).toList());
      }

      // Initialize first window
      if (_feedsByType[feedType]!.isNotEmpty) {
        _updateControllerWindow(0);
      }

      debugPrint(
        '[YTFeed] ✅ Loaded ${feedVideos.length} ${feedType.value} videos from network (filtered from ${items.length} items)',
      );
    } catch (e) {
      debugPrint('[YTFeed] ❌ Network error: $e');
      _hasError = true;
      _errorMessage = e.toString();
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      final items = await _apiClient.getPersonalizedFeedV2(
        refresh: true,
        limit: 50,
        page: 1,
      );

      if (items.isNotEmpty) {
        await FeedCacheService.saveFeed(items.map((e) => e.toJson()).toList());
        debugPrint('[YTFeed] ✅ Background refresh complete');
      }
    } catch (e) {
      debugPrint('[YTFeed] ⚠️ Background refresh failed: $e');
    }
  }

  // ==========================================================================
  // PAGE CHANGE HANDLER (Core Logic)
  // ==========================================================================

  /// Called when user scrolls to a new page.
  /// Handles: pause old → update index → play new → update window
  void onPageChanged(int index) {
    if (_isDisposed || index == _currentIndex) return;

    debugPrint('[YTFeed] 📱 Page changed: $_currentIndex → $index');

    // 1. Pause the previous video
    _pauseController(_currentIndex);

    // 2. Update current index
    _currentIndex = index;

    // 3. Update the window (creates new, disposes old)
    _updateControllerWindow(index);

    // 4. Play the new video with retry mechanism
    _playWithRetry(index);

    // 5. Load more if near end (pagination)
    if (index >= videos.length - 5) {
      loadMore();
    }

    notifyListeners();
  }

  /// Plays the video at index with retry mechanism
  /// Retries up to 5 times if controller isn't ready or video doesn't start
  void _playWithRetry(int index, [int attempt = 0]) {
    if (_isDisposed || _currentIndex != index) return;
    if (attempt >= 5) {
      debugPrint('[YTFeed] ⚠️ Failed to play index $index after 5 attempts');
      return;
    }

    final controller = _controllers[index];

    if (controller != null) {
      debugPrint('[YTFeed] ▶️ Playing index $index (attempt $attempt)');
      controller.play();

      // Verify it actually started playing after a short delay
      Future.delayed(Duration(milliseconds: 300 + (attempt * 200)), () {
        if (_isDisposed || _currentIndex != index) return;

        final currentController = _controllers[index];
        if (currentController != null && !currentController.value.isPlaying) {
          debugPrint('[YTFeed] ⚠️ Video at $index not playing, retrying...');
          _playWithRetry(index, attempt + 1);
        }
      });
    } else {
      // Controller not ready yet, retry with delay
      final delay = Duration(milliseconds: 150 + (attempt * 150));
      debugPrint(
        '[YTFeed] ⏳ Controller not ready for $index, retrying in ${delay.inMilliseconds}ms...',
      );
      Future.delayed(delay, () => _playWithRetry(index, attempt + 1));
    }
  }

  // ==========================================================================
  // 3-CONTROLLER WINDOW STRATEGY (Memory Management)
  // ==========================================================================

  /// Maintains only 3 controllers: [current-1, current, current+1]
  /// Disposes any controller outside this window immediately.
  void _updateControllerWindow(int centerIndex) {
    if (_isDisposed || videos.isEmpty) return;

    // Define the 3-controller window
    // Strict Single-Controller Strategy
    // We only keep the CURRENT controller to force a fresh session on ANY scroll.
    // This fixes persistent "Watch on YouTube" errors by preventing reuse of stale sessions.
    final windowIndices = <int>{
      centerIndex,
    }.where((i) => i >= 0 && i < videos.length).toSet();

    // 1. DISPOSE controllers outside the window
    final toDispose = _controllers.keys
        .where((key) => !windowIndices.contains(key))
        .toList();

    for (final index in toDispose) {
      debugPrint('[YTFeed] 🗑️ Disposing controller at index $index');
      _disposeController(index);
    }

    // 2. CREATE missing controllers in window
    for (final index in windowIndices) {
      if (!_controllers.containsKey(index) && !_initializing.contains(index)) {
        _createController(index);
      }
    }

    debugPrint('[YTFeed] 🎮 Active controllers: ${_controllers.keys.toList()}');
  }

  // ==========================================================================
  // CONTROLLER LIFECYCLE
  // ==========================================================================

  /// Creates a YoutubePlayerController with MUTED AUTOPLAY
  void _createController(int index) {
    if (index < 0 || index >= videos.length) return;
    if (_controllers.containsKey(index)) return;
    if (_isDisposed) return;

    _initializing.add(index);

    final video = videos[index];
    final videoId = video.videoId;

    if (videoId.isEmpty) {
      debugPrint('[YTFeed] ⚠️ Empty videoId at index $index');

      _initializing.remove(index);
      return;
    }

    debugPrint(
      '[YTFeed] 🎬 Creating controller for index $index: ${video.title}',
    );

    try {
      final controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay:
              false, // Don't rely on this - we'll manually play the current video
          mute: _isMuted, // Use the current mute state
          loop: true,
          disableDragSeek: true, // Prevents gesture conflicts
          enableCaption: false,
          hideControls: true,
          hideThumbnail: true,
          forceHD: false, // Let it adapt to connection
          useHybridComposition:
              false, // Performance: False = Texture Mode (Much faster)
        ),
      );

      // Add listener for error detection
      controller.addListener(() {
        if (_isDisposed) return;
        _handleControllerUpdate(index, controller);
      });

      _controllers[index] = controller;
      _initializing.remove(index);

      debugPrint('[YTFeed] ✅ Controller ready for index $index');
      notifyListeners();
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error creating controller for index $index: $e');
      _initializing.remove(index);
    }
  }

  /// Handle controller state changes (including errors)
  /// CRITICAL: Only notify on actual errors, not every frame update!
  void _handleControllerUpdate(int index, YoutubePlayerController controller) {
    // Only check for YouTube player errors - don't notify on every update!
    final errorCode = controller.value.errorCode;
    if (errorCode != 0) {
      debugPrint('[YTFeed] ❌ Player error at index $index: code $errorCode');

      // If it's a permanent restriction error, remove the video
      if (_restrictedErrorCodes.contains(errorCode)) {
        removeRestrictedVideo(index);
      }
    }
    // NOTE: Do NOT call notifyListeners() here!
    // It was causing infinite rebuilds and the self-scrolling bug
  }

  /// Dispose a single controller
  void _disposeController(int index) {
    final controller = _controllers.remove(index);
    if (controller != null) {
      controller.pause();
      controller.dispose();
    }
    _initializing.remove(index);
  }

  /// Dispose all controllers (used when switching tabs)
  void _disposeAllControllers() {
    debugPrint('[YTFeed] 🗑️ Disposing all ${_controllers.length} controllers');
    for (final index in _controllers.keys.toList()) {
      _disposeController(index);
    }
  }

  // ==========================================================================
  // ERROR RECOVERY - Remove Restricted Videos
  // ==========================================================================

  /// Removes a restricted video and scrolls to next
  /// Called when YouTube returns error 100, 101, 105, or 150
  void removeRestrictedVideo(int index) {
    if (_isDisposed) return;
    final feedList = _feedsByType[_activeFeedType]!;
    if (index < 0 || index >= feedList.length) return;

    final video = feedList[index];
    debugPrint(
      '[YTFeed] ❌ Removing restricted video at $index: ${video.videoId}',
    );

    // 1. Dispose the controller
    _disposeController(index);

    // 2. Remove the video from list
    feedList.removeAt(index);

    // 3. Adjust current index if needed
    if (feedList.isEmpty) {
      _currentIndex = 0;
    } else if (index <= _currentIndex) {
      _currentIndex = (_currentIndex - 1).clamp(0, feedList.length - 1);
    }

    // 4. Update the window with new indices
    _updateControllerWindow(_currentIndex);

    // 5. Play the new current video
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_isDisposed && feedList.isNotEmpty) {
        _playController(_currentIndex);
      }
    });

    notifyListeners();
  }

  // ==========================================================================
  // PLAYBACK CONTROL
  // ==========================================================================

  void _playController(int index) {
    final controller = _controllers[index];
    if (controller != null) {
      debugPrint('[YTFeed] ▶️ Playing index $index');
      controller.play();
    }
  }

  void _pauseController(int index) {
    final controller = _controllers[index];
    if (controller != null) {
      debugPrint('[YTFeed] ⏸️ Pausing index $index');
      controller.pause();
    }
  }

  /// Public: Play video at index
  void play(int index) => _playController(index);

  /// Public: Pause video at index
  void pause(int index) => _pauseController(index);

  /// Pause all videos (for app lifecycle)
  void pauseAll() {
    for (final controller in _controllers.values) {
      controller.pause();
    }
  }

  /// Resume current video (for app lifecycle)
  void resumeCurrent() {
    _playController(_currentIndex);
  }

  // ==========================================================================
  // MUTE CONTROL
  // ==========================================================================

  /// Toggle mute for CURRENT video only
  void toggleMute() {
    _isMuted = !_isMuted;

    // Only affect current controller
    final controller = _controllers[_currentIndex];
    if (controller != null) {
      if (_isMuted) {
        controller.mute();
        debugPrint('[YTFeed] 🔇 Muted');
      } else {
        controller.unMute();
        debugPrint('[YTFeed] 🔊 Unmuted');
      }
    }

    notifyListeners();
  }

  /// Set mute state explicitly
  void setMuted(bool muted) {
    _isMuted = muted;

    final controller = _controllers[_currentIndex];
    if (controller != null) {
      if (muted) {
        controller.mute();
      } else {
        controller.unMute();
      }
    }

    notifyListeners();
  }

  // ==========================================================================
  // PAGINATION
  // ==========================================================================

  /// Load more videos (next page) for the active feed type
  Future<void> loadMore() async {
    if (_isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final feedType = _activeFeedType;
      final currentPage = (_pagesByType[feedType] ?? 1);
      final nextPage = currentPage + 1;

      final items = await _apiClient.getPersonalizedFeedV2(
        refresh: false,
        limit: 50,
        page: nextPage,
        feedType: feedType, // Use active feed type
      );

      final newVideos = _convertFeedItemsToVideos(items);
      _feedsByType[feedType]!.addAll(newVideos);
      _pagesByType[feedType] = nextPage;

      debugPrint(
        '[YTFeed] ✅ Loaded ${newVideos.length} more ${feedType.value} (page $nextPage)',
      );
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error loading more: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  /// Force refresh - clear everything and reload
  Future<void> refresh() async {
    // Dispose all controllers
    _disposeAllControllers();
    _initializing.clear();

    // Clear all feed lists
    for (final feedType in FeedType.values) {
      _feedsByType[feedType]!.clear();
      _pagesByType[feedType] = 1;
    }

    _currentIndex = 0;
    _hasError = false;
    _errorMessage = null;

    // Clear cache
    await FeedCacheService.clearFeed();

    // Reload
    await initialize();
  }

  /// Trigger backend refresh (cron job)
  Future<bool> triggerBackendRefresh() async {
    try {
      return await _apiClient.triggerBackendRefresh();
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error triggering backend refresh: $e');
      return false;
    }
  }

  // ==========================================================================
  // CONVERSION HELPERS
  // ==========================================================================

  List<FeedVideo> _convertToFeedVideos(List<Map<String, dynamic>> items) {
    debugPrint(
      '[YTFeed] 🔄 Converting ${items.length} cached items to FeedVideos',
    );
    final converted = items
        .map((json) => FeedVideo.fromFeedItem(FeedItem.fromJson(json)))
        .toList();
    final filtered = converted.where((v) => v.videoId.isNotEmpty).toList();
    debugPrint(
      '[YTFeed] 📊 Cached conversion: ${converted.length} total, ${filtered.length} with valid videoId',
    );
    return filtered;
  }

  List<FeedVideo> _convertFeedItemsToVideos(List<FeedItem> items) {
    debugPrint(
      '[YTFeed] 🔄 Converting ${items.length} FeedItems to FeedVideos',
    );
    final converted = items
        .map((item) => FeedVideo.fromFeedItem(item))
        .toList();
    final filtered = converted.where((v) => v.videoId.isNotEmpty).toList();
    debugPrint(
      '[YTFeed] 📊 Network conversion: ${converted.length} total, ${filtered.length} with valid videoId',
    );
    if (filtered.length < converted.length) {
      debugPrint(
        '[YTFeed] ⚠️ Filtered out ${converted.length - filtered.length} items without videoId',
      );
    }
    return filtered;
  }

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

  @override
  void dispose() {
    debugPrint('[YTFeed] 🧹 Disposing YoutubeFeedProvider');
    _isDisposed = true;

    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initializing.clear();

    super.dispose();
  }
}
