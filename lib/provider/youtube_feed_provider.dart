import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/services/video_cache_service.dart';
import '../models/feed_video.dart';
import '../models/feed_type.dart';

/// YouTube Feed Provider (Now supports Creator Uploads via Supabase)
///
/// Production-ready controller management for vertical video feed.
/// Handles both YouTube videos and Supabase Storage MP4s.
///
/// Key Features:
/// - 3-Controller Window Strategy (prev, current, next)
/// - Three-tab support (Trending, Following, For You)
/// - Muted autoplay for browser/OS policy compliance
/// - Memory-efficient disposal of out-of-window controllers
class YoutubeFeedProvider extends ChangeNotifier {
  // --- State ---
  final Map<int, YoutubePlayerController> _controllers = {};
  final Map<int, VideoPlayerController> _mp4Controllers = {}; // NEW: For MP4s
  final Map<int, bool> _mp4Initialized =
      {}; // Track initialization state used for UI

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
  static const int _controllerKeepAhead = 1; // Keep only current+next in memory
  static const int _controllerKeepBehind = 1; // Keep previous for smooth reverse swipe
  static const int _networkPreloadAhead = 2; // Preload at most two ahead on network cache

  // ============================================================================
  // FEED BACKEND
  // ============================================================================
  // Direct Supabase integration. No external API client.

  /// Track page counts for UI display (debug menu)
  final Map<FeedType, int> _pageCountsByType = {
    FeedType.trending: 1,
    FeedType.following: 1,
    FeedType.forYou: 1,
  };

  // --- Getters ---
  List<FeedVideo> get videos => _feedsByType[_activeFeedType] ?? [];
  int get currentIndex => _currentIndex;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isMuted => _isMuted;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  FeedType get activeFeedType => _activeFeedType;
  int get currentPage => _pageCountsByType[_activeFeedType] ?? 1;

  int get activeYoutubeControllerCount => _controllers.length;
  int get activeMp4ControllerCount => _mp4Controllers.length;
  int get totalActiveControllers => _controllers.length + _mp4Controllers.length;

  /// Get controller for specific index (null if not in window)
  YoutubePlayerController? getController(int index) => _controllers[index];
  VideoPlayerController? getMp4Controller(int index) => _mp4Controllers[index];
  bool isMp4Initialized(int index) => _mp4Initialized[index] ?? false;

