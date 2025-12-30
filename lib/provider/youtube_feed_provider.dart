import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/feed_video.dart';
import '../services/api_client.dart';

import '../services/content_lake_repository.dart';
import '../db/objectbox/feed_entities.dart';

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

  DateTime? _videoStartTime;
  String? _lastFirstVideoId; // To prevent repeat first videos

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

  // Offline-First Repository
  final ContentLakeRepository _feedRepository = ContentLakeRepository();
  StreamSubscription<List<CachedFeedItem>>? _feedSubscription;

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

  /// Initialize provider - binds to ObjectBox stream
  Future<void> initialize() async {
    if (_isLoading) return;

    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      _feedRepository.initialize();

      // Bind callbacks
      _feedRepository.onSyncing = (syncing) {
        _isLoadingMore = syncing;
        notifyListeners();
      };

      _feedRepository.onError = (err) {
        _errorMessage = err;
        // Don't show full screen error if we have data
        if (videos.isEmpty) {
          _hasError = true;
          notifyListeners();
        }
      };

      // Start syncing the active feed type (background)
      await _feedRepository.startSync(_activeFeedType.value);

      // Subscribe to reactive updates from ObjectBox
      _subscribeToFeed(_activeFeedType.value);
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error initializing: $e');
      _hasError = true;
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _subscribeToFeed(String feedType) {
    _feedSubscription?.cancel();
    _feedSubscription = _feedRepository
        .watchFeed(feedType)
        .listen(
          (items) async {
            debugPrint(
              '[YTFeed] 📦 ObjectBox update: ${items.length} items for $feedType',
            );

            if (items.isEmpty) {
              // If empty, force a sync attempt
              await _feedRepository.startSync(feedType);
              return;
            }

            // VERIFICATION LOG
            print('''
              [YTFeed] 📥 RECEIVED DATA FROM LOCAL DB
              ------------------------------------------
              Source:    ObjectBox (Offline-Ready)
              Feed:      $feedType
              Items:     ${items.length}
              Status:    streaming...
              ------------------------------------------
              ''');

            await _onFeedChanged(
              items,
              FeedType.values.firstWhere((e) => e.value == feedType),
            );
          },
          onError: (e) {
            debugPrint('[YTFeed] ❌ ObjectBox stream error: $e');
            _hasError = true;
            _errorMessage = e.toString();
            notifyListeners();
          },
        );
  }

  Future<void> _onFeedChanged(
    List<CachedFeedItem> cachedItems,
    FeedType type,
  ) async {
    // Convert to UI models
    final videos = cachedItems.map(_cachedToFeedVideo).toList();

    // Personalization (For You only)
    List<FeedVideo> finalVideos = videos;

    if (type == FeedType.forYou && _currentIndex == 0) {
      finalVideos = _applyStartVideoGuarantee(videos);
    }

    _feedsByType[type] = finalVideos;

    // If valid content, update UI
    if (finalVideos.isNotEmpty) {
      // Ensure the window includes the current index (e.g. 0)
      if (!_controllers.containsKey(_currentIndex)) {
        _updateControllerWindow(_currentIndex);

        // CRITICAL FIX: Add a robust check loop to play once the controller is truly ready.
        // The simple Future.delayed(500ms) was insufficient for slower devices/network.
        _waitForControllerAndPlay(_currentIndex);
      } else {
        // If controller exists but might be paused (e.g. returning from background),
        // ensure it's playing if it's the active index.
        final controller = _controllers[_currentIndex];
        if (controller != null && !controller.value.isPlaying) {
          _playWithRetry(_currentIndex);
        }
      }
    }

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

    // 4. Start Sync & Subscribe
    await _feedRepository.startSync(type.value);
    _subscribeToFeed(type.value);

    // 5. Initial render from cache (fast)
    final initialItems = _feedRepository.getVisibleFeed(type.value);
    if (initialItems.isNotEmpty) {
      await _onFeedChanged(initialItems, type);
      _updateControllerWindow(0);
    } else {
      _isLoading = true; // Show loader while waiting for stream
    }

    notifyListeners();
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
  /// Checks every 100ms up to 50 times (5 seconds total).
  void _waitForControllerAndPlay(int index) {
    if (_isDisposed) return;

    int checks = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      final controller = _controllers[index];
      // CRITICAL: Check both existence AND readiness
      if (controller != null && controller.value.isReady) {
        timer.cancel();
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
  }

  /// Plays the video at index with retry mechanism
  void _playWithRetry(int index, [int attempt = 0]) {
    if (_isDisposed || _currentIndex != index) return;
    if (attempt >= 10) {
      debugPrint('[YTFeed] ⚠️ Failed to play index $index after 10 attempts');
      return;
    }

    final controller = _controllers[index];

    if (controller != null) {
      // If not ready yet, just wait (handled by _waitForControllerAndPlay usually, but double check)
      if (!controller.value.isReady && attempt == 0) {
        // Should have been handled by waiter, but let's delay
        Future.delayed(
          const Duration(milliseconds: 200),
          // Increment attempt to prevent infinite loop
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

      // Verify success
      Future.delayed(Duration(milliseconds: 300 + (attempt * 200)), () {
        if (_isDisposed || _currentIndex != index) return;

        final currentController = _controllers[index];
        if (currentController != null) {
          final state = currentController.value.playerState;
          // CRITICAL FIX: Consider BUFFERING as success (or at least "working on it")
          // Also checking "cued" as potential starting state that needs another kick?
          // Ideally: playing or buffering means we are good.
          final isWorking =
              state == PlayerState.playing || state == PlayerState.buffering;

          if (!isWorking) {
            debugPrint(
              '[YTFeed] ⚠️ Video at $index state: $state (not playing/buffering), retrying...',
            );
            _playWithRetry(index, attempt + 1);
          } else {
            debugPrint('[YTFeed] 🚀 Success: Video at $index is $state');
          }
        }
      });
    } else {
      // Controller missing
      final delay = Duration(milliseconds: 200);
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

    // Define the 3-controller window
    // We keep prev, current, and next to ensure smooth scroll transitions
    // while strictly controlling which one plays audio.
    final windowIndices = <int>{
      centerIndex - 1,
      centerIndex,
      centerIndex + 1,
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

  // ==========================================================================
  // ENGAGEMENT SCANNING
  // ==========================================================================

  void _recordEngagement(int index) {
    if (index < 0 || index >= videos.length) return;
    if (_videoStartTime == null) return;

    final video = videos[index];
    final duration = DateTime.now().difference(_videoStartTime!).inMilliseconds;

    debugPrint('[YTFeed] 📊 Engagement for ${video.videoId}: ${duration}ms');

    // 1. Record in Repository (Offline Cache)
    _feedRepository.recordEngagement(
      itemId: video.videoId,
      viewDurationMs: duration,
    );

    // 2. Update Session Bias
    if (video.relatedItemId != null) {
      // In a real app, we'd look up the genre of the item.
      // For now, we'll just log it.
      debugPrint('[YTFeed] 🧠 User watched genre signal from ${video.title}');
    }

    _videoStartTime = null;
  }

  List<FeedVideo> _applyStartVideoGuarantee(List<FeedVideo> pool) {
    if (pool.isEmpty) return pool;

    // Rule: Must not be the same first video as last session or today
    final candidates = pool
        .where((v) => v.videoId != _lastFirstVideoId)
        .toList();

    if (candidates.isEmpty) return pool;

    // Move the chosen one to the front
    final best = candidates.first;
    _lastFirstVideoId = best.videoId;

    final newList = List<FeedVideo>.from(pool);
    newList.removeWhere((v) => v.videoId == best.videoId);
    newList.insert(0, best);

    debugPrint('[YTFeed] ✨ Start Video Guarantee Applied: ${best.title}');
    return newList;
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
    // Current architecture uses fixed batches (50-100 items).
    // Infinite scroll acts as "Wait for next batch or just stop".
    // For now, no-op.
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  /// Force refresh - clear everything and reload
  Future<void> refresh() async {
    // Dispose all controllers
    _disposeAllControllers();
    _initializing.clear();

    _currentIndex = 0;
    _hasError = false;
    _errorMessage = null;

    // Force sync via repository
    await _feedRepository.forceRefresh(_activeFeedType.value);
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

  FeedVideo _cachedToFeedVideo(CachedFeedItem item) {
    return FeedVideo(
      videoId: item.youtubeKey ?? '',
      title: item.title,
      thumbnailUrl:
          item.backdrop ??
          (item.poster != null
              ? 'https://image.tmdb.org/t/p/w780${item.poster}'
              : ''),
      channelName: '', // Cached version often lacks channel, acceptable
      description: item.overview ?? '',
      recommendationReason: item.title,
      relatedItemId: item.tmdbId?.toString(),
      relatedItemType: item.mediaType,
      feedType: item.feedType,
      // Convert comma-separated string back to list if needed
    );
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
    _jumpToPageController.close();
    _feedSubscription?.cancel();
    _feedRepository.dispose();

    super.dispose();
  }
}
