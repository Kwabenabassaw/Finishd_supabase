import 'package:flutter/material.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:provider/provider.dart';

/// Screen showing a single post with its comments
class PostDetailScreen extends StatefulWidget {
  final CommunityPost post;
  final int showId;

  const PostDetailScreen({super.key, required this.post, required this.showId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  bool _isSending = false;
  String? _replyingToId;
  String? _replyingToName;

  // Local vote state for immediate feedback if not fully relying on parent provider list
  // However, we should try to use the provider's source of truth

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _submitComment(CommunityProvider provider) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await provider.addComment(
        postId: widget.post.id,
        showId: widget.showId,
        content: content,
        parentId: _replyingToId,
      );

      _commentController.clear();
      _replyingToId = null;
      _replyingToName = null;
      _commentFocus.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _replyTo(String commentId, String authorName) {
    setState(() {
      _replyingToId = commentId;
      _replyingToName = authorName;
    });
    _commentFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGreen = const Color(0xFF1A8927);
    final provider = Provider.of<CommunityProvider>(
      context,
    ); // Listen to changes

    // Get current vote from provider
    final userVote = provider.currentUserVotes[widget.post.id] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Post'), elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPostCard(
                    context,
                    theme,
                    primaryGreen,
                    provider,
                    userVote,
                  ),
                  const Divider(height: 1),

                  // Comments header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          'Comments',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${widget.post.commentCount})',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Comments stream - Provider just exposes the stream
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: provider.getCommentsStream(widget.post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final comments = snapshot.data ?? [];

                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: theme.hintColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No comments yet',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to comment!',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = CommunityComment.fromJson(
                            comments[index],
                          );
                          return _buildCommentTile(
                            context,
                            theme,
                            primaryGreen,
                            comment,
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          _buildCommentInput(context, theme, primaryGreen, provider),
        ],
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    ThemeData theme,
    Color primaryGreen,
    CommunityProvider provider,
    int userVote,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.post.authorAvatar != null
                    ? NetworkImage(widget.post.authorAvatar!)
                    : null,
                backgroundColor: theme.hintColor.withOpacity(0.3),
                child: widget.post.authorAvatar == null
                    ? Text(widget.post.authorName[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.authorName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(widget.post.timeAgo, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (widget.post.isSpoiler)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SPOILER',
                    style: TextStyle(color: Colors.red, fontSize: 10),
                  ),
                ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(widget.post.content, style: theme.textTheme.bodyLarge),
          ),

          // Hashtags
          if (widget.post.hashtags.isNotEmpty)
            Wrap(
              spacing: 8,
              children: widget.post.hashtags
                  .map(
                    (tag) =>
                        Text('#$tag', style: TextStyle(color: primaryGreen)),
                  )
                  .toList(),
            ),

          const SizedBox(height: 12),

          // Actions row
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_upward,
                  color: userVote == 1 ? primaryGreen : theme.hintColor,
                ),
                onPressed: () =>
                    provider.voteOnPost(widget.post.id, widget.showId, 1),
              ),
              Text(
                '${widget.post.score}', // Same caveat: score might not update instantly without stronger reactive models
                style: TextStyle(
                  color: widget.post.score > 0 ? primaryGreen : theme.hintColor,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_downward,
                  color: userVote == -1 ? Colors.red : theme.hintColor,
                ),
                onPressed: () =>
                    provider.voteOnPost(widget.post.id, widget.showId, -1),
              ),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline, color: theme.hintColor, size: 20),
              const SizedBox(width: 4),
              Text(
                '${widget.post.commentCount}',
                style: TextStyle(color: theme.hintColor),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.share_outlined, color: theme.hintColor),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(
    BuildContext context,
    ThemeData theme,
    Color primaryGreen,
    CommunityComment comment,
  ) {
    final isReply = comment.parentId != null;

    return Container(
      margin: EdgeInsets.only(left: isReply ? 40 : 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: comment.authorAvatar != null
                    ? NetworkImage(comment.authorAvatar!)
                    : null,
                backgroundColor: theme.hintColor.withOpacity(0.3),
                child: comment.authorAvatar == null
                    ? Text(
                        comment.authorName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                comment.authorName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimeAgo(comment.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(comment.content, style: theme.textTheme.bodyMedium),
          ),

          Row(
            children: [
              InkWell(
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        size: 16,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.score}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color: theme.hintColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => _replyTo(comment.id, comment.authorName),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: TextStyle(color: primaryGreen, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(
    BuildContext context,
    ThemeData theme,
    Color primaryGreen,
    CommunityProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingToName != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Replying to $_replyingToName',
                      style: TextStyle(color: primaryGreen, fontSize: 12),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingToId = null;
                          _replyingToName = null;
                        });
                      },
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocus,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.hintColor.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send, color: primaryGreen),
                  onPressed: _isSending ? null : () => _submitComment(provider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }
}
