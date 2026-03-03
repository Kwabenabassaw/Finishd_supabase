import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/creator_video.dart';
import '../services/creator_url_cache.dart';
import '../data/supabase_feed_datasource.dart';

/// Provider for the Creators Tab (TikTok-style Vertical Feed).
///
/// KEY FEATURES:
/// - Cursor-based pagination (engagement_score + created_at)
/// - Integrated URL pre-resolution via CreatorUrlCache
/// - Debounce guard on fetchMore to prevent overlapping queries
/// - Atomic view/like tracking via SupabaseFeedDataSource
/// - Realtime subscription for live stats on current video
class CreatorsFeedProvider extends ChangeNotifier {
  final List<CreatorVideo> _videos = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  // Cursor state — tracks last seen position for stable pagination.
  double? _lastEngagementScore;
  DateTime? _lastCreatedAt;

  // Debounce timer for fetchMore
  Timer? _fetchMoreDebounce;

  // Data source for Supabase operations
  final SupabaseFeedDataSource _dataSource = SupabaseFeedDataSource();

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
    _lastEngagementScore = null;
    _lastCreatedAt = null;
    notifyListeners();

    try {
      final data = await _fetchPage(isFirstPage: true);
      _videos.clear();
      _videos.addAll(data);
      _updateCursor();
      if (data.length < _pageSize) _hasMore = false;

      // Pre-resolve URLs for first 3 videos so controller manager has them fast.
      _prefetchUrls(0, 3);

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
      final data = await _fetchPage(isFirstPage: false);

      if (data.isEmpty) {
        _hasMore = false;
      } else {
        _videos.addAll(data);
        _updateCursor();
        if (data.length < _pageSize) _hasMore = false;

        // Pre-resolve URLs for incoming videos.
        _prefetchUrls(_videos.length - data.length, _videos.length);
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
  void recordView(int index) {
    if (index < 0 || index >= _videos.length) return;
    final video = _videos[index];
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

  /// Pre-warms the URL cache for the given range of video indices.
  void prefetchUrlsForIndex(int currentIndex) {
    // Prefetch next 2 video URLs into the cache.
    _prefetchUrls(currentIndex + 1, currentIndex + 3);
  }

  Future<String> resolveVideoUrl(String pathOrUrl) =>
      CreatorUrlCache.instance.resolve(pathOrUrl);

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
        // CreatorVideo is immutable — for now just log
        debugPrint(
          '[CreatorsFeed] Live stats update: likes=${newRecord['like_count']}, views=${newRecord['view_count']}',
        );
      }
    });
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  Future<List<CreatorVideo>> _fetchPage({required bool isFirstPage}) async {
    var query = Supabase.instance.client
        .from('creator_videos')
        .select('''
          *,
          profiles!creator_videos_creator_id_fkey(username, avatar_url)
        ''')
        .eq('status', 'approved')
        .isFilter('deleted_at', null);

    if (!isFirstPage &&
        _lastEngagementScore != null &&
        _lastCreatedAt != null) {
      // Cursor: fetch rows that come after the last seen combination.
      // This is stable even when new rows are inserted at the top.
      query = query.or(
        'engagement_score.lt.$_lastEngagementScore,'
        'and(engagement_score.eq.$_lastEngagementScore,created_at.lt.${_lastCreatedAt!.toIso8601String()})',
      );
    }

    final response = await query
        .order('engagement_score', ascending: false)
        .order('created_at', ascending: false)
        .limit(_pageSize);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => CreatorVideo.fromJson(json)).toList();
  }

  void _updateCursor() {
    if (_videos.isEmpty) return;
    final last = _videos.last;
    _lastEngagementScore = last.engagementScore;
    _lastCreatedAt = last.createdAt;
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
    if (_statsChannel != null) {
      _dataSource.unsubscribe(_statsChannel!);
    }
    super.dispose();
  }
}
