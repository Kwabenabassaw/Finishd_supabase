import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'youtube_mp4_extractor.dart';
import '../models/feed_video.dart';

/// Manages a pool of DualVideoControllers for instant playback.
/// Follows the "YouTube Shorts" performance model:
/// - Preloads 2 ahead, 1 behind
/// - Keeps 3-5 controllers in memory
/// - Disposes controllers > 3 indices away
class FastVideoPoolManager extends ChangeNotifier {
  final YouTubeMp4Extractor _extractor = YouTubeMp4Extractor();

  // The pool of active dual controllers
  final Map<int, DualVideoController> _controllers = {};

  // Track initialization status to avoid double-init
  final Set<int> _initializing = {};

  int _currentIndex = 0;
  bool _isDisposed = false;

  /// Get the active controller (LQ or HQ) for the UI
  VideoPlayerController? getController(int index) =>
      _controllers[index]?.activeController;

  /// Initialize the pool with the first few videos
  Future<void> initialize(List<FeedVideo> videos) async {
    await _updatePool(0, videos);
  }

  /// Called when the user scrolls to a new page
  void onPageChanged(int index, List<FeedVideo> videos) {
    if (_currentIndex == index) return;

    // Pause the old video immediately
    _controllers[_currentIndex]?.pause();

    _currentIndex = index;

    // Play the new video immediately if ready
    _controllers[index]?.play();

    // Update the pool (preload next/prev, dispose old)
    _updatePool(index, videos);

    notifyListeners();
  }

  /// Manages the pool of controllers:
  /// - Creates needed controllers (Current, +1, +2, -1)
  /// - Disposes distant controllers (> 3 away)
  Future<void> _updatePool(int index, List<FeedVideo> videos) async {
    if (_isDisposed) return;

    // 1. Define the window of indices to keep
    final window = {
      index, // Current
      index + 1, // Next
      index + 2, // Next + 1 (Preload)
      index - 1, // Previous (Keep for back scroll)
    };

    // 2. Identify controllers to dispose (outside window AND > 3 away)
    // We keep a slightly larger buffer for disposal to prevent thrashing
    // if the user scrolls back and forth quickly.
    final toDispose = _controllers.keys.where((key) {
      return (key - index).abs() > 3;
    }).toList();

    for (final key in toDispose) {
      debugPrint('[FastVideoPool] 🗑️ Disposing index $key');
      final controller = _controllers.remove(key);
      controller?.dispose();
    }

    // 3. Create missing controllers in the window
    for (final targetIndex in window) {
      if (targetIndex >= 0 && targetIndex < videos.length) {
        if (!_controllers.containsKey(targetIndex) &&
            !_initializing.contains(targetIndex)) {
          _createController(targetIndex, videos[targetIndex]);
        }
      }
    }
  }

  Future<void> _createController(int index, FeedVideo video) async {
    _initializing.add(index);
    debugPrint('[FastVideoPool] 🎬 Preloading index $index: ${video.title}');

    try {
      final urls = await _extractor.getStreamUrls(video.videoId);

      if (_isDisposed) return;

      if (urls == null) {
        _initializing.remove(index);
        return;
      }

      final dualController = DualVideoController(
        lowQualityUrl: urls.lowQualityUrl,
        highQualityUrl: urls.highQualityUrl,
        onSwap: () {
          // Notify UI when swap happens (LQ -> HQ)
          notifyListeners();
        },
      );

      // Initialize LQ first (fastest)
      await dualController.initializeLowQuality();

      if (_isDisposed) {
        dualController.dispose();
        return;
      }

      _controllers[index] = dualController;

      // If this is the current index, play immediately!
      if (index == _currentIndex) {
        debugPrint('[FastVideoPool] ▶️ Auto-playing index $index (LQ)');
        dualController.play();
      }

      notifyListeners();

      // Start loading HQ in background
      dualController.initializeHighQuality().then((_) {
        if (index == _currentIndex && !_isDisposed) {
          debugPrint('[FastVideoPool] ⚡ Swapped to HQ for index $index');
        }
      });
    } catch (e) {
      debugPrint('[FastVideoPool] ❌ Error loading index $index: $e');
    } finally {
      _initializing.remove(index);
    }
  }

  void play(int index) {
    _controllers[index]?.play();
  }

  void pause(int index) {
    _controllers[index]?.pause();
  }

  void pauseAll() {
    for (final controller in _controllers.values) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _extractor.dispose();
    super.dispose();
  }
}

/// Helper class to manage Low and High quality controllers
class DualVideoController {
  final String lowQualityUrl;
  final String highQualityUrl;
  final VoidCallback onSwap;

  VideoPlayerController? _lowController;
  VideoPlayerController? _highController;

  bool _isUsingHighQuality = false;
  bool _isDisposed = false;

  DualVideoController({
    required this.lowQualityUrl,
    required this.highQualityUrl,
    required this.onSwap,
  });

  VideoPlayerController? get activeController =>
      _isUsingHighQuality ? _highController : _lowController;

  Future<void> initializeLowQuality() async {
    _lowController = VideoPlayerController.networkUrl(
      Uri.parse(lowQualityUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    await _lowController!.initialize();
    _lowController!.setLooping(true);
    _lowController!.setVolume(1.0);
  }

  Future<void> initializeHighQuality() async {
    try {
      _highController = VideoPlayerController.networkUrl(
        Uri.parse(highQualityUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await _highController!.initialize();
      _highController!.setLooping(true);
      _highController!.setVolume(1.0);

      if (_isDisposed) return;

      // Check if we should swap (if LQ is playing)
      if (_lowController != null && _lowController!.value.isPlaying) {
        await _swapToHighQuality();
      } else {
        // If paused, just swap state so next play uses HQ
        _isUsingHighQuality = true;
        onSwap();
        // Dispose LQ to save memory
        _lowController?.dispose();
        _lowController = null;
      }
    } catch (e) {
      debugPrint('[DualVideoController] ❌ Failed to load HQ: $e');
    }
  }

  Future<void> _swapToHighQuality() async {
    if (_lowController == null || _highController == null) return;

    final position = _lowController!.value.position;
    await _highController!.seekTo(position);
    await _highController!.play();

    _isUsingHighQuality = true;
    onSwap();

    _lowController!.pause();
    _lowController!.dispose();
    _lowController = null;
  }

  void play() {
    activeController?.play();
    // If we just started playing and HQ is ready but not active (edge case), swap?
    // The initializeHighQuality logic handles the swap if it finishes while playing.
    // If it finished while paused, _isUsingHighQuality is already true.
  }

  void pause() {
    activeController?.pause();
  }

  void dispose() {
    _isDisposed = true;
    _lowController?.dispose();
    _highController?.dispose();
  }
}
