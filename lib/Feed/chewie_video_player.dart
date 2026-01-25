import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/feed_video.dart';
import '../services/fast_video_pool_manager.dart';
import '../Home/shareSceen.dart';

class ChewieVideoPlayer extends StatefulWidget {
  final FeedVideo video;
  final int index;
  final FastVideoPoolManager manager;

  const ChewieVideoPlayer({
    super.key,
    required this.video,
    required this.index,
    required this.manager,
  });

  @override
  State<ChewieVideoPlayer> createState() => _ChewieVideoPlayerState();
}

class _ChewieVideoPlayerState extends State<ChewieVideoPlayer> {
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onManagerUpdate);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  void _toggleMute() {
    final controller = widget.manager.getController(widget.index);
    if (controller != null) {
      setState(() {
        _isMuted = !_isMuted;
        controller.setVolume(_isMuted ? 0 : 1);
      });
    }
  }

  void _togglePlayPause() {
    final controller = widget.manager.getController(widget.index);
    if (controller != null) {
      if (controller.value.isPlaying) {
        widget.manager.pause(widget.index);
      } else {
        widget.manager.play(widget.index);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.manager.getController(widget.index);
    final isInitialized = controller?.value.isInitialized ?? false;

    return VisibilityDetector(
      key: Key('video-${widget.index}'),
      onVisibilityChanged: (info) {
        if (!mounted || controller == null) return;

        // Play when 90% visible
        if (info.visibleFraction > 0.9) {
          if (!controller.value.isPlaying) {
            widget.manager.play(widget.index);
          }
        } else {
          // Pause when less than 90% visible
          if (controller.value.isPlaying) {
            widget.manager.pause(widget.index);
          }
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Video Layer
            if (isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: controller!.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else
              _buildLoadingState(),

            // 2. Gradient Overlay
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black45,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black54,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Play/Pause Gesture
            if (isInitialized)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // 4. Metadata (Bottom Left)
            Positioned(
              bottom: 90,
              left: 16,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.video.recommendationReason != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.video.recommendationReason!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    widget.video.channelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),

            // 5. Action Buttons (Bottom Right)
            Positioned(
              bottom: 90,
              right: 10,
              child: Column(
                children: [
                  _buildActionButton(Icons.favorite, "Like"),
                  const SizedBox(height: 20),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(3.14159), // Flip horizontally
                    child: _buildActionButton(Icons.comment, "Comment"),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, 'friends'),
                    child: _buildActionButton(Icons.person, "Friends"),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => showShareBottomSheet(context),
                    child: _buildActionButton(Icons.share, "Share"),
                  ),
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: CachedNetworkImageProvider(
                      widget.video.thumbnailUrl,
                    ),
                    backgroundColor: Colors.grey,
                  ),
                ],
              ),
            ),

            // 6. Mute Button
            if (isInitialized)
              Positioned(
                top: 80,
                right: 16,
                child: IconButton(
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  onPressed: _toggleMute,
                ),
              ),

            // 7. Play Icon Overlay (shown when paused)
            if (isInitialized && !controller!.value.isPlaying)
              const Center(
                child: IgnorePointer(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 60),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail
        CachedNetworkImage(
          imageUrl: widget.video.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.black),
          errorWidget: (_, __, ___) => Container(color: Colors.black),
        ),
        // Dark overlay
        Container(color: Colors.black54),
        // Loading indicator
        const Center(child: CircularProgressIndicator(color: Colors.white)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
