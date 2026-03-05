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
///
/// LOADING UX (TikTok-style):
/// - Shows thumbnail (poster / first frame) immediately with a shimmer pulse.
/// - Once the controller is initialized, crossfades (~300ms) from thumbnail
///   to live video playback.
/// - If buffering mid-play, shows a subtle loading indicator over the video.
class CreatorVideoPlayer extends StatefulWidget {
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
  State<CreatorVideoPlayer> createState() => _CreatorVideoPlayerState();
}

class _CreatorVideoPlayerState extends State<CreatorVideoPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  /// Track whether we've already crossfaded to avoid re-running on rebuilds.
  bool _hasRevealedVideo = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(covariant CreatorVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final ctrl = widget.controller;
    final bool hasVideo = ctrl != null && ctrl.value.isInitialized;

    // Trigger crossfade exactly once when video becomes ready
    if (hasVideo && !_hasRevealedVideo) {
      _hasRevealedVideo = true;
      _fadeController.forward();
    }

    // If the controller changed entirely (new video), reset the fade
    if (widget.controller != oldWidget.controller) {
      final newCtrl = widget.controller;
      final newHasVideo = newCtrl != null && newCtrl.value.isInitialized;
      if (!newHasVideo) {
        _hasRevealedVideo = false;
        _fadeController.reset();
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final bool hasVideo = ctrl != null && ctrl.value.isInitialized;

    // Check if the controller is initialized but still buffering
    final bool isBuffering =
        hasVideo && ctrl.value.isBuffering && !ctrl.value.isCompleted;

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
            // ── Base: Black background ─────────────────────────────────────
            const ColoredBox(color: Colors.black),

            // ── Layer 1: Thumbnail (always rendered underneath) ─────────────
            // Stays visible until the video fades in on top.
            _Thumbnail(
              thumbnailUrl: widget.resolvedThumbnailUrl,
              isLoading: !hasVideo,
            ),

            // ── Layer 2: Video (fades in over thumbnail) ───────────────────
            if (hasVideo)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: ctrl.value.aspectRatio,
                    child: VideoPlayer(ctrl),
                  ),
                ),
              ),

            // ── Layer 3: Buffering indicator (mid-play) ────────────────────
            if (isBuffering) const _BufferingIndicator(),

            // ── Layer 4: Gradient overlay (static — never repaints) ────────
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

            // ── Layer 5: Interactive overlay (isolated subtree) ────────────
            RepaintBoundary(
              child: _VideoOverlay(
                video: widget.video,
                onLike: widget.onLike,
                onComment: widget.onComment,
                onShare: widget.onShare,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Thumbnail with shimmer/pulse loading effect
// Shows the poster image (first frame) with a pulsing overlay while loading.
// ──────────────────────────────────────────────────────────────────────────────

class _Thumbnail extends StatefulWidget {
  final String? thumbnailUrl;
  final bool isLoading;

  const _Thumbnail({this.thumbnailUrl, required this.isLoading});

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _shimmerAnimation = Tween<double>(begin: 0.08, end: 0.25).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    if (widget.isLoading) {
      _shimmerController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _Thumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_shimmerController.isAnimating) {
      _shimmerController.repeat(reverse: true);
    } else if (!widget.isLoading && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The actual thumbnail image (or black if unavailable)
        if (url != null && url.isNotEmpty)
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => const ColoredBox(color: Colors.black),
            errorWidget: (ctx, url, err) =>
                const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),

        // Shimmer pulse overlay — only while loading
        if (widget.isLoading)
          AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                color: Colors.white.withOpacity(_shimmerAnimation.value),
              );
            },
          ),

        // Small centered loading spinner while loading
        if (widget.isLoading)
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white70,
              ),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Buffering indicator shown over video when it pauses to buffer mid-play.
// Matches TikTok's subtle center spinner on a semi-transparent scrim.
// ──────────────────────────────────────────────────────────────────────────────

class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white60,
        ),
      ),
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
