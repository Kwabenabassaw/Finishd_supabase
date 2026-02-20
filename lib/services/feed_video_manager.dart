import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed_item.dart';

/// Unified Video Manager for Feed
/// Handles both YouTube and MP4 content with strict resource management.
/// Enforces a maximum window of [current, next] to prevent memory leaks.
class FeedVideoManager extends ChangeNotifier {
  // YouTube Controllers
  final Map<int, YoutubePlayerController> _ytControllers = {};

  // MP4 Controllers
  final Map<int, VideoPlayerController> _mp4Controllers = {};

  int _currentIndex = 0;
  bool _isDisposed = false;
  bool _globalMute = false; // Persist mute state across videos

  /// Get YouTube controller for a specific index
  YoutubePlayerController? getYoutubeController(int index) =>
      _ytControllers[index];

  /// Get MP4 controller for a specific index
  VideoPlayerController? getMp4Controller(int index) => _mp4Controllers[index];

  /// Get current playing index
  int get currentIndex => _currentIndex;

  /// Get mute state
  bool get isMuted => _globalMute;

  /// Check if ANY controller exists and is ready at index
  bool isReady(int index) {
    if (_ytControllers.containsKey(index)) {
      return _ytControllers[index]!.value.isReady;
    }
    if (_mp4Controllers.containsKey(index)) {
      return _mp4Controllers[index]!.value.isInitialized;
    }
    return false;
  }

  /// Set current index and manage prefetch window
  /// Window: [current, current+1] only
  Future<void> setCurrentIndex(int index, List<FeedItem> items) async {
    if (_isDisposed) return;
    if (index < 0 || index >= items.length) return;

    final previousIndex = _currentIndex;
    _currentIndex = index;

    debugPrint('[FeedVideoManager] 🎯 Setting current index: $index');

    // Pause previous video immediately
    _pauseAtIndex(previousIndex);

    // Update prefetch window and dispose others
    await _updateWindow(items);

    // Play current video
    _playAtIndex(index);

    notifyListeners();
  }

  void _pauseAtIndex(int index) {
    if (_ytControllers.containsKey(index)) {
      debugPrint('[FeedVideoManager] ⏸️ Pausing YouTube index: $index');
      _ytControllers[index]?.pause();
    }
    if (_mp4Controllers.containsKey(index)) {
      debugPrint('[FeedVideoManager] ⏸️ Pausing MP4 index: $index');
      _mp4Controllers[index]?.pause();
    }
  }