  /// Check if ANY controller exists for index
  bool hasController(int index) =>
      _controllers.containsKey(index) || _mp4Controllers.containsKey(index);

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initialize provider - fetch feed from Supabase
  Future<void> initialize() async {
    if (_isLoading) return;

    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      debugPrint('[YTFeed] 🚀 Initializing with Supabase backend');
      await _fetchTabFeed(_activeFeedType, limit: 100);
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error initializing: $e');
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Internal: Fetch feed for a specific tab from Supabase
  Future<void> _fetchTabFeed(FeedType type, {int limit = 20}) async {
    try {
      debugPrint('[YTFeed] 📥 Fetching $type feed from Supabase...');

      // Build Query
      dynamic query = Supabase.instance.client
          .from('creator_videos')
          .select(
            '*, profiles!creator_videos_creator_id_fkey(username, avatar_url)',
          )
          .eq('status', 'approved')
          .filter('deleted_at', 'is', null);

      // Filtering/Ordering based on feed type
      if (type == FeedType.trending) {
        query = query.order('engagement_score', ascending: false);
      } else if (type == FeedType.following) {
        // Ideally filter by following, but for now just show all (or implement following logic)
        // Since 'following' logic requires joins, we might just show latest for now
        query = query.order('created_at', ascending: false);
      } else {
        // For You (default)
        // Using created_at for now, maybe random or Algo later
        query = query.order('created_at', ascending: false);
      }

      final response = await query.limit(limit);

      List<FeedVideo> newVideos = (response as List)
          .map((json) => FeedVideo.fromCreatorJson(json))
          .toList();

      debugPrint('[YTFeed] 📸 Got ${newVideos.length} videos from Supabase');

      // Update state
      if (_feedsByType[type]!.isEmpty) {
        _feedsByType[type] = newVideos;
      } else {
        _feedsByType[type]!.addAll(newVideos);
      }

      // If active tab and we have content, ensure playback
      if (type == _activeFeedType && _feedsByType[type]!.isNotEmpty) {
        if (!hasController(_currentIndex)) {
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

  // ==========================================================================
  // PUBLIC METHODS (UI Helpers)
  // ==========================================================================

  /// Refresh the current feed (re-fetch from start)
  Future<void> refresh() async {
    debugPrint('[YTFeed] 🔄 Refreshing current feed: ${_activeFeedType.value}');

    // 1. Pause & dispose everything
    _pauseController(_currentIndex);
    _disposeAllControllers();

    // 2. Clear current feed data
    _feedsByType[_activeFeedType] = [];
    _currentIndex = 0;
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    // 3. Re-fetch
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

  /// Inject a video from Chat/Link and play it immediately
  void injectAndPlayVideo({
    required String videoId,
    String? title,
    String? thumbnail,
    String? channel,
  }) {
    final video = FeedVideo(
      videoId: videoId,
      videoUrl: 'https://www.youtube.com/watch?v=$videoId',
      title: title ?? 'Shared Video',
      description: '',
      thumbnailUrl: thumbnail ?? '',
      channelName: channel ?? 'Unknown',
      isCreator: false,
    );

    // Insert at top of current feed
    List<FeedVideo>? currentList = _feedsByType[_activeFeedType];
    if (currentList == null) {
      currentList = [];
      _feedsByType[_activeFeedType] = currentList;
    }

    currentList.insert(0, video);

    // Reset to top and play
    _currentIndex = 0;
    _disposeAllControllers(); // Reset state
    _updateControllerWindow(0);
    _waitForControllerAndPlay(0);

    notifyListeners();
  }

  // Public load more method
  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();

    // TODO: Implement proper pagination
    // For now we just wait to simulate
    await Future.delayed(const Duration(milliseconds: 500));
    _isLoadingMore = false;
    notifyListeners();
  }

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

      bool ready = false;

      // Check MP4
      final mp4Ctrl = _mp4Controllers[index];
      if (mp4Ctrl != null && mp4Ctrl.value.isInitialized) {
        ready = true;
      }

      // Check YouTube
      final ytCtrl = _controllers[index];
      if (ytCtrl != null && ytCtrl.value.isReady) {
        ready = true;
      }

      if (ready) {
        timer.cancel();
        _pendingTimers.remove(timer);
        debugPrint(
          '[YTFeed] ✅ Controller ready for $index after ${checks * 100}ms, playing...',
        );
        _playWithRetry(index);
      } else {
        checks++;
        if (checks >= 30) {
          // 3 seconds timeout for MP4/Network
          timer.cancel();
          _pendingTimers.remove(timer);
          debugPrint(
            '[YTFeed] ❌ Timed out waiting for controller at index $index',
          );
          // Try playing anyway
          _playWithRetry(index, 1);
        }
      }
    });
    _pendingTimers.add(timer);
  }

  /// Plays the video at index with retry mechanism
  void _playWithRetry(int index, [int attempt = 0]) {
    if (_isDisposed || _currentIndex != index || _isLifecyclePaused) {
      return;
    }
    if (attempt >= 5) return;

    // Try MP4 first
    final mp4Ctrl = _mp4Controllers[index];
    if (mp4Ctrl != null) {
      if (!mp4Ctrl.value.isInitialized) {
        Future.delayed(
          const Duration(milliseconds: 200),
          () => _playWithRetry(index, attempt + 1),
        );
        return;
      }

      _silenceOthers(index);
      mp4Ctrl.setVolume(_isMuted ? 0 : 1);
      mp4Ctrl.play();
      mp4Ctrl.setLooping(true);
      return;
    }

    // Try YouTube
    final controller = _controllers[index];
    if (controller != null) {
      if (!controller.value.isReady && attempt == 0) {
        Future.delayed(
          Duration(milliseconds: 200 + (attempt * 100)),
          () => _playWithRetry(index, attempt + 1),
        );
        return;
      }

      _silenceOthers(index);
      if (_isMuted)
        controller.mute();
      else
        controller.unMute();
      controller.play();
      return;
    }

    // No controller found yet
    debugPrint('[YTFeed] ⏳ Controller missing for $index, retrying...');
    Future.delayed(
      const Duration(milliseconds: 200),
      () => _playWithRetry(index, attempt + 1),
    );
  }

  void _silenceOthers(int activeIndex) {
    for (var entry in _controllers.entries) {
      if (entry.key != activeIndex) entry.value.pause();
    }
    for (var entry in _mp4Controllers.entries) {
      if (entry.key != activeIndex) entry.value.pause();
    }
  }

  // ==========================================================================
  // 3-CONTROLLER WINDOW STRATEGY (Memory Management)
  // ==========================================================================

  void _updateControllerWindow(int centerIndex) {
    if (_isDisposed || videos.isEmpty) return;

    final windowIndices = <int>{};
    windowIndices.add(centerIndex);
    for (int i = 1; i <= _controllerKeepAhead; i++) {
      windowIndices.add(centerIndex + i);
    }
    for (int i = 1; i <= _controllerKeepBehind; i++) {
      windowIndices.add(centerIndex - i);
    }

    final validWindow = windowIndices
        .where((i) => i >= 0 && i < videos.length)
        .toSet();

    // 1. DISPOSE
    final toDisposeYt = _controllers.keys
        .where((key) => !validWindow.contains(key))
        .toList();
    for (final index in toDisposeYt) _disposeController(index);

    final toDisposeMp4 = _mp4Controllers.keys
        .where((key) => !validWindow.contains(key))
        .toList();
    for (final index in toDisposeMp4) _disposeController(index);

    // 2. CREATE
    for (final index in validWindow) {
      if (!hasController(index) && !_initializing.contains(index)) {
        _createController(index);
      }
    }

    // 3. PRELOAD NEXT
    _preloadNextVideos(centerIndex);
  }

  void _preloadNextVideos(int currentIndex) {
    // Keep controller memory tight (prev/current/next), but still warm network cache.
    // Preload ahead from index + 1 and index + 2 only.
    final start = currentIndex + 1;
    final end = start + _networkPreloadAhead;

    for (int i = start; i < end && i < videos.length; i++) {
      final video = videos[i];
      if (video.videoUrl != null && !video.videoUrl!.contains('youtube.com')) {
        String url = video.videoUrl!;
        if (url.isNotEmpty && !url.startsWith('http')) {
          // Must resolve signed URL first — fire-and-forget
          Supabase.instance.client.storage
              .from('creator-videos')
              .createSignedUrl(url, 60 * 60)
              .then((signedUrl) {
                VideoCacheService().preload(signedUrl);
              })
              .catchError((e) {
                debugPrint('[YTFeed] ❌ Preload sign failed for index $i: $e');
              });
        } else if (url.startsWith('http')) {
          VideoCacheService().preload(url);
        }
      }
    }
  }

  // ==========================================================================
  // CONTROLLER LIFECYCLE
  // ==========================================================================

  void _createController(int index) async {
    if (index < 0 || index >= videos.length) return;
    if (hasController(index)) return;
    if (_isDisposed) return;

    // Use a lock to prevent duplicate creations for same index
    if (_initializing.contains(index)) return;
    _initializing.add(index);

    final video = videos[index];

    try {
      // 1. MP4 / Creator Video / Supabase Storage
      if (video.isCreator ||
          (video.videoUrl != null &&
              !video.videoUrl!.contains('youtube.com'))) {
        String url = video.videoUrl ?? '';

        // Resolve Signed URL if needed
        if (url.isNotEmpty && !url.startsWith('http')) {
          try {
            url = await Supabase.instance.client.storage
                .from('creator-videos')
                .createSignedUrl(url, 60 * 60);
          } catch (e) {
            debugPrint('[YTFeed] Failed to sign URL: $e');
          }
        }

        if (url.isEmpty) throw Exception("Empty Video URL");

        // ---------------------------------------------------------------------
        // CACHING LOGIC — Non-blocking
        // Check cache instantly. If hit → play from file (fast).
        // If miss → stream from network NOW, cache in background.
        // ---------------------------------------------------------------------
        VideoPlayerController? controller;
        final cachedFile = await VideoCacheService().getCachedFileOnly(url);

        if (cachedFile != null) {
          debugPrint('[YTFeed] ⚡️ Playing from CACHE: $index');
          controller = VideoPlayerController.file(cachedFile);
        } else {
          debugPrint('[YTFeed] 📡 Streaming NETWORK: $index');
          controller = VideoPlayerController.networkUrl(Uri.parse(url));
          // Cache in background (fire-and-forget)
          VideoCacheService().preload(url);
        }

        await controller.initialize();

        if (_isDisposed) {
          controller.dispose();
          return;
        }

        _mp4Controllers[index] = controller;
        _mp4Initialized[index] = true;

        // Start muted
        controller.setVolume(0);
        controller.setLooping(true);
      } else {
        // 2. YouTube Video
        if (video.videoId.isEmpty) throw Exception("Empty YouTube ID");

        final controller = YoutubePlayerController(
          initialVideoId: video.videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: true,
            loop: true,
            disableDragSeek: true,
            enableCaption: false,
            hideControls: true,
            hideThumbnail: true,
          ),
        );

        controller.addListener(() {
          if (_isDisposed) return;
          _handleControllerUpdate(index, controller);
        });

        _controllers[index] = controller;
        _controllerVideoIds[index] = video.videoId;

        if (!_isMuted) controller.unMute();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[YTFeed] ❌ Error creating controller for index $index: $e');
    } finally {
      _initializing.remove(index);
    }
  }

  void _handleControllerUpdate(int index, YoutubePlayerController controller) {
    if (controller.value.errorCode != 0) {
      debugPrint(
        '[YTFeed] ❌ Player error at index $index: ${controller.value.errorCode}',
      );
    }
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

    // We can insert into `video_engagement_events` here using Supabase if we want
    // But for now just print logs as per "remove external API"
  }

  /// Dispose a single controller
  void _disposeController(int index) {
    // Dispose YouTube
    final ytController = _controllers.remove(index);
    _controllerVideoIds.remove(index);
    if (ytController != null) {
      ytController.pause();
      ytController.dispose();
    }

    // Dispose MP4
    final mp4Controller = _mp4Controllers.remove(index);
    _mp4Initialized.remove(index);
    if (mp4Controller != null) {
      mp4Controller.pause();
      mp4Controller.dispose();
    }

    _initializing.remove(index);
  }

  /// Dispose all controllers (used when switching tabs)
  void _disposeAllControllers() {
    debugPrint('[YTFeed] 🗑️ Disposing all controllers');
    for (final index in _controllers.keys.toList()) _disposeController(index);
    for (final index in _mp4Controllers.keys.toList())
      _disposeController(index);
  }

  // ==========================================================================
  // PLAYBACK CONTROL
  // ==========================================================================

  void _playController(int index) {
    if (_isLifecyclePaused) return;

    final yt = _controllers[index];
    if (yt != null) yt.play();

    final mp4 = _mp4Controllers[index];
    if (mp4 != null) mp4.play();
  }

  void _pauseController(int index) {
    final yt = _controllers[index];
    if (yt != null) yt.pause();

    final mp4 = _mp4Controllers[index];
    if (mp4 != null) mp4.pause();
  }

  /// Public: Play video at index
  void play(int index) => _playController(index);

  /// Public: Pause video at index
  void pause(int index) => _pauseController(index);

  /// Pause all videos (for app lifecycle)
  void pauseAll() {
    _isLifecyclePaused = true;
    for (final c in _controllers.values) c.pause();
    for (final c in _mp4Controllers.values) c.pause();
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
      if (_isMuted)
        controller.mute();
      else
        controller.unMute();
    }

    final mp4Controller = _mp4Controllers[_currentIndex];
    if (mp4Controller != null) {
      mp4Controller.setVolume(_isMuted ? 0 : 1);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeAllControllers();
    _pendingTimers.forEach((t) => t.cancel());
    _jumpToPageController.close();
    super.dispose();
  }
}
