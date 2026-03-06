import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/creator_video.dart';
import '../services/creator_url_cache.dart';
import '../services/video_interaction_tracker.dart';
import '../data/supabase_feed_datasource.dart';

/// Provider for the Creators Tab (TikTok-style Vertical Feed).
///
/// KEY FEATURES:
/// - Cursor-based pagination via [SupabaseFeedDataSource.getRankedFeed]
/// - Integrated URL pre-resolution via [CreatorUrlCache]
/// - Debounce guard on fetchMore to prevent overlapping queries
/// - Atomic view/like/share tracking via [SupabaseFeedDataSource]
/// - Watch-time/completion/skip tracking via [VideoInteractionTracker]
/// - Realtime subscription for live stats on current video
class CreatorsFeedProvider extends ChangeNotifier {
  final List<CreatorVideo> _videos = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  // Since the DB uses feed_sessions to dedup seen videos,
  // we do not need strict cursor state for pagination anymore.

  // Debounce timer for fetchMore
  Timer? _fetchMoreDebounce;

  // Data source for Supabase operations
  final SupabaseFeedDataSource _dataSource = SupabaseFeedDataSource();

  // Interaction tracker — watch_time, completion, skip detection
  final VideoInteractionTracker _tracker = VideoInteractionTracker();

  // Realtime subscription for current video's live stats
  RealtimeChannel? _statsChannel;
  int _currentViewIndex = -1;

  // Local like state (video ID → liked)
  final Map<String, bool> _likedVideos = {};

  List<CreatorVideo> get videos => _videos;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  static const int _pageSize = 15;