  void _playAtIndex(int index) {
    if (_ytControllers.containsKey(index)) {
      debugPrint(
        '[FeedVideoManager] ▶️ Playing YouTube index: $index (Muted: $_globalMute)',
      );
      if (_globalMute)
        _ytControllers[index]?.mute();
      else
        _ytControllers[index]?.unMute();
      _ytControllers[index]?.play();
    }
    if (_mp4Controllers.containsKey(index)) {
      debugPrint(
        '[FeedVideoManager] ▶️ Playing MP4 index: $index (Muted: $_globalMute)',
      );
      _mp4Controllers[index]?.setVolume(_globalMute ? 0.0 : 1.0);
      _mp4Controllers[index]?.play();
    }
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

    debugPrint('[FeedVideoManager] 🔄 Window: $targetIndices');

    // 1. Dispose YouTube controllers outside window
    final ytToDispose = _ytControllers.keys
        .where((i) => !targetIndices.contains(i))
        .toList();
    for (final i in ytToDispose) _disposeYoutubeController(i);

    // 2. Dispose MP4 controllers outside window
    final mp4ToDispose = _mp4Controllers.keys
        .where((i) => !targetIndices.contains(i))
        .toList();
    for (final i in mp4ToDispose) _disposeMp4Controller(i);

    // 3. Create controller for current index (High Priority)
    await _ensureController(items, _currentIndex, isCurrent: true);

    // 4. Create controller for next index (Low Priority)
    final nextIndex = _currentIndex + 1;
    if (nextIndex < items.length) {
      // Small delay to let UI settle
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_isDisposed) {
          _ensureController(items, nextIndex, isCurrent: false);
        }
      });
    }
  }

  Future<void> _ensureController(
    List<FeedItem> items,
    int index, {
    required bool isCurrent,
  }) async {
    final item = items[index];

    // Case A: Creator Video (MP4)
    if (item.isCreatorVideo) {
      if (!_mp4Controllers.containsKey(index)) {
        await _createMp4Controller(index, item.videoUrl, isCurrent);
      }
    }
    // Case B: YouTube Video
    else if (item.hasYouTubeVideo) {
      if (!_ytControllers.containsKey(index)) {
        await _createYoutubeController(index, item.youtubeKey, isCurrent);
      }
    }
  }

  Future<void> _createMp4Controller(
    int index,
    String? url,
    bool isCurrent,
  ) async {
    if (url == null || url.isEmpty) return;
    try {
      debugPrint('[FeedVideoManager] 🎬 Creating MP4 controller for $index');

      String effectiveUrl = url;
      // If URL is a path (not http), sign it
      if (!url.startsWith('http')) {
        try {
          effectiveUrl = await Supabase.instance.client.storage
              .from('creator-videos')
              .createSignedUrl(url, 60 * 60); // 1 hour expiry
          debugPrint('[FeedVideoManager] 🔐 Signed URL generated for $index');
        } catch (e) {
          debugPrint('[FeedVideoManager] ⚠️ Failed to sign URL: $e');
          // Fallback to original, though likely to fail
        }
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(effectiveUrl),
      );

      // Store before init to prevent double-creation
      _mp4Controllers[index] = controller;

      await controller.initialize();
      controller.setLooping(true);

      if (isCurrent) {
        controller.play();
        controller.setVolume(_globalMute ? 0.0 : 1.0);
      } else {
        controller.pause();
        controller.setVolume(0.0); // Mute preload
      }

      notifyListeners();
      debugPrint('[FeedVideoManager] ✅ MP4 Ready: $index');
    } catch (e) {
      debugPrint('[FeedVideoManager] ❌ MP4 Error index $index: $e');
      _mp4Controllers.remove(index); // Remove failed keys
    }
  }

  Future<void> _createYoutubeController(
    int index,
    String? key,
    bool isCurrent,
  ) async {
    if (key == null) return;
    try {
      debugPrint(
        '[FeedVideoManager] 🎬 Creating YouTube controller for $index',
      );
      final controller = YoutubePlayerController(
        initialVideoId: key,
        flags: YoutubePlayerFlags(
          autoPlay: isCurrent,
          mute: isCurrent
              ? _globalMute
              : true, // Respect global mute if current, else mute (preload)
          disableDragSeek: true,
          loop: true,
          hideControls: true,
          controlsVisibleAtStart: false,
          enableCaption: false,
        ),
      );

      _ytControllers[index] = controller;
      notifyListeners();
    } catch (e) {
      debugPrint('[FeedVideoManager] ❌ YouTube Error index $index: $e');
    }
  }

  void _disposeYoutubeController(int index) {
    if (_ytControllers.containsKey(index)) {
      debugPrint('[FeedVideoManager] 🗑️ Disposing YouTube $index');
      final c = _ytControllers.remove(index);
      c?.pause();
      c?.dispose();
    }
  }

  void _disposeMp4Controller(int index) {
    if (_mp4Controllers.containsKey(index)) {
      debugPrint('[FeedVideoManager] 🗑️ Disposing MP4 $index');
      final c = _mp4Controllers.remove(index);
      c?.pause();
      c?.dispose();
    }
  }

  /// Unify toggle play/pause
  void togglePlay(int index) {
    if (_ytControllers.containsKey(index)) {
      final c = _ytControllers[index]!;
      c.value.isPlaying ? c.pause() : c.play();
      notifyListeners();
    }
    if (_mp4Controllers.containsKey(index)) {
      final c = _mp4Controllers[index]!;
      c.value.isPlaying ? c.pause() : c.play();
      notifyListeners();
    }
  }

  /// Unify toggle mute
  void toggleMute() {
    _globalMute = !_globalMute;

    // Apply to current immediately
    // YouTube
    if (_ytControllers.containsKey(_currentIndex)) {
      final c = _ytControllers[_currentIndex]!;
      if (_globalMute)
        c.mute();
      else
        c.unMute();
    }
    // MP4
    if (_mp4Controllers.containsKey(_currentIndex)) {
      final c = _mp4Controllers[_currentIndex]!;
      c.setVolume(_globalMute ? 0.0 : 1.0);
    }
    notifyListeners();
  }

  /// Dispose all
  @override
  void dispose() {
    _isDisposed = true;
    _pauseAll();
    for (final c in _ytControllers.values) c.dispose();
    for (final c in _mp4Controllers.values) c.dispose();
    _ytControllers.clear();
    _mp4Controllers.clear();
    super.dispose();
  }

  void _pauseAll() {
    for (final c in _ytControllers.values) c.pause();
    for (final c in _mp4Controllers.values) c.pause();
  }

  void pauseAll() => _pauseAll();

  void resumeCurrent() => _playAtIndex(_currentIndex);
}
