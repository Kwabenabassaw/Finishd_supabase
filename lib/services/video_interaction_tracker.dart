import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks per-video watch interactions on the client side.
///
/// LIFECYCLE:
///   1. Call [startTracking] when a video starts playing.
///   2. Call [stopTracking] when the user swipes away or the video is paused
///      for a tab change / background event.
///   3. [stopTracking] fires-and-forgets an upsert to `video_interactions`.
///
/// SIGNALS TRACKED:
///   - **watch_time_ms** — accumulated from a [Stopwatch].
///   - **completed** — true if watch_time ≥ 90% of duration.
///   - **skipped** — true if user swiped away within [_skipThresholdMs].
///   - **rewatched** — true if watch_time exceeds duration (user looped).
class VideoInteractionTracker {
  VideoInteractionTracker([this._explicitClient]);

  final SupabaseClient? _explicitClient;
  SupabaseClient get _client => _explicitClient ?? Supabase.instance.client;

  // ── Active tracking state ──────────────────────────────────────────────

  String? _currentVideoId;
  int _currentDurationMs = 0;
  final Stopwatch _stopwatch = Stopwatch();

  /// Threshold below which a swipe-away counts as "skipped".
  static const int _skipThresholdMs = 2000;

  /// Threshold above which watch_time / duration counts as "completed".
  static const double _completionThreshold = 0.90;

  // ── Public API ─────────────────────────────────────────────────────────

  /// Begin tracking a new video. Stops any previous tracking first.
  void startTracking(String videoId, int durationMs) {
    // If we were tracking a different video, flush it first.
    if (_currentVideoId != null && _currentVideoId != videoId) {
      stopTracking();
    }

    _currentVideoId = videoId;
    _currentDurationMs = durationMs;
    _stopwatch.reset();
    _stopwatch.start();
  }

  /// Stop tracking the current video and flush the interaction to Supabase.
  ///
  /// Safe to call multiple times — no-ops if nothing is being tracked.
  void stopTracking() {
    if (_currentVideoId == null) return;

    _stopwatch.stop();
    final watchTimeMs = _stopwatch.elapsedMilliseconds;
    final videoId = _currentVideoId!;
    final durationMs = _currentDurationMs;

    // Reset state immediately so a fast re-call doesn't double-fire.
    _currentVideoId = null;
    _currentDurationMs = 0;

    // Compute signals
    final completed =
        durationMs > 0 && (watchTimeMs / durationMs) >= _completionThreshold;
    final skipped = watchTimeMs < _skipThresholdMs;
    final rewatched = durationMs > 0 && watchTimeMs > durationMs;

    // Fire-and-forget upsert
    _upsert(
      videoId: videoId,
      watchTimeMs: watchTimeMs,
      durationMs: durationMs,
      completed: completed,
      skipped: skipped,
      rewatched: rewatched,
    );
  }

  /// Pause the stopwatch without flushing (e.g. app backgrounded).
  void pause() => _stopwatch.stop();

  /// Resume the stopwatch (e.g. app returned to foreground).
  void resume() {
    if (_currentVideoId != null) _stopwatch.start();
  }

  /// Whether tracking is active.
  bool get isTracking => _currentVideoId != null && _stopwatch.isRunning;

  // ── Private ────────────────────────────────────────────────────────────

  Future<void> _upsert({
    required String videoId,
    required int watchTimeMs,
    required int durationMs,
    required bool completed,
    required bool skipped,
    required bool rewatched,
  }) async {
    try {
      await _client.rpc(
        'upsert_video_interaction',
        params: {
          'p_video_id': videoId,
          'p_watch_time_ms': watchTimeMs,
          'p_duration_ms': durationMs,
          'p_completed': completed,
          'p_skipped': skipped,
          'p_rewatched': rewatched,
        },
      );
      debugPrint(
        '[InteractionTracker] Upserted: $videoId '
        '(${watchTimeMs}ms, completed=$completed, skipped=$skipped)',
      );
    } catch (e) {
      // Non-fatal — the feed works without this data.
      debugPrint('[InteractionTracker] Upsert failed: $e');
    }
  }
}
