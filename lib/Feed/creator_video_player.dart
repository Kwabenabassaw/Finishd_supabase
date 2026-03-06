import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'package:finishd/MovieDetails/movie_details_screen.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/profile/profileScreen.dart';
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
  final bool isLiked;
  final VideoPlayerController? controller;
  final bool isVisible;
  final String? resolvedThumbnailUrl;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const CreatorVideoPlayer({
    super.key,
    required this.video,
    required this.isLiked,
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

  /// Track if the user has opted to see a video that contains spoilers
  bool _spoilerAcknowledged = false;

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
          if (widget.video.spoiler && !_spoilerAcknowledged) {
            setState(() {
              _spoilerAcknowledged = true;
            });
            return;
          }
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(ctrl),
                        if (widget.video.spoiler && !_spoilerAcknowledged)
                          ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                              child: Container(
                                color: Colors.black.withOpacity(0.4),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.visibility_off,
                                      color: Colors.white,
                                      size: 32.sp,
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      "Contains Spoilers",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 1.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4.w,
                                        vertical: 1.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "Tap to view",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                isLiked: widget.isLiked,
                onLike: widget.onLike,
                onComment: widget.onComment,
                onShare: widget.onShare,
              ),
            ),

            // ── Layer 6: Progress Bar ──────────────────────────────────────
            if (hasVideo)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  ctrl,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF1A8927), // App accent color
                    backgroundColor: Colors.white24,
                    bufferedColor: Colors.white54,
                  ),
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
            fit: BoxFit.contain, // Replaces cover so video back is dark
            placeholder: (ctx, url) => const ColoredBox(color: Colors.black),
            errorWidget: (ctx, url, err) =>
                const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),

        // Shimmer pulse overlay — removed for a cleaner theatrical look as requested.
        // Instead of white pulse, we just play an animated loading bar from the center.

        // Center outward loading animation
        if (widget.isLoading)
          Center(
            child: AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                // shimmerAnimation goes from 0.08 to 0.25 (originally). Let's map it
                // to a scale width. Map [0.08, 0.25] to [0.0, 1.0] roughly.
                final scale = (_shimmerAnimation.value - 0.08) / (0.25 - 0.08);
                return Container(
                  width: 30.w * scale,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
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
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _VideoOverlay({
    required this.video,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<_VideoOverlay> createState() => _VideoOverlayState();
}

class _VideoOverlayState extends State<_VideoOverlay> {
  // We use the widget's isLiked initially, but optimistic updates within
  // this local state machine make it respond instantly until the parent
  // rebuilds with the true updated state.

  @override
  void initState() {
    super.initState();
  }

  void _onAvatarTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(uid: widget.video.creatorId),
      ),
    );
  }

  void _onTitleTap() {
    if (widget.video.tmdbId == null) return;

    final item = MediaItem(
      id: widget.video.tmdbId!,
      title: widget.video.tmdbTitle ?? 'Unknown',
      overview: "",
      imageUrl: "",
      voteAverage: 0.0,
      mediaType: widget.video.tmdbType ?? "movie",
      backdropPath: "",
      posterPath: "",
      releaseDate: "",
      genreIds: [],
    );

    final provider = Provider.of<MovieProvider>(context, listen: false);
    final result = provider.convertMediaItemToResult(item);
    provider.selectSearchItem([result], 0);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GenericDetailsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Right action column
        Positioned(
          right: 3.w, // originally 12
          bottom: 10
              .h, // originally 80, adjusted slightly for nav/progress bar visually
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                label: '${widget.video.likeCount}',
                color: widget.isLiked ? Colors.red : Colors.white,
                onTap: widget.onLike,
              ),
              SizedBox(height: 2.5.h), // originally 20
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: '${widget.video.commentCount}',
                onTap: widget.onComment,
              ),
              SizedBox(height: 2.5.h),
              _ActionButton(
                icon: Icons.share,
                label: '${widget.video.shareCount}',
                onTap: widget.onShare,
              ),
              SizedBox(height: 2.5.h),
              GestureDetector(
                onTap: _onAvatarTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    CircleAvatar(
                      radius: 20.sp, // originally 20
                      backgroundImage: widget.video.creatorAvatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(
                              widget.video.creatorAvatarUrl,
                            )
                          : null,
                      child: widget.video.creatorAvatarUrl.isEmpty
                          ? Icon(Icons.person, size: 20.sp)
                          : null,
                    ),
                    Positioned(
                      bottom: -8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A8927), // Theme primary
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom-left metadata
        Positioned(
          left: 3.w, // originally 12
          bottom: 8.h, // originally 70
          right: 18.w, // originally 72
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.video.title.isNotEmpty) ...[
                GestureDetector(
                  onTap: _onTitleTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF1A8927,
                      ).withOpacity(0.8), // Theme primary color
                      borderRadius: BorderRadius.circular(8.sp),
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.movie_creation_outlined,
                          color: Colors.white,
                          size: 12.sp,
                        ),
                        SizedBox(width: 1.w),
                        Flexible(
                          child: Text(
                            widget.video.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 1.w),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 12.sp,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 1.h),
              ],
              GestureDetector(
                onTap: _onAvatarTap,
                child: Text(
                  '@${widget.video.creatorName}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp, // originally 16
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.video.description.isNotEmpty) ...[
                SizedBox(height: 1.h), // originally 8
                Text(
                  widget.video.description,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp, // originally 14
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
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
          Icon(icon, color: color, size: 24.sp), // originally 32
          SizedBox(height: 0.5.h), // originally 4
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp, // originally 12
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 2,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
