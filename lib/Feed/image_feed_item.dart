import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:finishd/models/feed_video.dart';
import 'package:finishd/Widget/reactions/reaction_button.dart';
import 'package:finishd/Widget/comments/comment_button.dart';
import 'package:finishd/Home/shareSceen.dart';

/// Full-screen image feed item for mixed feeds.
/// Displays movie stills/backdrops with metadata overlay.
class ImageFeedItem extends StatelessWidget {
  final FeedVideo item;
  final bool isActive;
  final int index;

  const ImageFeedItem({
    super.key,
    required this.item,
    required this.isActive,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Full-screen image
        _buildImage(),

        // 2. Gradient overlays
        _buildGradientOverlay(),

        // 3. Metadata (bottom left)
        Positioned(
          left: 16,
          right: 80,
          bottom: 100,
          child: _ImageMetadata(item: item),
        ),

        // 4. Action buttons (right side)
        Positioned(
          right: 12,
          bottom: 120,
          child: _ImageActionButtons(item: item),
        ),

        // 5. Image indicator badge
        Positioned(top: 60, right: 16, child: _buildImageBadge()),
      ],
    );
  }

  Widget _buildImage() {
    final imageUrl = item.imageUrl ?? item.thumbnailUrl;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.5),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.2, 0.6, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildImageBadge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo, size: 14, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                'PHOTO',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Metadata overlay for image content
class _ImageMetadata extends StatelessWidget {
  final FeedVideo item;

  const _ImageMetadata({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Media type badge
        if (item.relatedItemType != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: Text(
              item.relatedItemType!.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),

        // Title
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),

        const SizedBox(height: 8),

        // Description
        if (item.description.isNotEmpty)
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.3,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
      ],
    );
  }
}

/// Action buttons for image content (like, comment, share)
class _ImageActionButtons extends StatelessWidget {
  final FeedVideo item;

  const _ImageActionButtons({required this.item});

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
        // Profile Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundImage: item.thumbnailUrl.isNotEmpty
                ? CachedNetworkImageProvider(item.thumbnailUrl)
                : null,
            backgroundColor: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),

        // Reaction Button
        ReactionButton(
          videoId: item.videoId,
          userId: userId,
          size: 32,
          showCount: true,
        ),
        const SizedBox(height: 16),

        // Comment Button
        CommentButton(
          videoId: item.videoId,
          userId: userId,
          userName: userName,
          userAvatar: userAvatar,
          size: 26,
        ),
        const SizedBox(height: 16),

        // Share Button
        GestureDetector(
          onTap: () => showVideoShareSheet(
            context,
            videoId: item.videoId,
            videoTitle: item.title,
            videoThumbnail: item.thumbnailUrl,
            videoChannel: item.channelName,
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(FontAwesomeIcons.share, color: Colors.white, size: 20),
              SizedBox(height: 4),
              Text(
                'Share',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
