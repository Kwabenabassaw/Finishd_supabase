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

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.isRead,
    this.type = 'text',
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
  });

  bool get _isVideoLink => type == 'video_link' && videoId != null;
  bool get _isRecommendation => type == 'recommendation' && movieId != null;

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
            // Regular text bubble
            else
              _buildTextBubble(context),
            // Timestamp row (outside bubble for media previews)
            if (_isVideoLink || _isRecommendation)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                child: _buildTimestampRow(time),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBubble(BuildContext context) {
    final time = DateFormat('hh:mm a').format(timestamp.toDate());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors based on design/theme
    // Sent: Bright Green
    // Received: Dark Grey (in dark mode) or Light Grey (in light mode)
    final sentColor = const Color(0xFF00C853); // Vibrant Green
    final receivedColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey[200];

    final sentTextColor = Colors.white;
    final receivedTextColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: isMe ? sentColor : receivedColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: isMe
              ? const Radius.circular(18)
              : const Radius.circular(4),
          bottomRight: isMe
              ? const Radius.circular(4)
              : const Radius.circular(18),
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
              fontSize: 16,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          // Time layout integrated or below? Design usually puts it inside or nicely outside.
          // Keeping it inside for now but aligned end.
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: (isMe ? sentTextColor : receivedTextColor)
                        .withOpacity(0.7),
                    fontSize: 10,
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
}
