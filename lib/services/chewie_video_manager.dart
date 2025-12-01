import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'youtube_mp4_extractor.dart';
import '../models/feed_video.dart';

/// Manages Chewie controllers for the video feed
/// Handles prefetching, disposal, and playback management
class ChewieVideoManager extends ChangeNotifier {
  final YouTubeMp4Extractor _extractor = YouTubeMp4Extractor();
  final Map<int, ChewieController> _controllers = {};
  final Map<int, VideoPlayerController> _videoControllers = {};
  int _currentIndex = 0;
  bool _isDisposed = false;

  /// Get controller for a specific index
  ChewieController? getController(int index) => _controllers[index];

  /// Get current playing index
  int get currentIndex => _currentIndex;

  /// Set current index and manage prefetch window
  Future<void> setCurrentIndex(int index, List<FeedVideo> videos) async {
    if (_isDisposed) return;

    // If we are just refreshing the same index (e.g. initial load), proceed
    // But if changing indices, pause the old one immediately
    if (_currentIndex != index) {
      debugPrint('[ChewieVideoManager] ⏸️ Pausing old index: $_currentIndex');
      _videoControllers[_currentIndex]?.pause();
      _currentIndex = index;
    }

    debugPrint('[ChewieVideoManager] 🎯 Setting current index: $index');

    // Update prefetch window
    await _updateWindow(videos);

    if (_isDisposed) return;

    // Only play if the index is still the current one (avoid race conditions)
    if (_currentIndex == index) {
      final controller = _videoControllers[index];
      if (controller != null && controller.value.isInitialized) {
        debugPrint('[ChewieVideoManager] ▶️ Playing current index: $index');
        controller.play();
      }
    }

    notifyListeners();
  }

  /// Play video at specific index
  void play(int index) {
    if (_isDisposed) return;
    final controller = _videoControllers[index];
    if (controller != null && !controller.value.isPlaying) {
      // Ensure we don't play if it's not the current index (unless intended)
      if (index == _currentIndex) {
        debugPrint('[ChewieVideoManager] ▶️ Playing video at index $index');
        controller.play();
      }
    }
  }

  /// Pause video at specific index
  void pause(int index) {
    final controller = _videoControllers[index];
    if (controller != null && controller.value.isPlaying) {
      debugPrint('[ChewieVideoManager] ⏸️ Pausing video at index $index');
      controller.pause();
    }
  }

  /// Update the prefetch window
  /// Keeps: currentIndex - 1, currentIndex, currentIndex + 1, currentIndex + 2
  Future<void> _updateWindow(List<FeedVideo> videos) async {
    if (_isDisposed) return;

    final targetIndices = {
      _currentIndex - 1, // Previous
      _currentIndex, // Current
      _currentIndex + 1, // Next
      _currentIndex + 2, // Next + 1
    }.where((i) => i >= 0 && i < videos.length).toSet();

    debugPrint('[ChewieVideoManager] 🔄 Window: $targetIndices');

    // Dispose controllers outside window
    final toDispose = _controllers.keys
        .where((i) => !targetIndices.contains(i))
        .toList();

    for (var i in toDispose) {
      await _disposeController(i);
    }

    // Create controllers for window
    // Prioritize current index first
    if (targetIndices.contains(_currentIndex)) {
      if (!_controllers.containsKey(_currentIndex)) {
        await _createController(_currentIndex, videos[_currentIndex]);
      }
    }

    // Then others
    for (var i in targetIndices) {
      if (i != _currentIndex && !_controllers.containsKey(i)) {
        // We don't await here to allow parallel loading for prefetch
        _createController(i, videos[i]);
      }
    }
  }

  /// Create a controller for a specific video
  Future<void> _createController(int index, FeedVideo video) async {
    if (_controllers.containsKey(index)) return;

    debugPrint(
      '[ChewieVideoManager] 🎬 Creating controller for index $index: ${video.title}',
    );

    try {
      // Extract MP4 URL
      final urls = await _extractor.getStreamUrls(video.videoId);

      if (_isDisposed) return;

      if (urls == null) {
        debugPrint(
          '[ChewieVideoManager] ❌ Failed to extract MP4 for ${video.videoId}',
        );
        return;
      }

      // Create VideoPlayer controller
      // mixWithOthers: false ensures we respect audio focus better
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse(urls.highQualityUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await videoController.initialize();

      if (_isDisposed) {
        videoController.dispose();
        return;
      }

      videoController.setLooping(true);
      videoController.setVolume(1); // Default to 1, UI handles muting

      // Create Chewie controller
      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: false,
        looping: true,
        showControls: false,
        aspectRatio: videoController.value.aspectRatio,
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      _videoControllers[index] = videoController;
      _controllers[index] = chewieController;

      debugPrint('[ChewieVideoManager] ✅ Controller created for index $index');

      // If we just created the controller for the current index, play it!
      if (index == _currentIndex && !_isDisposed) {
        videoController.play();
      }

      notifyListeners();
    } catch (e) {
      debugPrint(
        '[ChewieVideoManager] ❌ Error creating controller for $index: $e',
      );
    }
  }

  /// Dispose a controller
  Future<void> _disposeController(int index) async {
    final chewieController = _controllers.remove(index);
    final videoController = _videoControllers.remove(index);

    if (chewieController != null || videoController != null) {
      debugPrint(
        '[ChewieVideoManager] 🗑️ Disposing controller at index $index',
      );

      videoController?.pause();
      chewieController?.dispose();
      videoController?.dispose();
    }
  }

  /// Dispose all controllers and cleanup
  @override
  void dispose() {
    _isDisposed = true;
    debugPrint('[ChewieVideoManager] 🗑️ Disposing all controllers');
    pauseAll();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _videoControllers.clear();
    _extractor.dispose();
    super.dispose();
  }

  /// Pause all videos
  void pauseAll() {
    for (var controller in _videoControllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  /// Get video controller for a specific index
  VideoPlayerController? getVideoController(int index) =>
      _videoControllers[index];
}
