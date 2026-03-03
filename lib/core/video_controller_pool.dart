import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:finishd/services/creator_url_cache.dart';
import 'package:finishd/models/creator_video.dart';

/// Manages a sliding window of [VideoPlayerController] instances.
///
/// MEMORY CONTRACT:
///   Maximum 3 controllers alive: [currentIndex - 1, current, current + 1].
///   The next controller is pre-created after the current one activates,
///   so swiping forward starts playback instantly.
///   URL pre-warming covers currentIndex + 2 / + 3 (lightweight).
///
/// OWNERSHIP:
///   This pool OWNS every controller it creates. Widgets must NEVER
///   create or dispose controllers — they receive them via [getController].
class VideoControllerPool {
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializing = {};
  final Map<int, String> _resolvedThumbnails = {};
  bool _disposed = false;

  List<CreatorVideo> _videos = [];
  int _currentIndex = 0;

  /// Number of videos currently tracked by the pool.
  int get videoCount => _videos.length;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Set the video list. Call when feed data loads or paginates.
  void setVideos(List<CreatorVideo> videos) {
    if (_disposed) return;
    _videos = videos;
  }

  /// Called every time the user lands on a new feed item.
  Future<void> onPageChanged(int newIndex) async {
    if (_disposed) return;
    if (newIndex < 0 || newIndex >= _videos.length) return;
    final previousIndex = _currentIndex;
    _currentIndex = newIndex;

    // 1. Pause the previous video immediately (stops audio)
    _controllers[previousIndex]?.pause();

    // 2. Activate (init + play) the current video
    await _activateIndex(newIndex);

    // 3. Pre-create controller for next video so swipe is instant
    _preloadIndex(newIndex + 1);

    // 4. Pre-warm URL cache for videos beyond the preload window
    _prefetchUrls(newIndex);

    // 5. Dispose controllers outside [current-1, current, current+1]
    _disposeOutOfWindow(newIndex);
  }

  /// Get the controller for a specific index (null if not ready).
  VideoPlayerController? getController(int index) => _controllers[index];

  /// Get resolved thumbnail URL for index.
  String? getThumbnailUrl(int index) => _resolvedThumbnails[index];

  /// Pause all controllers (app goes to background).
  void pauseAll() {
    for (final controller in _controllers.values) {
      controller.pause();
    }
  }

  /// Resume the current video (app returns to foreground).
  void resumeCurrent() {
    final ctrl = _controllers[_currentIndex];
    if (ctrl != null && ctrl.value.isInitialized) {
      ctrl.setVolume(1.0);
      ctrl.play();
    }
  }

  /// Full teardown — call in State.dispose().
  void disposeAll() {
    _disposed = true;
    for (final controller in _controllers.values) {
      controller.pause();
      controller.dispose();
    }
    _controllers.clear();
    _initializing.clear();
    _resolvedThumbnails.clear();
  }

  /// Reset disposed flag so pool can be reused (e.g. after refresh).
  void reset() {
    _disposed = false;
    _currentIndex = 0;
  }

  // ── Private ─────────────────────────────────────────────────────────────

  /// Pre-creates a controller for [index] without playing it.
  /// This runs fire-and-forget so it doesn't block the current page.
  void _preloadIndex(int index) {
    if (_disposed) return;
    if (index < 0 || index >= _videos.length) return;
    if (_controllers.containsKey(index)) return; // already built
    if (_initializing.contains(index)) return; // build in progress

    _initializing.add(index);
    _buildController(index).then((ctrl) {
      _initializing.remove(index);
      if (_disposed || ctrl == null) {
        ctrl?.dispose();
        return;
      }
      _controllers[index] = ctrl;
    });
  }

  /// Initializes the controller for [index] and plays it.
  Future<void> _activateIndex(int index) async {
    if (_disposed) return;
    if (index < 0 || index >= _videos.length) return;

    VideoPlayerController? ctrl = _controllers[index];
    if (ctrl == null) {
      ctrl = await _buildController(index);
      // After await, verify state is still valid
      if (_disposed || _currentIndex != index) {
        ctrl?.pause();
        ctrl?.dispose();
        return;
      }
      if (ctrl == null) return;
      _controllers[index] = ctrl;
    }

    if (ctrl.value.isInitialized) {
      ctrl.setVolume(1.0);
      ctrl.play();
    }
    // If not initialized yet, the controller was just created and
    // _buildController already called initialize(). Once that future
    // completes, the controller is ready. We handle this by awaiting
    // _buildController above, so by this point it IS initialized
    // (or failed and returned null).
  }

  /// Pre-warms the URL cache for videos beyond the preload window.
  void _prefetchUrls(int centerIndex) {
    for (int i = 2; i <= 3; i++) {
      final idx = centerIndex + i;
      if (idx < _videos.length) {
        CreatorUrlCache.instance.prefetch(_videos[idx].videoUrl);
        if (_videos[idx].thumbnailUrl.isNotEmpty) {
          CreatorUrlCache.instance.prefetch(
            _videos[idx].thumbnailUrl,
            bucket: 'creator-thumbnails',
          );
        }
      }
    }
  }

  /// Disposes controllers outside [centerIndex - 1, centerIndex + 1].
  /// Maximum 3 controllers alive at any time (prev, current, next).
  ///
  /// CRITICAL: Native disposal is deferred to addPostFrameCallback.
  /// The VideoPlayer widget still references the native surface during
  /// the current frame. Disposing synchronously = crash.
  void _disposeOutOfWindow(int centerIndex) {
    final minKeep = (centerIndex - 1).clamp(0, _videos.length - 1);
    final maxKeep = centerIndex + 1;

    final keysToDispose = _controllers.keys
        .where((k) => k < minKeep || k > maxKeep)
        .toList();

    if (keysToDispose.isEmpty) return;

    final controllersToDispose = <VideoPlayerController>[];
    for (final k in keysToDispose) {
      final ctrl = _controllers.remove(k);
      _resolvedThumbnails.remove(k);
      if (ctrl != null) {
        ctrl.pause();
        controllersToDispose.add(ctrl);
      }
    }

    debugPrint(
      '[VideoPool] Window [$minKeep..$maxKeep], '
      'alive: ${_controllers.length}, disposing: ${controllersToDispose.length}',
    );

    // Defer native disposal to AFTER the widget tree rebuilds
    if (controllersToDispose.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final ctrl in controllersToDispose) {
          ctrl.dispose();
        }
      });
    }
  }

  /// Creates a [VideoPlayerController] and initializes it.
  Future<VideoPlayerController?> _buildController(int index) async {
    if (_disposed) return null;
    if (index < 0 || index >= _videos.length) return null;
    final video = _videos[index];

    try {
      final videoUrl = await CreatorUrlCache.instance.resolve(video.videoUrl);
      if (_disposed) return null;

      // Resolve + cache thumbnail URL
      if (video.thumbnailUrl.isNotEmpty) {
        final thumbUrl = await CreatorUrlCache.instance.resolveThumbnail(
          video.thumbnailUrl,
        );
        if (!_disposed) {
          _resolvedThumbnails[index] = thumbUrl;
        }
      }
      if (_disposed) return null;

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await ctrl.initialize();
      if (_disposed) {
        ctrl.dispose();
        return null;
      }

      ctrl.setLooping(true);

      return ctrl;
    } catch (e) {
      debugPrint('[VideoPool] Failed to build controller at $index: $e');
      return null;
    }
  }
}
