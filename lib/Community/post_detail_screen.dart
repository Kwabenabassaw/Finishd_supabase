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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Discussion',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPostCard(
                    context,
                    theme,
                    primaryGreen,
                    provider,
                    userVote,
                  ),

                  // Comments header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Row(
                      children: [
                        Text(
                          'Comments',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.hintColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.post.commentCount}',
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Comments stream
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: provider.getCommentsStream(widget.post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final comments = snapshot.data ?? [];

                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 64,
                                  color: theme.hintColor.withOpacity(0.2),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No comments yet',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.hintColor.withOpacity(0.5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
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
                            provider,
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 120),
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.3 : 0.1,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: widget.post.authorAvatar != null
                      ? NetworkImage(widget.post.authorAvatar!)
                      : null,
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  child: widget.post.authorAvatar == null
                      ? Text(
                          widget.post.authorName[0].toUpperCase(),
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.post.timeAgo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.post.isSpoiler)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'SPOILER',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                widget.post.content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ),

            // Hashtags
            if (widget.post.hashtags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: widget.post.hashtags
                      .map(
                        (tag) => Text(
                          '#$tag',
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            // Actions row
            Container(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_circle_up_rounded,
                            size: 26,
                            color: userVote == 1
                                ? primaryGreen
                                : theme.hintColor.withOpacity(0.4),
                          ),
                          onPressed: () => provider.voteOnPost(
                            widget.post.id,
                            widget.showId,
                            1,
                          ),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        Text(
                          '${widget.post.score}',
                          style: TextStyle(
                            color: widget.post.score > 0
                                ? primaryGreen
                                : theme.hintColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.arrow_circle_down_rounded,
                            size: 26,
                            color: userVote == -1
                                ? Colors.red
                                : theme.hintColor.withOpacity(0.4),
                          ),
                          onPressed: () => provider.voteOnPost(
                            widget.post.id,
                            widget.showId,
                            -1,
                          ),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.share_rounded,
                      color: theme.hintColor.withOpacity(0.6),
                      size: 20,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(
    BuildContext context,
    ThemeData theme,
    Color primaryGreen,
    CommunityComment comment,
    CommunityProvider provider,
  ) {
    final isReply = comment.parentId != null;
    final commentBg = theme.brightness == Brightness.dark
        ? theme.cardColor.withOpacity(0.5)
        : Colors.grey[50]!;
    final userVote = provider.getCommentVote(comment.id);

    return Container(
      margin: EdgeInsets.fromLTRB(isReply ? 56 : 16, 4, 16, 12),
      decoration: BoxDecoration(
        color: commentBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.2 : 0.05,
            ),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: comment.authorAvatar != null
                      ? NetworkImage(comment.authorAvatar!)
                      : null,
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  child: comment.authorAvatar == null
                      ? Text(
                          comment.authorName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(comment.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                comment.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  letterSpacing: 0.1,
                ),
              ),
            ),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 20,
                          color: userVote == 1
                              ? primaryGreen
                              : theme.hintColor.withOpacity(0.5),
                        ),
                        onPressed: () => provider.voteOnComment(
                          commentId: comment.id,
                          postId: widget.post.id,
                          showId: widget.showId,
                          vote: 1,
                        ),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                      Text(
                        '${comment.score}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: userVote == 1
                              ? primaryGreen
                              : (userVote == -1 ? Colors.red : null),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: userVote == -1
                              ? Colors.red
                              : theme.hintColor.withOpacity(0.5),
                        ),
                        onPressed: () => provider.voteOnComment(
                          commentId: comment.id,
                          postId: widget.post.id,
                          showId: widget.showId,
                          vote: -1,
                        ),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _replyTo(comment.id, comment.authorName),
                  icon: Icon(
                    Icons.reply_rounded,
                    size: 16,
                    color: primaryGreen,
                  ),
                  label: Text(
                    'Reply',
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingToName != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 18, color: primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Replying to $_replyingToName',
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: theme.hintColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _replyingToId = null;
                          _replyingToName = null;
                        });
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocus,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts...',
                        hintStyle: TextStyle(
                          color: theme.hintColor.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSending ? null : () => _submitComment(provider),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
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
