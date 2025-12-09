/// YouTube Iframe Video Item
///
/// Individual video page for the TikTok-style feed.
///
/// Key features:
/// - Gesture overlay to prevent WebView stealing scroll gestures
/// - Unmute button for user to enable sound after autoplay
/// - Error handling for Status 150 (restricted content)
/// - Loading state with thumbnail

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:finishd/models/feed_video.dart';

class IframeVideoItem extends StatefulWidget {
  final FeedVideo video;
  final YoutubePlayerController? controller;
  final bool isMuted;
  final bool isCurrentVideo;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onVideoTap;

  const IframeVideoItem({
    super.key,
    required this.video,
    required this.controller,
    required this.isMuted,
    required this.isCurrentVideo,
    this.onMuteToggle,
    this.onVideoTap,
  });

  @override
  State<IframeVideoItem> createState() => _IframeVideoItemState();
}

class _IframeVideoItemState extends State<IframeVideoItem> {
  bool _hasError = false;
  bool _isLoading = true;
  bool _showPlayButton = false;

  @override
  void initState() {
    super.initState();
    _setupPlayerListener();
  }

  void _setupPlayerListener() {
    if (widget.controller == null) return;

    // Listen for player state changes
    widget.controller!.stream.listen(
      (event) {
        if (!mounted) return;

        // Handle player states
        if (event.playerState == PlayerState.playing) {
          setState(() {
            _isLoading = false;
            _showPlayButton = false;
          });
        } else if (event.playerState == PlayerState.buffering) {
          setState(() => _isLoading = true);
        } else if (event.playerState == PlayerState.cued) {
          // Status 5 - video cued but not playing
          // This happens when autoplay is blocked
          setState(() {
            _isLoading = false;
            _showPlayButton = true;
          });
        } else if (event.playerState == PlayerState.paused) {
          setState(() => _showPlayButton = true);
        }
      },
      onError: (error) {
        // Handle Status 150 or other errors
        debugPrint('❌ Player error: $error');
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background thumbnail (shows while loading)
          if (widget.video.thumbnailUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                widget.video.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
            ),

          // Player or Error State
          if (_hasError)
            _buildErrorState()
          else if (widget.controller != null)
            _buildPlayer(),

          // Gesture Overlay - CRITICAL for smooth scrolling
          // This transparent overlay captures gestures so WebView
          // doesn't steal the vertical swipe
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_showPlayButton) {
                  widget.controller?.playVideo();
                } else {
                  widget.onVideoTap?.call();
                }
              },
              // Allow vertical drag to pass through for scrolling
              onVerticalDragUpdate: (_) {},
            ),
          ),

          // Loading indicator
          if (_isLoading && !_hasError)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),

          // Play button (shown when video is cued/paused)
          if (_showPlayButton && !_hasError)
            Center(
              child: GestureDetector(
                onTap: () {
                  widget.controller?.playVideo();
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),

          // Mute/Unmute Button
          Positioned(bottom: 120, right: 16, child: _buildMuteButton()),

          // Video Info Overlay
          Positioned(
            left: 16,
            right: 80,
            bottom: 100,
            child: _buildVideoInfo(),
          ),

          // Gradient overlay for text readability
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return ClipRect(
      child: YoutubePlayer(
        controller: widget.controller!,
        aspectRatio: 9 / 16, // Vertical video aspect ratio
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Video Unavailable',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This video cannot be played',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.video.title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMuteButton() {
    return GestureDetector(
      onTap: widget.onMuteToggle,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(
          widget.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          widget.video.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),

        // Channel name
        if (widget.video.channelName.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.video.channelName,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

        const SizedBox(height: 4),

        // Recommendation reason
        if (widget.video.recommendationReason?.isNotEmpty == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.video.recommendationReason!,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
