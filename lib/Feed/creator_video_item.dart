import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed_video.dart';
import '../provider/youtube_feed_provider.dart';

class CreatorVideoItem extends StatefulWidget {
  final FeedVideo video;
  final int index;

  const CreatorVideoItem({super.key, required this.video, required this.index});

  @override
  State<CreatorVideoItem> createState() => _CreatorVideoItemState();
}

class _CreatorVideoItemState extends State<CreatorVideoItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (widget.video.videoUrl == null) return;

    String videoUrl = widget.video.videoUrl!;
    // Check if it's a relative path (not starting with http)
    if (!videoUrl.startsWith('http')) {
      try {
        // Generate signed URL for private bucket
        videoUrl = await Supabase.instance.client.storage
            .from('creator-videos')
            .createSignedUrl(videoUrl, 60 * 60); // 1 hour expiry
      } catch (e) {
        debugPrint('Error generating signed URL: $e');
        return;
      }
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _controller!.initialize();
    _controller!.setLooping(true);

    // Mute by default if provider is muted (or logic can be handled by provider)
    // For simplicity, we just check global provider state if possible, or start muted.
    // _controller!.setVolume(0);

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _play() {
    _controller?.play();
  }

  void _pause() {
    _controller?.pause();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider to see if this item is the CURRENT index
    final isActive = context.select<YoutubeFeedProvider, bool>(
      (p) => p.currentIndex == widget.index,
    );

    // Auto-play/pause based on active state
    if (_isInitialized) {
      if (isActive) {
        _play();
      } else {
        _pause();
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video Player
        if (_isInitialized && _controller != null)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          )
        else
          // Placeholder / Thumbnail
          CachedNetworkImage(
            imageUrl: widget.video.thumbnailUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: Colors.black),
          ),

        // 2. Gradient Overlay
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black87],
                begin: Alignment.center,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // 3. Metadata and Actions
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${widget.video.channelName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.video.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Actions (Like, Comment, etc - Optional for now)
              // We can add them later or reuse existing buttons
            ],
          ),
        ),
      ],
    );
  }
}
