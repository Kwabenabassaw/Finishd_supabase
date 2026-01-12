import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/feed_item.dart';

/// Manages YouTube player controllers for the video feed
/// Implements conservative 1-video-ahead preloading with resource management
class YouTubeVideoManager extends ChangeNotifier {
  final Map<int, YoutubePlayerController> _controllers = {};
  int _currentIndex = 0;
  bool _isDisposed = false;

  /// Get controller for a specific index
  YoutubePlayerController? getController(int index) => _controllers[index];

  /// Get current playing index
  int get currentIndex => _currentIndex;

  /// Check if a controller exists and is ready
  bool isReady(int index) {
    final controller = _controllers[index];
    return controller != null && controller.value.isReady;
  }

  /// Set current index and manage prefetch window
  /// Window: [current, current+1] only
  Future<void> setCurrentIndex(int index, List<FeedItem> items) async {
    if (_isDisposed) return;
    if (index < 0 || index >= items.length) return;

    final previousIndex = _currentIndex;
    _currentIndex = index;

    debugPrint('[YouTubeVideoManager] 🎯 Setting current index: $index');

    // Pause previous video immediately to prevent audio overlap
    if (previousIndex != index && _controllers.containsKey(previousIndex)) {
      debugPrint(
        '[YouTubeVideoManager] ⏸️ Pausing previous index: $previousIndex',
      );
      _controllers[previousIndex]?.pause();
      _controllers[previousIndex]?.mute();
    }

    // Update prefetch window
    await _updateWindow(items);

    // Play current video
    if (_controllers.containsKey(index)) {
      debugPrint('[YouTubeVideoManager] ▶️ Playing current index: $index');
      _controllers[index]?.unMute();
      _controllers[index]?.play();
    }

    notifyListeners();
  }

  /// Update the prefetch window
  /// Keeps only: [currentIndex, currentIndex + 1]
  Future<void> _updateWindow(List<FeedItem> items) async {
    if (_isDisposed) return;

    // Target indices: current and next only
    final targetIndices = <int>{};
    targetIndices.add(_currentIndex);
    if (_currentIndex + 1 < items.length) {
      targetIndices.add(_currentIndex + 1);
    }

    debugPrint('[YouTubeVideoManager] 🔄 Window: $targetIndices');

    // Dispose controllers outside window immediately
    final toDispose = _controllers.keys
        .where((i) => !targetIndices.contains(i))
        .toList();

    for (final i in toDispose) {
      _disposeController(i);
    }

    // Create controller for current index first (priority)
    if (!_controllers.containsKey(_currentIndex)) {
      await _createController(
        _currentIndex,
        items[_currentIndex],
        isCurrent: true,
      );
    }

    // Create controller for next index (preload, muted and paused)
    final nextIndex = _currentIndex + 1;
    if (nextIndex < items.length && !_controllers.containsKey(nextIndex)) {
      // Small delay to prioritize current video
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!_isDisposed && !_controllers.containsKey(nextIndex)) {
          _createController(nextIndex, items[nextIndex], isCurrent: false);
        }
      });
    }
  }

  /// Create a controller for a specific video
  Future<void> _createController(
    int index,
    FeedItem item, {
    required bool isCurrent,
  }) async {
    if (_isDisposed) return;
    if (_controllers.containsKey(index)) return;
    if (!item.hasYouTubeVideo || item.youtubeKey == null) return;

    debugPrint(
      '[YouTubeVideoManager] 🎬 Creating controller for index $index (current: $isCurrent)',
    );

    try {
      final controller = YoutubePlayerController(
        initialVideoId: item.youtubeKey!,
        flags: YoutubePlayerFlags(
          autoPlay: isCurrent, // Only autoplay if current
          mute: !isCurrent, // Mute if preloading
          disableDragSeek: true,
          loop: true,
          hideControls: true,
          controlsVisibleAtStart: false,
          enableCaption: false,
        ),
      );

      _controllers[index] = controller;
      debugPrint('[YouTubeVideoManager] ✅ Controller created for index $index');

      notifyListeners();
    } catch (e) {
      debugPrint(
        '[YouTubeVideoManager] ❌ Error creating controller for $index: $e',
      );
    }
  }

  /// Dispose a controller
  void _disposeController(int index) {
    final controller = _controllers.remove(index);
    if (controller != null) {
      debugPrint(
        '[YouTubeVideoManager] 🗑️ Disposing controller at index $index',
      );
      controller.pause();
      controller.dispose();
    }
  }

  /// Play video at specific index
  void play(int index) {
    if (_isDisposed) return;
    final controller = _controllers[index];
    if (controller != null && index == _currentIndex) {
      controller.unMute();
      controller.play();
    }
  }

  /// Pause video at specific index
  void pause(int index) {
    final controller = _controllers[index];
    controller?.pause();
  }

  /// Pause all videos (for app lifecycle)
  void pauseAll() {
    for (final controller in _controllers.values) {
      controller.pause();
    }
  }

  /// Resume current video
  void resumeCurrent() {
    final controller = _controllers[_currentIndex];
    controller?.play();
  }

  /// Toggle mute for current video
  void toggleMute() {
    final controller = _controllers[_currentIndex];
    if (controller != null) {
      if (controller.value.volume > 0) {
        controller.mute();
      } else {
        controller.unMute();
      }
      notifyListeners();
    }
  }

  /// Check if current video is muted
  bool get isMuted {
    final controller = _controllers[_currentIndex];
    return controller?.value.volume == 0;
  }

  /// Dispose all controllers and cleanup
  @override
  void dispose() {
    _isDisposed = true;
    debugPrint('[YouTubeVideoManager] 🗑️ Disposing all controllers');

    for (final controller in _controllers.values) {
      controller.pause();
      controller.dispose();
    }
    _controllers.clear();

    super.dispose();
  }
}
