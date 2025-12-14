/// YouTube Video Item Widget (TikTok-style)
///
/// Individual video page for the vertical feed.
///
/// Key features:
/// - Error listener for restricted videos (auto-skip)
/// - Gesture priority fix (PageView scroll takes precedence)
/// - Prominent mute button overlay
/// - Thumbnail fallback while loading
/// - TikTok-style metadata and action buttons

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

    return Consumer<YoutubeFeedProvider>(
      builder: (context, provider, _) {
        // Safety check
        if (widget.index >= provider.videos.length) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final video = provider.videos[widget.index];
        final controller = provider.getController(widget.index);
        final isCurrentVideo = widget.index == provider.currentIndex;

        return Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Video Player Layer (or loading thumbnail)
              if (controller != null)
                _buildVideoPlayer(controller, provider)
              else
                _buildLoadingState(video),

              // 2. Gradient overlays for text readability
              _buildGradientOverlay(),

              // 3. Play/Pause gesture area (handles taps, lets swipes through)
              if (controller != null)
                _buildPlayPauseGesture(provider, controller),

              // 4. Metadata (Bottom Left)
              Positioned(
                bottom: 100,
                left: 16,
                right: 80,
                child: _buildMetadata(video),
              ),

              // 5. Action Buttons (Bottom Right)
              Positioned(
                bottom: 100,
                right: 10,
                child: _buildActionButtons(context, video),
              ),

              // 6. PROMINENT Mute Button (Top Right)
              Positioned(top: 80, right: 16, child: _buildMuteButton(provider)),

              // 7. Play icon overlay (when paused)
              if (controller != null &&
                  controller.value.playerState == PlayerState.paused &&
                  isCurrentVideo)
                _buildPlayIconOverlay(),

              // 8. Error indicator (if controller has error)
              if (controller != null && controller.value.errorCode != 0)
                _buildErrorIndicator(controller.value.errorCode),
            ],
          ),
        );
      },
    );
  }

  /// Build the YouTube player with gesture handling
  /// CRITICAL: Uses AbsorbPointer to prevent player from intercepting PageView swipes
  Widget _buildVideoPlayer(
    YoutubePlayerController controller,
    YoutubeFeedProvider provider,
  ) {
    // Ensure playing via post-frame callback
    _ensurePlaying(controller, provider);

    return AbsorbPointer(
      // BLOCK all gestures from the YouTube player
      // This prevents the bouncing/scroll conflict with PageView
      absorbing: true,
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
              onReady: () {
                debugPrint('[YTItem] Player ready for index ${widget.index}');
                // Force play if this is the current video
                if (provider.currentIndex == widget.index) {
                  controller.play();
                }
              },
              onEnded: (metaData) {
                debugPrint('[YTItem] Video ended at index ${widget.index}');
                controller.play();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _ensurePlaying(
    YoutubePlayerController controller,
    YoutubeFeedProvider provider,
  ) {
    // Use delayed callback with retry for reliable autoplay
    _tryAutoPlay(controller, provider, 0);
  }

  void _tryAutoPlay(
    YoutubePlayerController controller,
    YoutubeFeedProvider provider,
    int attempt,
  ) {
    if (attempt >= 3) return; // Max 3 attempts

    Future.delayed(Duration(milliseconds: 200 + (attempt * 150)), () {
      if (!mounted) return;
      if (provider.currentIndex != widget.index) return;

      if (!controller.value.isPlaying) {
        debugPrint(
          '[YTItem] Auto-play attempt ${attempt + 1} for index ${widget.index}',
        );
        controller.play();

        // Retry if still not playing
        _tryAutoPlay(controller, provider, attempt + 1);
      }
    });
  }

  /// Play/Pause gesture detector
  /// Uses HitTestBehavior.translucent to not block PageView swipes
  Widget _buildPlayPauseGesture(
    YoutubeFeedProvider provider,
    YoutubePlayerController controller,
  ) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _togglePlayPause(provider, controller),
        // Translucent allows swipes to pass through to PageView
        behavior: HitTestBehavior.translucent,
        child: Container(color: Colors.transparent),
      ),
    );
  }

  void _togglePlayPause(
    YoutubeFeedProvider provider,
    YoutubePlayerController controller,
  ) {
    if (controller.value.playerState == PlayerState.playing) {
      provider.pause(widget.index);
    } else {
      provider.play(widget.index);
    }
  }

  /// Loading state with thumbnail
  Widget _buildLoadingState(FeedVideo video) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail background
        if (video.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: video.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.black),
            errorWidget: (_, __, ___) => Container(color: Colors.black),
          )
        else
          Container(color: Colors.black),

        // Dark overlay
        Container(color: Colors.black54),

        // Loading indicator
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
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

  /// Gradient overlays for text readability
  Widget _buildGradientOverlay() {
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

  /// PROMINENT Mute Button
  Widget _buildMuteButton(YoutubeFeedProvider provider) {
    return GestureDetector(
      onTap: () => provider.toggleMute(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 1),
        ),
        child: Icon(
          provider.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// Play icon overlay (shown when paused)
  Widget _buildPlayIconOverlay() {
    return Center(
      child: IgnorePointer(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 60),
        ),
      ),
    );
  }

  /// Error indicator (for debugging)
  Widget _buildErrorIndicator(int errorCode) {
    return Positioned(
      top: 140,
      left: 16,
      child: Container(
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
      ),
    );
  }

  /// Video metadata (bottom left)
  Widget _buildMetadata(FeedVideo video) {
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
                color: Colors.amber.withOpacity(0.9),
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
                        color: Colors.black,
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

        // Channel name / media type
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

        // Video title
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

        // Description (if available)
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

  /// Action buttons (bottom right) - TikTok style
  Widget _buildActionButtons(BuildContext context, FeedVideo video) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';
    final userName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';
    final userAvatar = user?.photoURL;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reaction button (Instagram-style)
        ReactionButton(
          videoId: video.videoId,
          userId: userId,
          size: 32,
          showCount: true,
        ),
        const SizedBox(height: 20),
        // Comment button
        CommentButton(
          videoId: video.videoId,
          userId: userId,
          userName: userName,
          userAvatar: userAvatar,
          size: 26,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.person_outline,
          label: 'Friends',
          onTap: () => Navigator.pushNamed(context, 'friends'),
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.share_outlined,
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

        // Avatar / Thumbnail
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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
            child: Icon(icon, color: Colors.white, size: 26),
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
