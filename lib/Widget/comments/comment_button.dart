import 'package:flutter/material.dart';
import 'package:finishd/services/comment_service.dart';
import 'package:finishd/Widget/comments/comment_sheet.dart';

/// TikTok-style comment button
///
/// Features:
/// - Shows comment icon + count
/// - Tap to open comment bottom sheet
/// - Real-time count updates
class CommentButton extends StatefulWidget {
  final String videoId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final double size;
  final Color? color;

  const CommentButton({
    super.key,
    required this.videoId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.size = 26,
    this.color,
  });

  @override
  State<CommentButton> createState() => _CommentButtonState();
}

class _CommentButtonState extends State<CommentButton> {
  final CommentService _commentService = CommentService();
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final count = await _commentService.getCommentCount(widget.videoId);
    if (mounted) {
      setState(() {
        _commentCount = count;
      });
    }
  }

  void _openCommentSheet() async {
    await CommentSheet.show(
      context: context,
      videoId: widget.videoId,
      userId: widget.userId,
      userName: widget.userName,
      userAvatar: widget.userAvatar,
    );

    // Refresh count after closing sheet
    _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openCommentSheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              color: widget.color ?? Colors.white,
              size: widget.size,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCount(_commentCount),
            style: TextStyle(
              color: widget.color ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count == 0) return 'Comment';
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
