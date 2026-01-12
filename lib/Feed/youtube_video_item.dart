import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/feed_video.dart';
import '../provider/youtube_feed_provider.dart';
import '../Home/shareSceen.dart';
import 'dart:ui';
import '../Widget/reactions/reaction_button.dart';
import '../Widget/comments/comment_button.dart';
import 'package:flutter/services.dart';
import 'image_feed_item.dart';

class YoutubeVideoItem extends StatefulWidget {
  final int index;

  const YoutubeVideoItem({Key? key, required this.index}) : super(key: key);

  @override
  State<YoutubeVideoItem> createState() => _YoutubeVideoItemState();
}

class _YoutubeVideoItemState extends State<YoutubeVideoItem>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  bool _showHeart = false;
  Offset _heartPos = Offset.zero;

  void _onDoubleTap(TapDownDetails details) {
    setState(() {
      _showHeart = true;
      _heartPos = details.localPosition;
    });
    HapticFeedback.mediumImpact();
    // Trigger like logic here if not already liked
    // ...

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  // Keep alive during minor scroll adjustments to prevent flickering
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // READ-ONLY access to provider for initial data to avoid full rebuilds
    final provider = context.read<YoutubeFeedProvider>();

    // Safety check - if index is out of bounds, return loading or empty
    if (widget.index >= provider.videos.length) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final video = provider.videos[widget.index];

    // If this is an image content item (not a video), render ImageFeedItem
    if (video.isImage) {
      final isActive = provider.currentIndex == widget.index;
      return ImageFeedItem(
        item: video,
        isActive: isActive,
        index: widget.index,
      );
    }

    return Container(
      color: Colors.black,
      child: GestureDetector(
        onDoubleTapDown: _onDoubleTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Video Player Layer (Scoped)
            _VideoPlayerLayer(index: widget.index, video: video),

            // 2. Gradient overlays for text readability
            const _GradientOverlay(),

            // 3. Play/Pause gesture area
            _PlayPauseGesture(index: widget.index),

            // 4. Metadata (Restored)
            Positioned(
              bottom: 0,
              left: 0,
              right: 100, // Leave room for action buttons
              child: SafeArea(
                top: false,
                right: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    bottom: 20.0,
                    right: 16.0,
                  ),
                  child: _VideoMetadata(video: video),
                ),
              ),
            ),

            // 5. Action Buttons (Bottom Right) - Now Reactive
            Positioned(
              bottom: 0,
              right: 0,
              child: SafeArea(
                top: false,
                left: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0, right: 10.0),
                  // Use Selector to reactively update isActive
                  child: Selector<YoutubeFeedProvider, bool>(
                    selector: (_, provider) =>
                        provider.currentIndex == widget.index,
                    builder: (context, isActive, _) {
                      return _ActionButtons(video: video, isActive: isActive);
                    },
                  ),
                ),
              ),
            ),

            // 6. PROMINENT Mute Button (Top Right) - Scoped
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                left: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0, right: 16.0),
                  child: const _MuteButton(),
                ),
              ),
            ),

            // 7. Play icon overlay (Scoped)
            Center(child: _PlayIconOverlay(index: widget.index)),

            // 8. Error indicator (Scoped)
            Positioned(
              top: 140,
              left: 16,
              child: SafeArea(child: _ErrorIndicator(index: widget.index)),
            ),

            // 9. Double Tap Heart Animation
            if (_showHeart)
              Positioned(
                left: _heartPos.dx - 40,
                top: _heartPos.dy - 40,
                child: _HeartAnimation(),
              ),
          ],
        ),
      ),
    );
  }
}

/// --------------------------------------------------------------------------
/// 1. Scoped Video Player Layer
/// --------------------------------------------------------------------------
class _VideoPlayerLayer extends StatelessWidget {
  final int index;
  final FeedVideo video;

  const _VideoPlayerLayer({required this.index, required this.video});

