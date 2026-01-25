import 'package:flutter/material.dart';
import 'package:finishd/services/comment_service.dart';
import 'package:finishd/Widget/comments/comment_sheet.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    this.size = 18,
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
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159), // Flip horizontally
            child: FaIcon(
              FontAwesomeIcons.solidCommentDots,
              color: widget.color ?? Colors.white,
              size: widget.size + 4,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCount(_commentCount),
            style: TextStyle(
              color: widget.color ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
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
