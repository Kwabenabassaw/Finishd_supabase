import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'video_link_preview.dart';
import 'recommendation_preview.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final Timestamp timestamp;
  final bool isRead;
  final String type;
  final String? mediaUrl;
  final String? videoId;
  final String? videoTitle;
  final String? videoThumbnail;
  final String? videoChannel;
  final VoidCallback? onVideoTap;
  // Recommendation fields
  final String? movieId;
  final String? movieTitle;
  final String? moviePoster;
  final String? mediaType;
  final VoidCallback? onRecommendationTap;
  final VoidCallback? onImageTap;
  // Post sharing fields
  final String? postId;
  final String? postContent;
  final String? postAuthorName;
  final String? postShowTitle;
  final VoidCallback? onPostTap;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.isRead,
    this.type = 'text',
    this.mediaUrl,
    this.videoId,
    this.videoTitle,
    this.videoThumbnail,
    this.videoChannel,
    this.onVideoTap,
    this.movieId,
    this.movieTitle,
    this.moviePoster,
    this.mediaType,
    this.onRecommendationTap,
    this.onImageTap,
    this.postId,
    this.postContent,
    this.postAuthorName,
    this.postShowTitle,
    this.onPostTap,
  });

  bool get _isVideoLink => type == 'video_link' && videoId != null;
  bool get _isRecommendation => type == 'recommendation' && movieId != null;
  bool get _isImage => type == 'image' && mediaUrl != null;
  bool get _isVideo => type == 'video' && mediaUrl != null;
  bool get _isSharedPost => type == 'shared_post' && postId != null;
  bool get _isGif => type == 'gif' && mediaUrl != null;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('hh:mm a').format(timestamp.toDate());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Video link preview
            if (_isVideoLink)
              VideoLinkPreview(
                videoId: videoId!,
                videoTitle: videoTitle ?? 'Video',
                videoThumbnail: videoThumbnail ?? '',
                videoChannel: videoChannel ?? '',
                isMe: isMe,
                onTap: onVideoTap,
              )
            // Recommendation preview
            else if (_isRecommendation)
              RecommendationPreview(
                movieId: movieId!,
                title: movieTitle ?? 'Recommendation',
                posterPath: moviePoster,
                mediaType: mediaType ?? 'movie',
                isSentByMe: isMe,
                onTap: onRecommendationTap,
              )
            // Image message
            else if (_isImage)
              _buildImageBubble(context)
            // GIF message
            else if (_isGif)
              _buildGifBubble(context)
            // Video message
            else if (_isVideo)
              _buildVideoBubble(context)
            // Shared post preview
            else if (_isSharedPost)
              _buildSharedPostBubble(context)
            // Regular text bubble
            else
              _buildTextBubble(context),
            // Timestamp row (outside bubble for media previews)
            if (_isVideoLink ||
                _isRecommendation ||
                _isImage ||
                _isGif ||
                _isVideo ||
                _isSharedPost)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                child: _buildTimestampRow(time),
              ),
          ],
        ),
      ),
    );
  }

  // ... (Methods for text, image, video bubbles remain, adding GIF bubble below)

  Widget _buildGifBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receivedBgColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white;
    final receivedBorderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);
    final primaryGreen = const Color(0xFF1A8927);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMe ? primaryGreen : receivedBgColor,
        border: isMe
            ? null
            : Border.all(color: receivedBorderColor, width: 0.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isMe && !isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
                maxHeight: 300,
              ),
              child: Hero(
                tag: mediaUrl!,
                child: Image.network(
                  mediaUrl!,
                  fit: BoxFit.contain, // GIFs should show full content usually
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey[800],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.gif,
                            size: 50,
                            color: Colors.white54,
                          ),
                          Text(
                            "GIF Failed",
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // GIFs usually don't have captions in this app, but if they did:
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextBubble(BuildContext context) {
    final time = DateFormat('hh:mm a').format(timestamp.toDate());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium Color Palette
    final primaryGreen = const Color(0xFF1A8927);
    final gradientGreen = const Color(0xFF14691E);

    // Glassmorphism/Soft Backgrounds
    final receivedBgColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white;
    final receivedBorderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);

    final sentTextColor = Colors.white;
    final receivedTextColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          if (isMe)
            BoxShadow(
              color: primaryGreen.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          if (!isMe && !isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [primaryGreen, gradientGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : receivedBgColor,
          border: isMe
              ? null
              : Border.all(color: receivedBorderColor, width: 0.5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe
                ? const Radius.circular(20)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(20),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? sentTextColor : receivedTextColor,
                fontSize: 15.5,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: (isMe ? sentTextColor : receivedTextColor)
                          .withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: isRead ? Colors.white : Colors.white60,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampRow(String time) {
    // This is for media previews which are outside the bubble function
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            isRead ? Icons.done_all : Icons.done,
            size: 16,
            color: isRead ? const Color(0xFF34B7F1) : Colors.grey,
          ),
        ],
      ],
    );
  }

  Widget _buildImageBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receivedBgColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white;
    final receivedBorderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);
    final primaryGreen = const Color(0xFF1A8927);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMe ? primaryGreen : receivedBgColor,
        border: isMe
            ? null
            : Border.all(color: receivedBorderColor, width: 0.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isMe && !isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onImageTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                  maxHeight: 300,
                ),
                child: Hero(
                  tag: mediaUrl!,
                  child: Image.network(
                    mediaUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 50),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receivedBgColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white;
    final receivedBorderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);
    final primaryGreen = const Color(0xFF1A8927);

    // Generate thumbnail URL from Cloudinary video URL
    final thumbnailUrl = mediaUrl!
        .replaceFirst(
          '/video/upload/',
          '/video/upload/so_0,w_400,h_300,c_fill/',
        )
        .replaceFirst(RegExp(r'\.(mp4|mov|avi|webm)$'), '.jpg');

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMe ? primaryGreen : receivedBgColor,
        border: isMe
            ? null
            : Border.all(color: receivedBorderColor, width: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onImageTap, // Reuse for video tap handling
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65,
                      maxHeight: 250,
                    ),
                    child: Hero(
                      tag: mediaUrl!,
                      child: Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 150,
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 150,
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.videocam_off,
                              size: 50,
                              color: Colors.white54,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Play button overlay
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSharedPostBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGreen = const Color(0xFF1A8927);

    return GestureDetector(
      onTap: onPostTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? primaryGreen
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
          border: isMe
              ? null
              : Border.all(color: Colors.grey.withOpacity(0.2), width: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: isMe ? Colors.white70 : primaryGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  'Post in ${postShowTitle ?? 'Community'}',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : themeHintColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              postAuthorName ?? 'Unknown',
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              postContent ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    (isMe
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black))
                        .withOpacity(0.9),
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withOpacity(0.2)
                    : primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Post',
                    style: TextStyle(
                      color: isMe ? Colors.white : primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: isMe ? Colors.white : primaryGreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color themeHintColor(BuildContext context) => Theme.of(context).hintColor;
}
