import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../models/feed_video.dart';
import '../models/feed_item.dart';
import '../services/api_client.dart';
import '../services/fast_video_pool_manager.dart';
import '../services/feed_cache_manager.dart';

/// Centralized state management for the Chewie-based video feed.
///
/// Handles:
/// - Video data loading and pagination
/// - FastVideoPoolManager lifecycle
/// - App lifecycle events
/// - Mute state
/// - Local caching for instant load
class ChewieFeedProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final FastVideoPoolManager _videoManager = FastVideoPoolManager();
  final FeedCacheManager _cacheManager = FeedCacheManager.instance;

  // --- State ---
  final List<FeedVideo> _videos = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  int _focusedIndex = 0;
  int _currentPage = 1;
  bool _isMuted = false;
  bool _isDisposed = false;

  // --- Getters ---
  List<FeedVideo> get videos => List.unmodifiable(_videos);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  int get focusedIndex => _focusedIndex;
  int get currentPage => _currentPage;
  bool get isMuted => _isMuted;
  FastVideoPoolManager get videoManager => _videoManager;

  /// Get controller for specific index
  VideoPlayerController? getController(int index) =>
      _videoManager.getController(index);

  // --- Initialization ---

  ChewieFeedProvider() {
    _videoManager.addListener(_onVideoManagerUpdate);
  }

  void _onVideoManagerUpdate() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Initialize and load feed with cache-first strategy
  /// 1. Load from cache for instant display
  /// 2. Refresh from network in background
  Future<void> initialize() async {
    await _loadFromCacheThenNetwork();
  }

  /// Cache-first loading strategy
  Future<void> _loadFromCacheThenNetwork() async {
    _isLoading = true;
    notifyListeners();

    // 1. Try to load from cache first (instant display)
    try {
      final cachedItems = await _cacheManager.getCachedFeed();

      if (cachedItems.isNotEmpty && !_isDisposed) {
        debugPrint('📦 Loaded ${cachedItems.length} items from cache');

        final cachedVideos = _processFeedItems(cachedItems);
        _videos.clear();
        _videos.addAll(cachedVideos);
        _isLoading = false;

        if (_videos.isNotEmpty) {
          _videoManager.initialize(_videos);
        }

        notifyListeners();

        // 2. Refresh from network in background (don't block UI)
        _refreshInBackground();
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Error loading from cache: $e');
    }

    // 3. No cache, load from network directly
    await _loadFromNetwork();
  }

  /// Refresh feed in background (doesn't block UI)
  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();

    debugPrint('🔄 Background refresh started...');

    try {
      final freshItems = await _fetchFeedFromNetwork();

      if (freshItems.isNotEmpty && !_isDisposed) {
        // Cache the fresh data
        await _cacheManager.cacheFeed(freshItems);

        final freshVideos = _processFeedItems(freshItems);
        _videos.clear();
        _videos.addAll(freshVideos);

        if (_videos.isNotEmpty) {
          _videoManager.initialize(_videos);
        
        }

        debugPrint(
          '✅ Background refresh complete, cached ${freshItems.length} items',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Background refresh failed: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  // --- Data Conversion ---

  FeedVideo _convertToFeedVideo(FeedItem item) {
    String videoId = item.youtubeKey ?? '';
    String thumbnailUrl =
        item.fullBackdropUrl ??
        item.fullPosterUrl ??
        (videoId.isNotEmpty
            ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg'
            : '');

    return FeedVideo(
      videoId: videoId,
      title: item.title,
      thumbnailUrl: thumbnailUrl,
      channelName: item.mediaType?.toUpperCase() ?? 'MOVIE',
      description: item.overview ?? '',
      recommendationReason: item.reason,
      relatedItemId: item.tmdbId?.toString(),
      relatedItemType: item.type,
    );
  }

  List<FeedItem> _prioritizeTrailers(List<FeedItem> items) {
    final trailers = items
        .where((i) => i.type == 'trailer' || i.type == 'teaser')
        .toList();
    final others = items
        .where((i) => i.type != 'trailer' && i.type != 'teaser')
        .toList();

    trailers.shuffle();
    others.shuffle();

    return [...others, ...trailers];
  }

  List<FeedVideo> _processFeedItems(List<FeedItem> items) {
    final itemsWithVideos = items
        .where((item) => item.hasYouTubeVideo)
        .toList();

    final sortedItems = _prioritizeTrailers(itemsWithVideos);
    return sortedItems.map(_convertToFeedVideo).toList();
  }

  // --- Network Operations ---

  Future<List<FeedItem>> _fetchFeedFromNetwork({int page = 4}) async {
    var feedItems = await _apiClient.getPersonalizedFeedV2(
      refresh: false,
      limit: 70,
      page: page,
    );

    if (feedItems.isEmpty && page == 1) {
      debugPrint('⚠️ Personalized feed empty, trying global feed...');
      feedItems = await _apiClient.getGlobalFeed(limit: 50);
    }

    return feedItems;
  }

  Future<void> _loadFromNetwork() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('📡 Loading from network...');
      final feedItems = await _fetchFeedFromNetwork();
      debugPrint('✅ Got ${feedItems.length} items from network');

      final newVideos = _processFeedItems(feedItems);

      if (!_isDisposed) {
        // Cache the fresh data for next app start
        await _cacheManager.cacheFeed(feedItems);

        _videos.clear();
        _videos.addAll(newVideos);
        _isLoading = false;

        if (_videos.isNotEmpty) {
          _videoManager.initialize(_videos);
        }

        // Log stats
        final trailerCount = feedItems
            .where((i) => i.type == 'trailer' || i.type == 'teaser')
            .length;
        final btsCount = feedItems
            .where((i) => i.type == 'bts' || i.type == 'interview')
            .length;
        debugPrint('📊 Trailers: $trailerCount | BTS/Interviews: $btsCount');

        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("❌ Error loading from network: $e");
    }
  }

  /// Pull to refresh
  Future<void> refresh() async {
    debugPrint('🔄 Pull to refresh...');
    _currentPage = 1;
    notifyListeners();
    await _loadFromNetwork();
  }

  /// Load more feed items (Infinite Scroll)
  Future<void> loadMore() async {
    if (_isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      debugPrint('📡 Loading page $nextPage from network...');

      final newItems = await _fetchFeedFromNetwork(page: nextPage);

      if (newItems.isNotEmpty && !_isDisposed) {
        debugPrint('✅ Got ${newItems.length} new items for page $nextPage');

        final newVideos = _processFeedItems(newItems);
        final existingIds = _videos.map((v) => v.videoId).toSet();
        final uniqueVideos = newVideos
            .where((v) => !existingIds.contains(v.videoId))
            .toList();

        if (uniqueVideos.isNotEmpty) {
          _videos.addAll(uniqueVideos);
          _currentPage = nextPage;
        } else {
          debugPrint('⚠️ All items were duplicates');
          _currentPage = nextPage;
        }
        _isLoadingMore = false;
        notifyListeners();
      } else {
        debugPrint('⚠️ No more items available.');
        _isLoadingMore = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading more items: $e');
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Trigger backend refresh
  Future<bool> triggerBackendRefresh() async {
    return await _apiClient.triggerBackendRefresh();
  }

  // --- Page Change ---

  void onPageChanged(int index) {
    _focusedIndex = index;
    _videoManager.onPageChanged(index, _videos);
    notifyListeners();

    // Load more when near end
    if (index >= _videos.length - 3 && !_isLoadingMore) {
      debugPrint('📜 Reached index $index, loading more...');
      loadMore();
    }
  }

  // --- Playback Control ---

  void play(int index) {
    _videoManager.play(index);
  }

  void pause(int index) {
    _videoManager.pause(index);
  }

  void pauseAll() {
    _videoManager.pauseAll();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    final controller = _videoManager.getController(_focusedIndex);
    controller?.setVolume(_isMuted ? 0 : 1);
    notifyListeners();
  }

  // --- App Lifecycle ---

  void onAppPaused() {
    _videoManager.pauseAll();
  }

  void onAppResumed() {
    _videoManager.play(_focusedIndex);
  }

  // --- Cleanup ---

  @override
  void dispose() {
    debugPrint('[ChewieFeed] 🧹 Disposing provider');
    _isDisposed = true;
    _videoManager.removeListener(_onVideoManagerUpdate);
    _videoManager.dispose();
    super.dispose();
  }
}
