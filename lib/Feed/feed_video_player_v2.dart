import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/feed_item.dart';
import '../Home/shareSceen.dart';

/// Video player for the TMDB-based feed
/// Handles both TMDB trailers and YouTube BTS/Interview content
class FeedVideoPlayerV2 extends StatefulWidget {
  final FeedItem item;
  final int index;
  final bool isActive;
  final VoidCallback? onNext;

  const FeedVideoPlayerV2({
    Key? key,
    required this.item,
    required this.index,
    this.isActive = false,
    this.onNext,
  }) : super(key: key);

  @override
  State<FeedVideoPlayerV2> createState() => _FeedVideoPlayerV2State();
}

class _FeedVideoPlayerV2State extends State<FeedVideoPlayerV2> {
  YoutubePlayerController? _youtubeController;
  bool _isReady = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(FeedVideoPlayerV2 oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle active state changes
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _youtubeController?.play();
      } else {
        _youtubeController?.pause();
      }
    }
  }

  void _initializePlayer() {
    if (!widget.item.hasYouTubeVideo) return;

    _youtubeController = YoutubePlayerController(
      initialVideoId: widget.item.youtubeKey!,
      flags: YoutubePlayerFlags(
        autoPlay: widget.isActive,
        mute: false,
        disableDragSeek: true,
        loop: true,
        hideControls: true,
        controlsVisibleAtStart: false,
        enableCaption: false,
        
      ),
    );

    _youtubeController!.addListener(() {
      if (_youtubeController!.value.isReady && !_isReady) {
        setState(() => _isReady = true);
      }
    });
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (_youtubeController == null) return;

    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _youtubeController!.mute();
      } else {
        _youtubeController!.unMute();
      }
    });
  }

  void _togglePlayPause() {
    if (_youtubeController == null) return;

    if (_youtubeController!.value.isPlaying) {
      _youtubeController!.pause();
    } else {
      _youtubeController!.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('feed-item-${widget.index}'),
      onVisibilityChanged: (info) {
        if (!mounted || _youtubeController == null) return;

        if (info.visibleFraction > 0.9) {
          _youtubeController!.play();
        } else {
          _youtubeController!.pause();
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Video Layer
            if (widget.item.hasYouTubeVideo && _youtubeController != null)
              _buildVideoPlayer()
            else
              _buildThumbnailOnly(),

            // 2. Gradient Overlay
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.2, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Play/Pause Gesture
            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePlayPause,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

            // 4. Content Type Badge (Top Left)
            Positioned(top: 100, left: 16, child: _buildTypeBadge()),

            // 5. Metadata (Bottom Left)
            Positioned(
              bottom: 100,
              left: 16,
              right: 80,
              child: _buildMetadata(),
            ),

            // 6. Action Buttons (Bottom Right)
            Positioned(bottom: 100, right: 10, child: _buildActionButtons()),

            // 7. Mute Button (Top Right)
            Positioned(
              top: 100,
              right: 16,
              child: IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _toggleMute,
              ),
            ),

            // 8. Source Badge (Top Center)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.item.isBTS || widget.item.isInterview
                          ? Colors.red.withOpacity(0.8)
                          : Colors.blue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.item.isBTS || widget.item.isInterview
                              ? Icons.play_circle_outline
                              : Icons.movie_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.item.isBTS || widget.item.isInterview
                              ? 'YouTube'
                              : 'TMDB',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 9. Loading indicator
            if (!_isReady && widget.item.hasYouTubeVideo)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        bottomActions: const [],
        topActions: const [],
      ),
      builder: (context, player) {
        return Center(child: player);
      },
    );
  }

  Widget _buildThumbnailOnly() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: widget.item.bestThumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.grey[900]),
          errorWidget: (_, __, ___) => Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(Icons.movie, color: Colors.white54, size: 64),
            ),
          ),
        ),
        Container(color: Colors.black38),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_outline, color: Colors.white, size: 64),
              SizedBox(height: 8),
              Text(
                'No video available',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBadge() {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (widget.item.type) {
      case 'trailer':
        badgeColor = Colors.blue;
        badgeIcon = Icons.movie;
        badgeText = 'TRAILER';
        break;
      case 'teaser':
        badgeColor = Colors.purple;
        badgeIcon = Icons.movie_filter;
        badgeText = 'TEASER';
        break;
      case 'bts':
        badgeColor = Colors.orange;
        badgeIcon = Icons.videocam;
        badgeText = 'BEHIND THE SCENES';
        break;
      case 'interview':
        badgeColor = Colors.green;
        badgeIcon = Icons.mic;
        badgeText = 'INTERVIEW';
        break;
      default:
        badgeColor = Colors.grey;
        badgeIcon = Icons.play_arrow;
        badgeText = 'VIDEO';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recommendation reason
        if (widget.item.reason != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.item.reason!,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),

        // Title
        Text(
          widget.item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 6),

        // Overview or description
        if (widget.item.overview != null && widget.item.overview!.isNotEmpty)
          Text(
            widget.item.overview!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
            ),
          ),

        const SizedBox(height: 8),

        // Additional info row
        Row(
          children: [
            // Media type
            if (widget.item.mediaType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.item.mediaType!.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),

            // Rating
            if (widget.item.voteAverage != null && widget.item.voteAverage! > 0)
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: Colors.amber,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    widget.item.voteAverage!.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(Icons.favorite_border, "Like", () {}),
        const SizedBox(height: 20),
        _buildActionButton(Icons.bookmark_border, "Save", () {}),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => showShareBottomSheet(context),
          child: _buildActionButton(Icons.share, "Share", null),
        ),
        const SizedBox(height: 20),
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: widget.item.fullPosterUrl ?? widget.item.bestThumbnailUrl,
            width: 48,
            height: 64,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(width: 48, height: 64, color: Colors.grey[800]),
            errorWidget: (_, __, ___) => Container(
              width: 48,
              height: 64,
              color: Colors.grey[800],
              child: const Icon(Icons.movie, color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