  @override
  Widget build(BuildContext context) {
    // Select BOTH controller and isCurrent status
    // This ensures we rebuild when this video becomes the active one
    return Selector<
      YoutubeFeedProvider,
      ({YoutubePlayerController? controller, bool isCurrent})
    >(
      selector: (_, provider) => (
        controller: provider.getController(index),
        isCurrent: provider.currentIndex == index,
      ),
      builder: (context, data, child) {
        if (data.controller != null) {
          return _buildPlayer(
            context,
            data.controller!,
            data.isCurrent,
            video.videoId,
          );
        } else {
          return _buildLoadingState();
        }
      },
      shouldRebuild: (prev, next) =>
          prev.controller != next.controller ||
          prev.isCurrent != next.isCurrent,
    );
  }

  Widget _buildPlayer(
    BuildContext context,
    YoutubePlayerController controller,
    bool isCurrent,
    String videoId,
  ) {
    // Detect if this is a Short (Vertical native)
    final isShort = video.videoType == 'short';

    // Shorts are already 9:16.
    // Since JS injection hides the UI, we don't need to zoom/crop anymore.
    final scale = 1.0;

    // Aspect Ratio: 9/16 for full screen vertical
    final aspectRatio = 9 / 16;

    return Stack(
      children: [
        // 1. Cropped Video Player
        Positioned.fill(
          child: ClipRect(
            child: OverflowBox(
              // Dynamic scaling based on content type
              minWidth: MediaQuery.of(context).size.width * scale,
              minHeight: MediaQuery.of(context).size.height * scale,
              maxWidth: MediaQuery.of(context).size.width * scale,
              maxHeight: MediaQuery.of(context).size.height * scale,
              alignment: Alignment.center,
              child: AbsorbPointer(
                absorbing: true,
                child: YoutubePlayer(
                  aspectRatio: aspectRatio,
                  showVideoProgressIndicator: true,
                  progressColors: const ProgressBarColors(
                    playedColor: Colors.greenAccent,
                    handleColor: Colors.greenAccent,
                  ),
                  controller: controller,
                  thumbnail: const SizedBox.shrink(),
                  onEnded: (_) => controller.play(),
                  onReady: () {
                    // NOTE: JavaScript injection is not supported by youtube_player_flutter package
                    // UI customization is handled by YoutubePlayerFlags instead:
                    // - hideControls: true
                    // - hideThumbnail: true
                    // - controlsVisibleAtStart: false
                    // These flags are set in youtube_feed_provider.dart:_createController()
                    debugPrint(
                      '[YTVideoItem] ✅ Player ready for: ${video.videoId}',
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // 1.5. Thumbnail Mask (Hides "Ghost Button" before first play)
        Positioned.fill(
          child: ValueListenableBuilder<YoutubePlayerValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final shouldShow =
                  !value.isReady ||
                  value.playerState == PlayerState.cued ||
                  value.playerState == PlayerState.unknown;
              return AnimatedOpacity(
                opacity: shouldShow ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),

        // 2. Shorts Badge (if applicable)
        if (isShort)
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(230), // fixed withOpacity
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    FontAwesomeIcons.youtube,
                    color: Colors.white,
                    size: 12,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Shorts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 2. Top Shield (Covers titles/pre-roll UI)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 190,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Color.fromARGB(0, 5, 1, 1)],
              ),
            ),
          ),
        ),

        // 3. Bottom Shield (Covers logo/controls)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 140,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (video.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: video.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.black),
            errorWidget: (_, __, ___) => Container(color: Colors.black),
          )
        else
          Container(color: Colors.black),
        Container(color: Colors.black54), // Dim overlay
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoLoadingScreen(),
              SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// --------------------------------------------------------------------------
/// 2. Gradient Overlay (Static)
/// --------------------------------------------------------------------------
class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
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
            stops: [0.0, 0.2, 0.75, 1.0],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}

/// --------------------------------------------------------------------------
/// 3. Play/Pause Gesture (Scoped Action)
/// --------------------------------------------------------------------------
class _PlayPauseGesture extends StatelessWidget {
  final int index;

  const _PlayPauseGesture({required this.index});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          final provider = context.read<YoutubeFeedProvider>();
          final controller = provider.getController(index);
          if (controller != null) {
            if (controller.value.isPlaying) {
              provider.pause(index);
            } else {
              provider.play(index);
            }
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

/// --------------------------------------------------------------------------
/// 4. Mute Button (Scoped Rebuild)
/// --------------------------------------------------------------------------
class _MuteButton extends StatelessWidget {
  const _MuteButton();

  @override
  Widget build(BuildContext context) {
    return Selector<YoutubeFeedProvider, bool>(
      selector: (_, provider) => provider.isMuted,
      builder: (context, isMuted, _) {
        return GestureDetector(
          onTap: () => context.read<YoutubeFeedProvider>().toggleMute(),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: Icon(
              isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}

/// --------------------------------------------------------------------------
/// 5. Play Icon Overlay (Scoped Rebuild)
/// --------------------------------------------------------------------------
class _PlayIconOverlay extends StatelessWidget {
  final int index;

  const _PlayIconOverlay({required this.index});

  @override
  Widget build(BuildContext context) {
    return Selector<YoutubeFeedProvider, bool>(
      selector: (_, provider) {
        final controller = provider.getController(index);
        final isCurrent = provider.currentIndex == index;
        return isCurrent &&
            controller != null &&
            controller.value.playerState == PlayerState.paused;
      },
      builder: (context, showOverlay, _) {
        if (!showOverlay) return const SizedBox.shrink();

        return IgnorePointer(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
        );
      },
    );
  }
}

/// --------------------------------------------------------------------------
/// 6. Error Indicator (Scoped Rebuild)
/// --------------------------------------------------------------------------
class _ErrorIndicator extends StatelessWidget {
  final int index;

  const _ErrorIndicator({required this.index});

  @override
  Widget build(BuildContext context) {
    return Selector<YoutubeFeedProvider, int>(
      selector: (_, provider) =>
          provider.getController(index)?.value.errorCode ?? 0,
      builder: (context, errorCode, _) {
        if (errorCode == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'Error $errorCode - Skipping...',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// --------------------------------------------------------------------------
/// 7. Metadata (Static Widget)
/// --------------------------------------------------------------------------
class _VideoMetadata extends StatelessWidget {
  final FeedVideo video;

  const _VideoMetadata({required this.video});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Feed type and recommendation badges row
        _buildBadgesRow(),

        // Channel Name / Media Type
        Text(
          video.channelName.isNotEmpty
              ? video.channelName
              : (video.type == 'VIDEO_ONLY' ? 'Video' : 'MOVIE'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.3,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),

        // Description (Optional)
        if (video.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            video.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  /// Build the badges row with feed type and recommendation reason
  Widget _buildBadgesRow() {
    final hasFeedType = video.feedType != null && video.feedType!.isNotEmpty;
    final hasRecommendation =
        video.recommendationReason != null &&
        video.recommendationReason!.isNotEmpty;

    if (!hasFeedType && !hasRecommendation) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          // Feed Type Badge (Trending, Following, For You)
          if (hasFeedType) _buildFeedTypeBadge(video.feedType!),

          // Video Type Badge (Extra, BTS) - NEW
          if (video.type == 'VIDEO_ONLY') _buildVideoTypeBadge(),

          // Recommendation Reason Badge
          if (hasRecommendation)
            _buildRecommendationBadge(video.recommendationReason!),
        ],
      ),
    );
  }

  /// Build badge for video-only content (Extras, BTS)
  Widget _buildVideoTypeBadge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library_rounded,
                size: 12,
                color: Colors.white70,
              ),
              SizedBox(width: 4),
              Text(
                'EXTRA',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build feed type badge with distinct styling per type
  Widget _buildFeedTypeBadge(String feedType) {
    // Get icon and color based on feed type
    IconData icon;
    Color iconColor;
    String label;

    switch (feedType.toLowerCase()) {
      case 'trending':
        icon = Icons.trending_up_rounded;
        iconColor = Colors.orangeAccent;
        label = 'Trending';
        break;
      case 'following':
        icon = Icons.people_alt_rounded;
        iconColor = Colors.lightBlueAccent;
        label = 'Following';
        break;
      case 'for_you':
        icon = Icons.auto_awesome;
        iconColor = Colors.pinkAccent;
        label = 'For You';
        break;
      default:
        icon = Icons.play_circle_outline;
        iconColor = Colors.white70;
        label = feedType;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: iconColor.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build recommendation reason badge
  Widget _buildRecommendationBadge(String reason) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  reason,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// --------------------------------------------------------------------------
/// 8. Action Buttons (Static Widget)
/// --------------------------------------------------------------------------
class _ActionButtons extends StatelessWidget {
  final FeedVideo video;
  final bool isActive;

  const _ActionButtons({required this.video, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';
    final userName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';
    final userAvatar = user?.photoURL;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile Avatar at the Top (TikTok style)
        _buildProfileAvatar(context, video),
        const SizedBox(height: 16),

        // Reaction Button
        ReactionButton(
          videoId: video.videoId,
          userId: userId,
          size: 32,
          showCount: true,
        ),
        const SizedBox(height: 16),

        // Comment Button
        CommentButton(
          videoId: video.videoId,
          userId: userId,
          userName: userName,
          userAvatar: userAvatar,
          size: 26,
        ),
        const SizedBox(height: 16),

        // Share Button
        _ActionButton(
          icon: FontAwesomeIcons.share,
          label: 'Share',
          onTap: () => showVideoShareSheet(
            context,
            videoId: video.videoId,
            videoTitle: video.title,
            videoThumbnail: video.thumbnailUrl,
            videoChannel: video.channelName,
          ),
        ),
        const SizedBox(height: 20),

        // Spinning Music Disk
        _SpinningDisk(thumbnailUrl: video.thumbnailUrl, isActive: isActive),
      ],
    );
  }

  Widget _buildProfileAvatar(BuildContext context, FeedVideo video) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundImage: video.thumbnailUrl.isNotEmpty
            ? CachedNetworkImageProvider(video.thumbnailUrl)
            : null,
        backgroundColor: Colors.grey[800],
        child: video.thumbnailUrl.isEmpty
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),

            child: FaIcon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicScrollingText extends StatefulWidget {
  final FeedVideo video;
  final bool isActive;

  const _MusicScrollingText({required this.video, required this.isActive});

  @override
  State<_MusicScrollingText> createState() => _MusicScrollingTextState();
}

class _MusicScrollingTextState extends State<_MusicScrollingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _animation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(-1.5, 0.0),
    ).animate(_controller);

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_MusicScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.music_note, color: Colors.white, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRect(
            child: SlideTransition(
              position: _animation,
              child: Text(
                '${widget.video.channelName} • Original Sound - ${widget.video.title}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpinningDisk extends StatefulWidget {
  final String thumbnailUrl;
  final bool isActive;

  const _SpinningDisk({required this.thumbnailUrl, required this.isActive});

  @override
  State<_SpinningDisk> createState() => _SpinningDiskState();
}

class _SpinningDiskState extends State<_SpinningDisk>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_SpinningDisk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [Colors.grey[900]!, Colors.black, Colors.grey[900]!],
          ),
        ),
        child: CircleAvatar(
          radius: 12,
          backgroundImage: widget.thumbnailUrl.isNotEmpty
              ? CachedNetworkImageProvider(widget.thumbnailUrl)
              : null,
          backgroundColor: Colors.grey[800],
        ),
      ),
    );
  }
}

class _HeartAnimation extends StatefulWidget {
  @override
  State<_HeartAnimation> createState() => _HeartAnimationState();
}

class _HeartAnimationState extends State<_HeartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(_controller);
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: const Icon(Icons.favorite, color: Colors.red, size: 80),
          ),
        );
      },
    );
  }
}
