import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/models/creator_video.dart';

/// Data source for the TikTok-style feed backed by Supabase.
///
/// Handles:
///   - Feed session management (seen-video dedup)
///   - Ranked feed fetching via RPC
///   - Atomic view/like tracking
///   - Realtime subscriptions for live stats
class SupabaseFeedDataSource {
  SupabaseFeedDataSource([this._explicitClient]);

  final SupabaseClient? _explicitClient;
  String? _sessionId;

  /// Lazy — only accessed when a method is actually called,
  /// not at Provider construction time (which happens before
  /// Supabase.initialize() in some app configurations).
  SupabaseClient get _client => _explicitClient ?? Supabase.instance.client;

  // ── Session Management ──────────────────────────────────────────────────

  /// Initialize or restore a feed session for the current user.
  /// Creates a new session if one doesn't exist.
  Future<void> initSession() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[FeedDataSource] No user logged in, skipping session init');
      return;
    }

    try {
      final existing = await _client
          .from('feed_sessions')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        _sessionId = existing['id'] as String;
        debugPrint('[FeedDataSource] Restored session: $_sessionId');
      } else {
        final created = await _client
            .from('feed_sessions')
            .insert({'user_id': userId})
            .select('id')
            .single();
        _sessionId = created['id'] as String;
        debugPrint('[FeedDataSource] Created new session: $_sessionId');
      }
    } catch (e) {
      debugPrint('[FeedDataSource] Session init failed: $e');
      // Non-fatal — feed will work without session (just may show repeats)
    }
  }

  /// Reset the session (e.g., on pull-to-refresh) — clears seen videos.
  Future<void> resetSession() async {
    if (_sessionId == null) return;
    try {
      await _client
          .from('feed_sessions')
          .update({
            'seen_video_ids': <String>[],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _sessionId!);
    } catch (e) {
      debugPrint('[FeedDataSource] Reset session failed: $e');
    }
  }

  // ── Feed Fetching ───────────────────────────────────────────────────────

  /// Fetch personalized feed using the Supabase RPC.
  Future<List<CreatorVideo>> getRankedFeed({
    int limit = 15,
    bool coldStart = false,
  }) async {
    try {
      final response = await _client.rpc(
        'get_personalized_feed',
        params: {
          'p_session_id': _sessionId,
          'p_limit': limit,
          'p_user_id': _client.auth.currentUser?.id,
          'p_cold_start': coldStart,
        },
      );

      final List<dynamic> data = response as List<dynamic>;

      // Mark these videos as seen
      if (data.isNotEmpty && _sessionId != null) {
        final newIds = data.map((v) => v['id'] as String).toList();
        _markSeen(newIds);
      }

      return data.map((json) => CreatorVideo.fromRpcJson(json)).toList();
    } catch (e) {
      debugPrint('[FeedDataSource] getRankedFeed failed: $e');
      // Fallback: direct query without dedup
      return _fallbackFetch(limit: limit, cursorCreatedAt: null);
    }
  }

  /// Fallback fetch if RPC is not yet deployed/available.
  Future<List<CreatorVideo>> _fallbackFetch({
    int limit = 15,
    DateTime? cursorCreatedAt,
  }) async {
    var query = _client
        .from('creator_videos')
        .select('''
          *,
          profiles!creator_videos_creator_id_fkey(username, avatar_url)
        ''')
        .eq('status', 'approved')
        .isFilter('deleted_at', null);

    if (cursorCreatedAt != null) {
      query = query.lt('created_at', cursorCreatedAt.toIso8601String());
    }

    final response = await query
        .order('engagement_score', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => CreatorVideo.fromJson(json)).toList();
  }

  /// Batch insert feed impressions.
  Future<void> batchInsertImpressions(
    List<Map<String, dynamic>> impressions,
  ) async {
    if (impressions.isEmpty) return;
    try {
      await _client.rpc(
        'batch_insert_impressions',
        params: {'p_impressions': impressions},
      );
    } catch (e) {
      debugPrint('[FeedDataSource] batchInsertImpressions failed: $e');
    }
  }

  // ── Engagement Tracking ─────────────────────────────────────────────────

  /// Record a video view (atomic increment).
  Future<void> recordView(String videoId) async {
    try {
      await _client.rpc(
        'increment_video_views',
        params: {'p_video_id': videoId},
      );
    } catch (e) {
      debugPrint('[FeedDataSource] recordView failed: $e');
    }
  }

  /// Toggle like (atomic increment/decrement).
  Future<void> toggleLike(String videoId, bool isLiked) async {
    try {
      await _client.rpc(
        isLiked ? 'increment_video_likes' : 'decrement_video_likes',
        params: {'p_video_id': videoId},
      );
    } catch (e) {
      debugPrint('[FeedDataSource] toggleLike failed: $e');
    }
  }

  /// Record a share (atomic increment).
  Future<void> recordShare(String videoId) async {
    try {
      await _client.rpc(
        'increment_video_shares',
        params: {'p_video_id': videoId},
      );
    } catch (e) {
      debugPrint('[FeedDataSource] recordShare failed: $e');
    }
  }

  // ── Realtime ────────────────────────────────────────────────────────────

  /// Subscribe to live stat updates for a specific video.
  /// Returns the channel so the caller can unsubscribe.
  RealtimeChannel subscribeLiveStats(
    String videoId,
    void Function(Map<String, dynamic> newRecord) onUpdate,
  ) {
    return _client
        .channel('video-stats-$videoId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'creator_videos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: videoId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Unsubscribe from a realtime channel.
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }

  // ── Private ─────────────────────────────────────────────────────────────

  /// Mark video IDs as seen in the current session (fire-and-forget).
  void _markSeen(List<String> videoIds) {
    if (_sessionId == null || videoIds.isEmpty) return;
    _client
        .rpc(
          'append_seen_videos',
          params: {'p_session_id': _sessionId, 'p_new_ids': videoIds},
        )
        .then((_) {
          debugPrint(
            '[FeedDataSource] Marked ${videoIds.length} videos as seen',
          );
        })
        .catchError((e) {
          debugPrint('[FeedDataSource] markSeen failed: $e');
        });
  }
}
