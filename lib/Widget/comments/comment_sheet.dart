import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finishd/Model/comment_data.dart';
import 'package:finishd/services/comment_service.dart';
import 'package:finishd/Widget/comments/comment_item.dart';

/// Bottom sheet for viewing and adding comments
///
/// Features:
/// - Real-time comment stream
/// - Text input with send button
/// - Pull to refresh
/// - Empty state
class CommentSheet extends StatefulWidget {
  final String videoId;
  final String userId;
  final String userName;
  final String? userAvatar;

  const CommentSheet({
    super.key,
    required this.videoId,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  /// Show the comment sheet as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required String videoId,
    required String userId,
    required String userName,
    String? userAvatar,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentSheet(
        videoId: videoId,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
      ),
    );
  }

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final CommentService _commentService = CommentService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<CommentData> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _commentService.getComments(
        videoId: widget.videoId,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending || widget.userId.isEmpty) return;

    setState(() => _isSending = true);
    HapticFeedback.lightImpact();

    try {
      final newComment = await _commentService.addComment(
        videoId: widget.videoId,
        userId: widget.userId,
        userName: widget.userName,
        userAvatar: widget.userAvatar,
        text: text,
      );

      if (mounted) {
        setState(() {
          _comments.insert(0, newComment);
          _isSending = false;
        });
        _textController.clear();
        _focusNode.unfocus();
      }
    } catch (e) {
      print('Error sending comment: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to post comment')));
      }
    }
  }

  Future<void> _deleteComment(CommentData comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Comment',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _commentService.deleteComment(
        videoId: widget.videoId,
        commentId: comment.id,
        parentId: comment.parentId,
      );

      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      print('Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete comment')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.7,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_comments.length} Comments',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          // Comments list
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _comments.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadComments,
                    color: Colors.white,
                    backgroundColor: Colors.grey[800],
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return CommentItem(
                          comment: comment,
                          currentUserId: widget.userId,
                          onDelete: () => _deleteComment(comment),
                        );
                      },
                    ),
                  ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 12,
              bottom: 12 + bottomPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // User avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[700],
                    backgroundImage: widget.userAvatar != null
                        ? NetworkImage(widget.userAvatar!)
                        : null,
                    child: widget.userAvatar == null
                        ? Text(
                            widget.userName.isNotEmpty
                                ? widget.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  GestureDetector(
                    onTap: _sendComment,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isSending ? Colors.grey[700] : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => const CommentItemSkeleton(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No comments yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to comment!',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
