import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/feed_item.dart';
import '../models/feed_video.dart';
import '../services/api_client.dart';
import '../services/seen_repository.dart';

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
  final Map<int, String> _controllerVideoIds =
      {}; // Track which video ID is in which controller
  final Set<int> _initializing = {};
  final List<Timer> _pendingTimers = []; // Track timers for cleanup

  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isMuted =
      true; // Start MUTED for autoplay policy compliance (OS requirement)
  bool _isDisposed = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLifecyclePaused = false; // Prevents playback when app/tab is hidden

  DateTime? _videoStartTime;

  // --- Navigation/Jumping ---
  final _jumpToPageController = StreamController<int>.broadcast();
  Stream<int> get jumpToPageStream => _jumpToPageController.stream;

  // --- NEW: Multi-tab state ---
  FeedType _activeFeedType = FeedType.forYou;

  // Separate video lists per tab
  final Map<FeedType, List<FeedVideo>> _feedsByType = {
    FeedType.trending: [],
    FeedType.following: [],
    FeedType.forYou: [],
  };

  // Preload window configuration
  static const int _preloadNextCount = 3;
  static const int _preloadPrevCount = 1;

  // Restricted error codes that should trigger video removal
  static const _restrictedErrorCodes = {2, 100, 101, 105, 150};

  // API Client
  final ApiClient _apiClient = ApiClient();

  // ============================================================================
  // FEED BACKEND
  // ============================================================================
  // The app now uses the Generator & Hydrator backend exclusively.
  // Legacy ObjectBox synchronization for feed videos has been removed.

  /// Tab-specific cursors for pagination with new feed backend
  final Map<FeedType, String?> _cursorsByType = {
    FeedType.trending: null,
    FeedType.following: null,
    FeedType.forYou: null,
  };

  /// Track if we have more items to load per tab
  final Map<FeedType, bool> _hasMoreByType = {
    FeedType.trending: true,
    FeedType.following: true,
    FeedType.forYou: true,
  };

  /// Track page counts for UI display (debug menu)
  final Map<FeedType, int> _pageCountsByType = {
    FeedType.trending: 1,
    FeedType.following: 1,
    FeedType.forYou: 1,
  };

  /// Analytics event queue for batched sending
  final List<Map<String, dynamic>> _pendingAnalyticsEvents = [];
  Timer? _analyticsFlushTimer;

  // --- Getters ---
  List<FeedVideo> get videos => _feedsByType[_activeFeedType] ?? [];
  int get currentIndex => _currentIndex;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isMuted => _isMuted;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  FeedType get activeFeedType => _activeFeedType;
  int get currentPage => _pageCountsByType[_activeFeedType] ?? 1; // NEW

  /// Get controller for specific index (null if not in window)
  YoutubePlayerController? getController(int index) => _controllers[index];

  /// Check if controller exists for index
  bool hasController(int index) => _controllers.containsKey(index);

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initialize provider - uses the new Generator & Hydrator backend
  Future<void> initialize() async {
    if (_isLoading) return;

    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      debugPrint('[YTFeed] 🚀 Initializing with NEW feed backend');
      await _fetchTabFeed(_activeFeedType, limit: 100);

      // Start analytics flush timer
      _startAnalyticsFlushTimer();
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error initializing: $e');
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Internal: Fetch feed for a specific tab from backend
  Future<void> _fetchTabFeed(FeedType type, {int limit = 40}) async {
    try {
      debugPrint('[YTFeed] 📥 Fetching $type feed...');

      final response = await _apiClient.getFeedV3(
        feedType: type,
        limit: limit,
        cursor: _cursorsByType[type],
      );

      // Store cursor for next pagination call
      if (response.nextCursor != null) {
        _pageCountsByType[type] = (_pageCountsByType[type] ?? 1) + 1;
      }
      _cursorsByType[type] = response.nextCursor;
      _hasMoreByType[type] = response.hasMore;

      // Get seen IDs for local filtering (only used for For You)
      final seenIds = SeenRepository.instance.getSeenIds();

      // DEBUG: Log raw feed count
      debugPrint(
        '[YTFeed] 📦 Raw feed items from backend: ${response.feed.length}',
      );

      // Filter: Keep items with valid content (video OR image)
      final validItems = response.feed
          .where(
            (item) =>
                (item.youtubeKey != null && item.youtubeKey!.isNotEmpty) ||
                (item.isImage &&
                    item.imageUrl != null &&
                    item.imageUrl!.isNotEmpty),
          )
          .toList();
      debugPrint(
        '[YTFeed] 🎬 Valid items (videos: ${validItems.where((i) => !i.isImage).length}, images: ${validItems.where((i) => i.isImage).length})',
      );

      // Apply seen filter ONLY for "For You" feed, not for Trending
      List<FeedItem> filteredItems;
      if (type == FeedType.forYou) {
        filteredItems = validItems
            .where((item) => item.isImage || !seenIds.contains(item.youtubeKey))
            .toList();
        debugPrint(
          '[YTFeed] 👁️ For You after seen filter: ${filteredItems.length} (seen: ${seenIds.length})',
        );
      } else {
        // Trending and Following: no seen filter
        filteredItems = validItems;
      }

      // Convert to FeedVideo
      final feedVideos = filteredItems
          .map((item) => FeedVideo.fromFeedItem(item))
          .toList();

      // Shuffle trending feed for variety on each load
      if (type == FeedType.trending) {
        feedVideos.shuffle();
      }

      debugPrint('[YTFeed] ✅ Got ${feedVideos.length} videos for $type');

      // Update the feed list
      if (_cursorsByType[type] == null || _feedsByType[type]!.isEmpty) {
        // Initial fetch or fresh start
        _feedsByType[type] = feedVideos;
      } else {
        // Append
        _feedsByType[type]!.addAll(feedVideos);
      }

      // If active tab and we have content, ensure playback
      if (type == _activeFeedType && _feedsByType[type]!.isNotEmpty) {
        if (!_controllers.containsKey(_currentIndex)) {
          _updateControllerWindow(_currentIndex);
          _waitForControllerAndPlay(_currentIndex);
        }
      }
    } catch (e) {
      debugPrint('[YTFeed] ❌ Fetch failed for $type: $e');
      if (_feedsByType[type]!.isEmpty) {
        rethrow;
      }
    }
  }

  // ==========================================================================
  // ANALYTICS TRACKING (New Backend)
  // ==========================================================================

  void _startAnalyticsFlushTimer() {
    _analyticsFlushTimer?.cancel();
    _analyticsFlushTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _flushAnalyticsEvents(),
    );
  }

  /// Track a view event for analytics and mark as seen
  void trackViewEvent(String itemId, {int? durationMs}) {
    // Mark as seen in local ObjectBox (for deduplication)
    SeenRepository.instance.markSeen(itemId, viewDurationMs: durationMs ?? 0);

    if (_pendingAnalyticsEvents.length > 50) return; // Prevent memory bloat

    _pendingAnalyticsEvents.add({
      'eventType': 'view',
      'itemId': itemId,
      'timestamp': DateTime.now().toIso8601String(),
      if (durationMs != null) 'durationWatched': durationMs,
    });

    debugPrint('[YTFeed] 📊 Queued view event for $itemId (marked seen)');
  }

  /// Flush pending analytics events to backend
  Future<void> _flushAnalyticsEvents() async {
    if (_pendingAnalyticsEvents.isEmpty) return;

    final events = List<Map<String, dynamic>>.from(_pendingAnalyticsEvents);
    _pendingAnalyticsEvents.clear();

    try {
      await _apiClient.trackAnalyticsEvents(events: events);
      debugPrint('[YTFeed] ✅ Flushed ${events.length} analytics events');
    } catch (e) {
      debugPrint('[YTFeed] ❌ Analytics flush failed: $e');
      // Re-queue events on failure
      _pendingAnalyticsEvents.addAll(events);
    }
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
    notifyListeners();

    // 4. Fetch if empty, otherwise UI will update from State
    if (videos.isEmpty) {
      _isLoading = true;
      notifyListeners();
      try {
        await _fetchTabFeed(type);
      } catch (e) {
        _hasError = true;
        _errorMessage = e.toString();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      // Content exists, just update window and play
      _updateControllerWindow(0);
      _waitForControllerAndPlay(0);
      notifyListeners();
    }
  }

  // REMOVED _loadFromNetwork - logic is now in FeedSyncService

  // ==========================================================================
  // PAGE CHANGE HANDLER (Core Logic)
  // ==========================================================================

  /// Called when user scrolls to a new page.
  /// Handles: pause old → update index → play new → update window
  void onPageChanged(int index) {
    if (_isDisposed || index == _currentIndex) return;

    debugPrint('[YTFeed] 📱 Page changed: $_currentIndex → $index');

    // 0. Record view duration for previous video
    _recordEngagement(_currentIndex);

    // 1. Pause the previous video
    _pauseController(_currentIndex);

    // 2. Update current index
    _currentIndex = index;
    _videoStartTime = DateTime.now();

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

  /// Robustly waits for a controller to be created AND READY, then plays it.
  /// Checks every 100ms up to 15 times (1.5 seconds total).
  void _waitForControllerAndPlay(int index) {
    if (_isDisposed || _isLifecyclePaused) return;

    int checks = 0;
    late final Timer timer;
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isDisposed || _isLifecyclePaused) {
        timer.cancel();
        _pendingTimers.remove(timer);
        return;
      }

      final controller = _controllers[index];
      // CRITICAL: Check both existence AND readiness
      if (controller != null && controller.value.isReady) {
        timer.cancel();
        _pendingTimers.remove(timer);
        debugPrint(
          '[YTFeed] ✅ Controller ready for $index after ${checks * 100}ms, playing...',
        );
        _playWithRetry(index);
      } else {
        checks++;
        // Use a shorter timeout (1.5s) to avoid leaving user hanging
        // If it's not ready by then, we force play and hope queueing works.
        if (checks >= 15) {
          timer.cancel();
          _pendingTimers.remove(timer); // FIX Bug #1: Prevent memory leak
          debugPrint(
            '[YTFeed] ❌ Timed out waiting for controller READY at index $index',
          );

          // Fallback: Try playing anyway if controller exists, sometimes isReady is flaky?
          if (controller != null) {
            debugPrint(
              '[YTFeed] ⚠️ Force playing non-ready controller at index $index',
            );
            // Pass attempt=1 to bypass the "wait for ready" check in _playWithRetry
            _playWithRetry(index, 1);
          }
        }
      }
    });
    _pendingTimers.add(timer);
  }

  /// Plays the video at index with retry mechanism
  void _playWithRetry(int index, [int attempt = 0]) {
    if (_isDisposed || _currentIndex != index || _isLifecyclePaused) {
      debugPrint(
        '[YTFeed] 🛑 Play blocked: Disposed=$_isDisposed, IndexMatch=${_currentIndex == index}, LifecyclePaused=$_isLifecyclePaused',
      );
      return;
    }
    if (attempt >= 10) {
      debugPrint('[YTFeed] ⚠️ Failed to play index $index after 10 attempts');
      return;
    }

    final controller = _controllers[index];

    if (controller != null) {
      // If not ready yet, wait and retry
      if (!controller.value.isReady && attempt == 0) {
        // FIX Bug #5: Add exponential backoff
        Future.delayed(
          Duration(milliseconds: 200 + (attempt * 100)),
          () => _playWithRetry(index, attempt + 1),
        );
        return;
      }

      debugPrint('[YTFeed] ▶️ Playing index $index (attempt $attempt)');

      // Safety: Pause any other controllers
      for (var entry in _controllers.entries) {
        if (entry.key != index) {
          entry.value.pause();
        }
      }

      // Mute/Unmute
      if (_isMuted) {
        controller.mute();
      } else {
        controller.unMute();
      }

      controller.play();

      // Verify success after a small delay to allow engine to react
      Future.delayed(Duration(milliseconds: 400 + (attempt * 100)), () {
        if (_isDisposed || _currentIndex != index) return;

        final currentController = _controllers[index];
        if (currentController != null) {
          final state = currentController.value.playerState;

          // Successful states
          final isWorking =
              state == PlayerState.playing || state == PlayerState.buffering;

          if (!isWorking) {
            // If it's still cued or unknown, it hasn't actually started yet.
            // We should retry playing.
            debugPrint(
              '[YTFeed] ⚠️ Video at $index state: $state (not playing yet), retrying... (attempt $attempt)',
            );
            // Re-call play just in case the first one was ignored
            currentController.play();
            _playWithRetry(index, attempt + 1);
          } else {
            debugPrint('[YTFeed] 🚀 Success: Video at $index is $state');

            // NEW: Auto-unmute when it starts playing
            if (_isMuted && !_isLifecyclePaused) {
              debugPrint('[YTFeed] 🔊 Auto-unmuting since playback started');
              _isMuted = false;
              currentController.unMute();
              notifyListeners();
            }
          }
        }
      });
    } else {
      // FIX Bug #5: Add exponential backoff for missing controller
      final delay = Duration(milliseconds: 200 + (attempt * 150));
      debugPrint(
        '[YTFeed] ⏳ Controller missing for $index, retrying in ${delay.inMilliseconds}ms...',
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

    // Define the preload window
    // We keep prev, current, and multiple nexts to ensure smooth scroll transitions
    // while strictly controlling which one plays audio.
    final windowIndices = <int>{};

    // Always include current
    windowIndices.add(centerIndex);

    // Preload next videos
    for (int i = 1; i <= _preloadNextCount; i++) {
      windowIndices.add(centerIndex + i);
    }

    // Preload previous videos
    for (int i = 1; i <= _preloadPrevCount; i++) {
      windowIndices.add(centerIndex - i);
    }

    // Filter valid indices
    final validWindow = windowIndices
        .where((i) => i >= 0 && i < videos.length)
        .toSet();

    // 1. DISPOSE controllers outside the window
    final toDispose = _controllers.keys
        .where((key) => !validWindow.contains(key))
        .toList();

    for (final index in toDispose) {
      debugPrint('[YTFeed] 🗑️ Disposing controller at index $index');
      _disposeController(index);
    }

    // 2. CREATE missing controllers in window
    for (final index in validWindow) {
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
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: true, // Start muted for pre-loading smoothness
          loop: true,
          disableDragSeek: true,
          enableCaption: false,
          hideControls: true,
          hideThumbnail: true,
          forceHD: false,
          useHybridComposition: false,
          controlsVisibleAtStart: false,
        ),
      );

      // Add listener for error detection
      controller.addListener(() {
        if (_isDisposed) return;
        _handleControllerUpdate(index, controller);
      });

      _controllers[index] = controller;
      _controllerVideoIds[index] = videoId;
      _initializing.remove(index);

      // Apply current mute state immediately to new controller
      if (!_isMuted) {
        controller.unMute();
      }

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

  // ==========================================================================
  // ENGAGEMENT SCANNING
  // ==========================================================================

  void _recordEngagement(int index) {
    if (index < 0 || index >= videos.length) return;
    if (_videoStartTime == null) return;

    final video = videos[index];
    final duration = DateTime.now().difference(_videoStartTime!).inMilliseconds;

    debugPrint('[YTFeed] 📊 Engagement for ${video.videoId}: ${duration}ms');

    // 1. Mark as SEEN for deduplication (critical for not showing again)
    SeenRepository.instance.markSeen(video.videoId, viewDurationMs: duration);
    debugPrint('[YTFeed] ✅ Marked as seen: ${video.videoId}');

    // 3. Update Session Bias
    if (video.relatedItemId != null) {
      // In a real app, we'd look up the genre of the item.
      // For now, we'll just log it.
      debugPrint('[YTFeed] 🧠 User watched genre signal from ${video.title}');
    }

    _videoStartTime = null;
  }

  /// Dispose a single controller
  void _disposeController(int index) {
    final controller = _controllers.remove(index);
    _controllerVideoIds.remove(index);
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
    if (_isLifecyclePaused) {
      debugPrint('[YTFeed] 🛑 Valid play command blocked by lifecycle pause');
      return;
    }
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
    _isLifecyclePaused = true;
    for (final controller in _controllers.values) {
      controller.pause();
    }
  }

  /// Resume current video (for app lifecycle)
  void resumeCurrent() {
    _isLifecyclePaused = false;
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

    // Check feed limit (200 items per tab)
    if (videos.length >= 200) {
      debugPrint('[YTFeed] ⚠️ Reached tab limit (${videos.length} items).');
      return;
    }

    // Cursor check
    if (_cursorsByType[_activeFeedType] == null) {
      if (!_hasMoreByType[_activeFeedType]!) {
        debugPrint('[YTFeed] 🏁 No more content for $_activeFeedType');
      }
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      await _fetchTabFeed(_activeFeedType, limit: 10);
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error loading more: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  /// Force refresh - clear everything and reload
  Future<void> refresh() async {
    // 1. Dispose all controllers
    _disposeAllControllers();
    _initializing.clear();

    _currentIndex = 0;
    _hasError = false;
    _errorMessage = null;

    // 2. Reset list and cursor for current tab
    _feedsByType[_activeFeedType] = [];
    _cursorsByType[_activeFeedType] = null;
    _pageCountsByType[_activeFeedType] = 1;
    _hasMoreByType[_activeFeedType] = true;

    // 3. Re-initialize
    _isLoading = true;
    notifyListeners();

    try {
      await _fetchTabFeed(_activeFeedType, limit: 100);
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
  // FEED MANIPULATION (Remote Trigger)
  // ==========================================================================

  void injectAndPlayVideo({
    required String videoId,
    String? title,
    String? thumbnail,
    String? channel,
  }) {
    if (_isDisposed) return;

    final feedList = _feedsByType[_activeFeedType]!;
    final index = feedList.indexWhere((v) => v.videoId == videoId);

    if (index != -1) {
      debugPrint(
        '[YTFeed] 📌 Video already in list at index $index, jumping...',
      );
      _jumpToPageController.add(index);
    } else {
      debugPrint('[YTFeed] 📥 Injecting new shared video: $videoId');

      final newVideo = FeedVideo(
        videoId: videoId,
        title: title ?? 'Shared Video',
        thumbnailUrl: thumbnail ?? '',
        channelName: channel ?? '',
        description: 'Shared from chat',
      );

      // Insert it right after the current index so it's the next video
      final insertIndex = (_currentIndex + 1).clamp(0, feedList.length);
      feedList.insert(insertIndex, newVideo);

      // Wait for list update then jump
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_isDisposed) {
          _jumpToPageController.add(insertIndex);
        }
      });
    }
    notifyListeners();
  }

  // ==========================================================================
  // CONVERSION HELPERS
  // ==========================================================================

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

  @override
  void dispose() {
    debugPrint('[YTFeed] 🧹 Disposing YoutubeFeedProvider');
    _isDisposed = true;

    // Cancel all pending timers to prevent memory leaks
    for (final timer in _pendingTimers) {
      timer.cancel();
    }
    _pendingTimers.clear();

    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initializing.clear();
    _jumpToPageController.close();

    // Do NOT dispose SeenRepository as it is a singleton for the app lifecycle.
    super.dispose();
  }
}