  Future<void> initialize() async {
    if (_videos.isNotEmpty || _isLoading) return;
    // Initialize feed session for seen-video dedup
    await _dataSource.initSession();
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    _hasMore = true;
    notifyListeners();

    // Stop any active interaction tracking
    _tracker.stopTracking();

    try {
      final data = await _dataSource.getRankedFeed(
        limit: _pageSize,
        coldStart: false,
      );
      _videos.clear();
      _videos.addAll(data);
      _updateCursor();
      if (data.length < _pageSize) _hasMore = false;

      // Log impressions
      if (data.isNotEmpty) {
        final impressions = data.asMap().entries.map((entry) {
          return {
            'video_id': entry.value.id,
            'position': entry.key,
            'feed_source': entry.value.feedSource ?? 'explore',
          };
        }).toList();
        _dataSource.batchInsertImpressions(impressions);
      }

      // Prefetch URLs first
      _prefetchUrls(0, 3);

      // Fetch like states for these videos
      if (data.isNotEmpty) {
        final videoIds = data.map((v) => v.id).toList();
        final likeStates = await _dataSource.fetchUserLikeStates(videoIds);
        _likedVideos.clear();
        _likedVideos.addAll(likeStates);
      }

      // Reset realtime subscription (old video IDs are stale after refresh)
      _currentViewIndex = -1;
      if (_statsChannel != null) {
        _dataSource.unsubscribe(_statsChannel!);
        _statsChannel = null;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[CreatorsFeed] Error fetching: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Debounced fetchMore — safe to call from scroll listener.
  void fetchMoreDebounced() {
    _fetchMoreDebounce?.cancel();
    _fetchMoreDebounce = Timer(const Duration(milliseconds: 300), fetchMore);
  }

  Future<void> fetchMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final data = await _dataSource.getRankedFeed(
        limit: _pageSize,
        coldStart: false,
      );

      if (data.isEmpty) {
        _hasMore = false;
      } else {
        _videos.addAll(data);
        _updateCursor();
        if (data.length < _pageSize) _hasMore = false;

        // Log impressions
        final startIndex = _videos.length - data.length;
        final impressions = data.asMap().entries.map((entry) {
          return {
            'video_id': entry.value.id,
            'position': startIndex + entry.key,
            'feed_source': entry.value.feedSource ?? 'explore',
          };
        }).toList();
        _dataSource.batchInsertImpressions(impressions);

        // Pre-resolve URLs for incoming videos.
        _prefetchUrls(_videos.length - data.length, _videos.length);

        // Fetch like states for incoming videos
        final videoIds = data.map((v) => v.id).toList();
        final likeStates = await _dataSource.fetchUserLikeStates(videoIds);
        _likedVideos.addAll(likeStates);
      }
    } catch (e) {
      debugPrint('[CreatorsFeed] Error fetching more: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ─── Engagement Tracking ────────────────────────────────────────────────

  /// Record a view for the video at [index]. Called on page change.
  ///
  /// Also starts interaction tracking (watch-time, completion, skip)
  /// and stops tracking the previous video.
  void recordView(int index) {
    if (index < 0 || index >= _videos.length) return;
    final video = _videos[index];

    // Stop tracking the previous video (flushes watch data)
    _tracker.stopTracking();

    // Start tracking the new video
    _tracker.startTracking(video.id, video.durationMs);

    // Increment view count
    _dataSource.recordView(video.id);

    // Update Realtime subscription to new video
    _subscribeToLiveStats(index);
  }

  /// Toggle like for the video at [index]. Optimistic update + atomic RPC.
  void toggleLike(int index) {
    if (index < 0 || index >= _videos.length) return;
    final video = _videos[index];

    // Track local like state so we toggle correctly
    final wasLiked = _likedVideos[video.id] ?? false;
    final isNowLiked = !wasLiked;
    _likedVideos[video.id] = isNowLiked;

    _dataSource.toggleLike(video.id, isNowLiked);
    notifyListeners();
  }

  /// Check if a video is liked locally.
  bool isLiked(String videoId) => _likedVideos[videoId] ?? false;

  /// Record a share for the video at [index]. Atomic increment.
  void recordShare(int index) {
    if (index < 0 || index >= _videos.length) return;
    _dataSource.recordShare(_videos[index].id);

    // Optimistic UI update
    final video = _videos[index];
    _videos[index] = video.copyWith(shareCount: video.shareCount + 1);
    notifyListeners();
  }

  /// Record a comment for the video at [index]. Updates interaction flag.
  void recordComment(int index) {
    if (index < 0 || index >= _videos.length) return;
    _dataSource.recordComment(_videos[index].id);

    // Local optimistic update for the comment count
    final video = _videos[index];
    _videos[index] = video.copyWith(commentCount: video.commentCount + 1);
    notifyListeners();
  }

  /// Pre-warms the URL cache for the given range of video indices.
  void prefetchUrlsForIndex(int currentIndex) {
    // Prefetch next 2 video URLs into the cache.
    _prefetchUrls(currentIndex + 1, currentIndex + 3);
  }

  Future<String> resolveVideoUrl(String pathOrUrl) =>
      CreatorUrlCache.instance.resolve(pathOrUrl);

  // ─── App Lifecycle ─────────────────────────────────────────────────────

  /// Pause interaction tracking (e.g. app backgrounded).
  void pauseTracking() => _tracker.pause();

  /// Resume interaction tracking (e.g. app returned to foreground).
  void resumeTracking() => _tracker.resume();

  // ─── Realtime ───────────────────────────────────────────────────────────

  void _subscribeToLiveStats(int index) {
    if (index == _currentViewIndex) return;
    _currentViewIndex = index;

    // Unsubscribe from previous video
    if (_statsChannel != null) {
      _dataSource.unsubscribe(_statsChannel!);
      _statsChannel = null;
    }

    if (index < 0 || index >= _videos.length) return;
    final video = _videos[index];

    _statsChannel = _dataSource.subscribeLiveStats(video.id, (newRecord) {
      // Update local video data with live stats
      if (index < _videos.length && _videos[index].id == video.id) {
        final currentVideo = _videos[index];
        _videos[index] = currentVideo.copyWith(
          likeCount: newRecord['like_count'] as int? ?? currentVideo.likeCount,
          viewCount: newRecord['view_count'] as int? ?? currentVideo.viewCount,
          commentCount:
              newRecord['comment_count'] as int? ?? currentVideo.commentCount,
          shareCount:
              newRecord['share_count'] as int? ?? currentVideo.shareCount,
          engagementScore:
              (newRecord['engagement_score'] as num?)?.toDouble() ??
              currentVideo.engagementScore,
        );
        notifyListeners();
      }
    });
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  void _updateCursor() {
    // State removed: _lastCreatedAt
    // We rely solely on the session dedup array now.
  }

  void _prefetchUrls(int start, int end) {
    final upper = end.clamp(0, _videos.length);
    for (int i = start.clamp(0, _videos.length); i < upper; i++) {
      CreatorUrlCache.instance.prefetch(_videos[i].videoUrl);
      if (_videos[i].thumbnailUrl.isNotEmpty) {
        CreatorUrlCache.instance.prefetch(
          _videos[i].thumbnailUrl,
          bucket: 'creator-thumbnails',
        );
      }
    }
  }

  @override
  void dispose() {
    _fetchMoreDebounce?.cancel();
    _tracker.stopTracking();
    if (_statsChannel != null) {
      _dataSource.unsubscribe(_statsChannel!);
    }
    super.dispose();
  }
}
