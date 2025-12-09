/// YouTube Iframe Feed Provider
///
/// Implements a 3-controller window strategy for memory management.
/// Uses muted autoplay to fix "Status 5" autoplay policy issues.
///
/// Key features:
/// - Only 3 active controllers at any time (previous, current, next)
/// - Muted autoplay for browser compatibility
/// - Aggressive cleanup of controllers outside the window

import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:finishd/models/feed_video.dart';
import 'package:finishd/models/feed_item.dart';
import 'package:finishd/services/api_client.dart';
import 'package:finishd/services/cache/feed_cache_service.dart';

class IframeFeedProvider extends ChangeNotifier {
  // --- State ---
  final List<FeedVideo> _videos = [];
  final Map<int, YoutubePlayerController> _controllers = {};

  int _currentIndex = 0;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isMuted = true; // Start muted for autoplay policy
  bool _hasError = false;
  String? _errorMessage;

  // --- API ---
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

  /// Get controller for a specific index (if within window)
  YoutubePlayerController? getController(int index) => _controllers[index];

  /// Check if controller exists for index
  bool hasController(int index) => _controllers.containsKey(index);

  // --- Initialization ---

  Future<void> initialize() async {
    if (_isLoading) return;

    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      // Try cache first
      final cached = await FeedCacheService.getFeed();
      if (cached != null && cached.isNotEmpty) {
        _videos.addAll(_convertToFeedVideos(cached));
        _isLoading = false;
        notifyListeners();

        // Initialize controllers for first 3
        _updateControllerWindow(0);

        // Background refresh
        _refreshInBackground();
        return;
      }

      // Load from network
      await _loadFromNetwork();
    } catch (e) {
      debugPrint('❌ Error initializing feed: $e');
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

      // Initialize first 3 controllers
      if (_videos.isNotEmpty) {
        _updateControllerWindow(0);
      }

      debugPrint('✅ Loaded ${_videos.length} videos from network');
    } catch (e) {
      debugPrint('❌ Network error: $e');
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
        debugPrint('✅ Background refresh complete');
      }
    } catch (e) {
      debugPrint('⚠️ Background refresh failed: $e');
    }
  }

  // --- Page Change Handler ---

  void onPageChanged(int newIndex) {
    if (newIndex == _currentIndex) return;

    final oldIndex = _currentIndex;
    _currentIndex = newIndex;

    debugPrint('📄 Page changed: $oldIndex → $newIndex');

    // Pause old video
    _controllers[oldIndex]?.pauseVideo();

    // Update controller window
    _updateControllerWindow(newIndex);

    // Play new video (muted for autoplay policy)
    Future.delayed(const Duration(milliseconds: 100), () {
      _controllers[newIndex]?.playVideo();
    });

    // Load more if near end
    if (newIndex >= _videos.length - 5) {
      loadMore();
    }

    notifyListeners();
  }

  // --- Controller Window Management (THE KEY STRATEGY) ---

  /// Only keep 3 controllers: previous, current, next
  void _updateControllerWindow(int centerIndex) {
    final keepIndices = <int>{};

    // Window: [centerIndex - 1, centerIndex, centerIndex + 1]
    for (int i = centerIndex - 1; i <= centerIndex + 1; i++) {
      if (i >= 0 && i < _videos.length) {
        keepIndices.add(i);
      }
    }

    // Remove controllers outside window
    final toRemove = _controllers.keys
        .where((i) => !keepIndices.contains(i))
        .toList();
    for (final index in toRemove) {
      debugPrint('🗑️ Disposing controller at index $index');
      _controllers[index]?.close();
      _controllers.remove(index);
    }

    // Create controllers for indices in window
    for (final index in keepIndices) {
      if (!_controllers.containsKey(index)) {
        _createController(index);
      }
    }

    debugPrint('🎮 Active controllers: ${_controllers.keys.toList()}');
  }

  /// Create a controller with muted autoplay params
  void _createController(int index) {
    if (index < 0 || index >= _videos.length) return;
    if (_controllers.containsKey(index)) return;

    final video = _videos[index];
    final videoId = video.videoId;

    if (videoId.isEmpty) {
      debugPrint('⚠️ Empty videoId at index $index');
      return;
    }

    debugPrint('🎬 Creating controller for index $index: $videoId');

    final controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: index == _currentIndex, // Only autoplay current
      params: const YoutubePlayerParams(
        mute: true, // CRITICAL: Muted for autoplay policy
        showControls: false,
        showFullscreenButton: false,
        loop: true,
        playsInline: true,
        enableCaption: false,
        showVideoAnnotations: false,
        strictRelatedVideos: true,
      ),
    );

    _controllers[index] = controller;
  }

  // --- Mute/Unmute ---

  void toggleMute() {
    _isMuted = !_isMuted;

    final controller = _controllers[_currentIndex];
    if (controller != null) {
      if (_isMuted) {
        controller.mute();
      } else {
        controller.unMute();
      }
    }

    notifyListeners();
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    final controller = _controllers[_currentIndex];
    if (controller != null) {
      if (_isMuted) {
        controller.mute();
      } else {
        controller.unMute();
      }
    }
    notifyListeners();
  }

  // --- Load More (Pagination) ---

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
        '✅ Loaded ${newVideos.length} more videos (page $_currentPage)',
      );
    } catch (e) {
      debugPrint('❌ Error loading more: $e');
      _currentPage--;
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // --- Force Refresh ---

  Future<void> refresh() async {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _videos.clear();
    _currentIndex = 0;
    _currentPage = 1;

    // Clear cache
    await FeedCacheService.clearFeed();

    // Reload
    await initialize();
  }

  // --- Conversion Helpers ---

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

  // --- Backend Trigger ---

  /// Trigger backend cron job to refresh content (Debug/Admin)
  Future<bool> triggerBackendRefresh() async {
    try {
      return await _apiClient.triggerBackendRefresh();
    } catch (e) {
      debugPrint('❌ Error triggering backend refresh: $e');
      return false;
    }
  }

  // --- Cleanup ---

  @override
  void dispose() {
    debugPrint('🧹 Disposing IframeFeedProvider');
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    super.dispose();
  }
}
