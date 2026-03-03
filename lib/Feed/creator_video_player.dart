import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/creator_video.dart';

/// A single video cell for the Creators TikTok-style feed.
///
/// PERFORMANCE CONTRACT:
/// - Does NOT own or create any [VideoPlayerController]. The controller is
///   managed by the [CreatorsFeedScreen] window manager (max 3 alive at once).
/// - All like/comment/share state lives in [_VideoOverlay], which is a
///   separate subtree from the [VideoPlayer]. Like taps NEVER trigger a
///   rebuild of the video layer.
/// - Wrapped in [RepaintBoundary] at the widget level.
class CreatorVideoPlayer extends StatelessWidget {
  final CreatorVideo video;
  final VideoPlayerController? controller;
  final bool isVisible;
  final String? resolvedThumbnailUrl;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const CreatorVideoPlayer({
    super.key,
    required this.video,
    required this.controller,
    required this.isVisible,
    this.resolvedThumbnailUrl,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    final bool hasVideo = ctrl != null && ctrl.value.isInitialized;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          if (ctrl != null && ctrl.value.isPlaying) {
            ctrl.pause();
          } else {
            ctrl?.play();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video layer ─────────────────────────────────────────────────
            // Black background fills the screen. The video is rendered at its
            // native aspect ratio using FittedBox(contain), centered in the
            // available space. No cropping, no stretching.
            const ColoredBox(color: Colors.black),
            if (hasVideo)
              Center(
                child: AspectRatio(
                  aspectRatio: ctrl.value.aspectRatio,
                  child: VideoPlayer(ctrl),
                ),
              )
            else
              _Thumbnail(thumbnailUrl: resolvedThumbnailUrl),

            // ── Gradient overlay (static — never repaints) ──────────────────
            const IgnorePointer(
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

            // ── Interactive overlay (isolated subtree) ───────────────────────
            RepaintBoundary(
              child: _VideoOverlay(
                video: video,
                onLike: onLike,
                onComment: onComment,
                onShare: onShare,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Thumbnail shown before the controller is ready
// ──────────────────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final String? thumbnailUrl;
  const _Thumbnail({this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl;
    if (url == null || url.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (ctx, url) => const ColoredBox(color: Colors.black),
      errorWidget: (ctx, url, err) => const ColoredBox(color: Colors.black),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Isolated overlay — owns all interactive state so setState calls here
// *never* touch the VideoPlayer widget above.
// ──────────────────────────────────────────────────────────────────────────────

class _VideoOverlay extends StatefulWidget {
  final CreatorVideo video;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _VideoOverlay({
    required this.video,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<_VideoOverlay> createState() => _VideoOverlayState();
}

class _VideoOverlayState extends State<_VideoOverlay> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = false;
    _likeCount = widget.video.likeCount;
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Right action column
        Positioned(
          right: 12,
          bottom: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                label: '$_likeCount',
                color: _isLiked ? Colors.red : Colors.white,
                onTap: _toggleLike,
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: '${widget.video.commentCount}',
                onTap: widget.onComment,
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.share,
                label: 'Share',
                onTap: widget.onShare,
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.video.creatorAvatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(widget.video.creatorAvatarUrl)
                    : null,
                child: widget.video.creatorAvatarUrl.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
            ],
          ),
        ),

        // Bottom-left metadata
        Positioned(
          left: 12,
          bottom: 70,
          right: 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${widget.video.creatorName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (widget.video.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.video.description,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Stateless action button
// ──────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
