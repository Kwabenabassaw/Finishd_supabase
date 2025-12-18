/// YouTube Video Item Widget (TikTok-style)
///
/// Individual video page for the vertical feed.
/// Refactored for performance: Uses scoped state access to prevent full rebuilds.
///
/// Key features:
/// - Scoped rebuilds (only mute button/player rebuild when needed)
/// - Error listener for restricted videos (auto-skip)
/// - Gesture priority fix (PageView scroll takes precedence)
/// - Prominent mute button overlay
/// - Thumbnail fallback while loading
/// - TikTok-style metadata and action buttons
/// - SafeArea compliance

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
import '../Widget/reactions/reaction_button.dart';
import '../Widget/comments/comment_button.dart';

class YoutubeVideoItem extends StatefulWidget {
  final int index;

  const YoutubeVideoItem({Key? key, required this.index}) : super(key: key);

  @override
  State<YoutubeVideoItem> createState() => _YoutubeVideoItemState();
}

class _YoutubeVideoItemState extends State<YoutubeVideoItem>
    with AutomaticKeepAliveClientMixin {
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

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Player Layer (Scoped)
          _VideoPlayerLayer(index: widget.index, video: video),

          // 2. Gradient overlays for text readability
          const _GradientOverlay(),

          // 3. Play/Pause gesture area
          _PlayPauseGesture(index: widget.index),

          // 4. Metadata (Bottom Left) - Static
          Positioned(
            bottom: 0,
            left: 0,
            right: 80, // Leave room for side buttons
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

          // 5. Action Buttons (Bottom Right) - Static
          Positioned(
            bottom: 0,
            right: 0,
            child: SafeArea(
              top: false,
              left: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0, right: 10.0),
                child: _ActionButtons(video: video),
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
        ],
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
    // Note: We rely on the Provider to give us a fresh controller when isCurrent is true
    // (due to the new windowing strategy), so we don't need to manually force load() here anymore.
    // The controller should be fresh and ready to play.

    return AbsorbPointer(
      absorbing: true, // Block YouTube player gestures to allow scrolling
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: YoutubePlayer(
              controller: controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: const ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
              onEnded: (_) {
                controller.play(); // Loop
              },
            ),
          ),
        ),
      ),
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
        // Recommendation reason badge
        if (video.recommendationReason != null &&
            video.recommendationReason!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 4, 152, 9).withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up, size: 14, color: Colors.black),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      video.recommendationReason!,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 206, 204, 204),
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

        // Channel Name
        Text(
          video.channelName.isNotEmpty ? video.channelName : 'MOVIE',
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
}

/// --------------------------------------------------------------------------
/// 8. Action Buttons (Static Widget)
/// --------------------------------------------------------------------------
class _ActionButtons extends StatelessWidget {
  final FeedVideo video;

  const _ActionButtons({required this.video});

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
        // Reaction Button
        ReactionButton(
          videoId: video.videoId,
          userId: userId,
          size: 32,
          showCount: true,
        ),
        const SizedBox(height: 20),

        // Comment Button
        CommentButton(
          videoId: video.videoId,
          userId: userId,
          userName: userName,
          userAvatar: userAvatar,
          size: 26,
        ),
        const SizedBox(height: 20),

        // Friends Button
        _ActionButton(
          icon: FontAwesomeIcons.users,
          label: 'Friends',
          onTap: () => Navigator.pushNamed(context, 'friends'),
        ),
        const SizedBox(height: 20),

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
        const SizedBox(height: 24),

        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundImage: video.thumbnailUrl.isNotEmpty
                ? CachedNetworkImageProvider(video.thumbnailUrl)
                : null,
            backgroundColor: Colors.grey[800],
            child: video.thumbnailUrl.isEmpty
                ? const Icon(Icons.movie, color: Colors.white)
                : null,
          ),
        ),
      ],
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
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, color: Colors.white, size: 26),
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
