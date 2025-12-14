import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/feed_video.dart';
import '../models/feed_item.dart';
import '../services/api_client.dart';
import '../services/cache/feed_cache_service.dart';

/// YouTube Feed Provider (TikTok-style)
///
/// Production-ready controller management for vertical video feed.
///
/// Key Features:
/// - 3-Controller Window Strategy (prev, current, next)
/// - Muted autoplay for browser/OS policy compliance
/// - Error recovery for restricted videos (100, 101, 105, 150)
/// - Memory-efficient disposal of out-of-window controllers
class YoutubeFeedProvider extends ChangeNotifier {
  // --- State ---
  final Map<int, YoutubePlayerController> _controllers = {};
  final Set<int> _initializing = {};
  final List<FeedVideo> _videos = [];

  int _currentIndex = 0;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isMuted = false; // Start MUTED for autoplay policy
  bool _isDisposed = false;
  bool _hasError = false;
  String? _errorMessage;

  // Restricted error codes that should trigger video removal
  static const _restrictedErrorCodes = {2, 100, 101, 105, 150};

  // API Client
  final ApiClient _apiClient = ApiClient();

  // --- Getters ---
  List<FeedVideo> get videos => _videos;
  int get currentIndex => _currentIndex;
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isMuted => _isMuted;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

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
      // Try cache first for instant display
      final cached = await FeedCacheService.getFeed();
      if (cached != null && cached.isNotEmpty) {
        _videos.addAll(_convertToFeedVideos(cached));
        _isLoading = false;
        notifyListeners();

        // Initialize first window
        _updateControllerWindow(0);

        // Background refresh
        _refreshInBackground();
        return;
      }

      // Load from network
      await _loadFromNetwork();
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error initializing: $e');
      _hasError = true;
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFromNetwork() async {
    try {
      final items = await _apiClient.getPersonalizedFeedV2(
        refresh: false,
        limit: 50,
        page: _currentPage,
      );

      final feedVideos = _convertFeedItemsToVideos(items);
      _videos.clear();
      _videos.addAll(feedVideos);

      // Cache for later
      await FeedCacheService.saveFeed(items.map((e) => e.toJson()).toList());

      // Initialize first window
      if (_videos.isNotEmpty) {
        _updateControllerWindow(0);
      }

      debugPrint('[YTFeed] ✅ Loaded ${_videos.length} videos from network');
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
    if (index >= _videos.length - 5) {
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
    if (_isDisposed || _videos.isEmpty) return;

    // Define the 3-controller window
    final windowIndices = <int>{
      centerIndex - 1, // Previous (for back scroll)
      centerIndex, // Current (playing)
      centerIndex + 1, // Next (pre-loaded)
    }.where((i) => i >= 0 && i < _videos.length).toSet();

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
    if (index < 0 || index >= _videos.length) return;
    if (_controllers.containsKey(index)) return;
    if (_isDisposed) return;

    _initializing.add(index);

    final video = _videos[index];
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
          hideThumbnail: false,
          forceHD: false, // Let it adapt to connection
          useHybridComposition: true, // Better Android performance
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

  // ==========================================================================
  // ERROR RECOVERY - Remove Restricted Videos
  // ==========================================================================

  /// Removes a restricted video and scrolls to next
  /// Called when YouTube returns error 100, 101, 105, or 150
  void removeRestrictedVideo(int index) {
    if (_isDisposed) return;
    if (index < 0 || index >= _videos.length) return;

    final video = _videos[index];
    debugPrint(
      '[YTFeed] ❌ Removing restricted video at $index: ${video.videoId}',
    );

    // 1. Dispose the controller
    _disposeController(index);

    // 2. Remove the video from list
    _videos.removeAt(index);

    // 3. Adjust current index if needed
    if (_videos.isEmpty) {
      _currentIndex = 0;
    } else if (index <= _currentIndex) {
      _currentIndex = (_currentIndex - 1).clamp(0, _videos.length - 1);
    }

    // 4. Update the window with new indices
    _updateControllerWindow(_currentIndex);

    // 5. Play the new current video
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_isDisposed && _videos.isNotEmpty) {
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

  /// Load more videos (next page)
  Future<void> loadMore() async {
    if (_isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      final items = await _apiClient.getPersonalizedFeedV2(
        refresh: false,
        limit: 50,
        page: _currentPage,
      );

      final newVideos = _convertFeedItemsToVideos(items);
      _videos.addAll(newVideos);

      debugPrint(
        '[YTFeed] ✅ Loaded ${newVideos.length} more (page $_currentPage)',
      );
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error loading more: $e');
      _currentPage--; // Revert page increment
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
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initializing.clear();
    _videos.clear();
    _currentIndex = 0;
    _currentPage = 1;
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
    return items
        .map((json) => FeedVideo.fromFeedItem(FeedItem.fromJson(json)))
        .where((v) => v.videoId.isNotEmpty)
        .toList();
  }

  List<FeedVideo> _convertFeedItemsToVideos(List<FeedItem> items) {
    return items
        .map((item) => FeedVideo.fromFeedItem(item))
        .where((v) => v.videoId.isNotEmpty)
        .toList();
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
