import 'package:flutter/material.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/Widget/user_avatar.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/Widget/report_bottom_sheet.dart';
import 'package:finishd/models/report_model.dart';
import 'package:finishd/Widget/image_preview.dart';
import 'package:finishd/Home/share_post_sheet.dart';
import 'package:finishd/Widget/fullscreen_video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  bool _isSpoilerRevealed = false;
  String? _replyingToId;
  String? _replyingToName;

  // Track which comment IDs have already been loaded to prevent infinite loop
  final Set<String> _loadedCommentVoteIds = {};

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

    // Get the current post from provider (updated with live score) or fallback to widget.post
    final currentPost = provider.currentPosts.firstWhere(
      (p) => p.id == widget.post.id,
      orElse: () => widget.post,
    );

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
            onPressed: () => _showPostOptions(context, provider),
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
                    currentPost,
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

                      // Load comment votes only for NEW comments (prevent infinite loop)
                      if (comments.isNotEmpty) {
                        final commentIds = comments
                            .map((c) => c['id'] as String)
                            .toList();
                        // Only load votes for IDs we haven't loaded yet
                        final newIds = commentIds
                            .where((id) => !_loadedCommentVoteIds.contains(id))
                            .toList();
                        if (newIds.isNotEmpty) {
                          _loadedCommentVoteIds.addAll(newIds);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            provider.loadCommentVotes(newIds);
                          });
                        }
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
    CommunityPost currentPost,
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
            blurRadius: 10,
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
                UserAvatar(
                  radius: 22,
                  profileImageUrl: widget.post.authorAvatar?.toString(),
                  username: widget.post.authorName,
                  userId: widget.post.authorId,
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
              child: widget.post.isSpoiler && !_isSpoilerRevealed
                  ? _buildSpoilerContent(context, widget.post, () {
                      setState(() {
                        _isSpoilerRevealed = true;
                      });
                    })
                  : Text(
                      widget.post.content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),

            // Media
            if (widget.post.mediaUrls.isNotEmpty &&
                (!widget.post.isSpoiler || _isSpoilerRevealed))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildMediaGallery(context, widget.post),
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
                            FontAwesomeIcons.thumbsUp,
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
                          '${currentPost.score}',
                          style: TextStyle(
                            color: currentPost.score > 0
                                ? primaryGreen
                                : currentPost.score < 0
                                ? Colors.red
                                : theme.hintColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            FontAwesomeIcons.thumbsDown,
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
                      FontAwesomeIcons.share,
                      color: theme.hintColor.withOpacity(0.6),
                      size: 20,
                    ),
                    onPressed: () => SharePostSheet.show(context, currentPost),
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
      decoration: BoxDecoration(color: commentBg),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  radius: 16,
                  profileImageUrl: comment.authorAvatar,
                  username: comment.authorName,
                  userId: comment.authorId,
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
                          FontAwesomeIcons.thumbsUp,
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
                          FontAwesomeIcons.thumbsDown,
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
                if (comment.authorId != provider.currentUid) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: theme.hintColor.withOpacity(0.5),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ReportBottomSheet(
                          type: ReportType.communityComment,
                          contentId: comment.id,
                          reportedUserId: comment.authorId,
                          communityId: widget.showId.toString(),
                          parentContentId: widget.post.id,
                        ),
                      );
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                    tooltip: 'Report Comment',
                  ),
                ],
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
                        FontAwesomeIcons.x,
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
                const SizedBox(width: 8),
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
                            FontAwesomeIcons.arrowRight,
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

  Widget _buildMediaGallery(BuildContext context, CommunityPost post) {
    if (post.mediaUrls.length == 1) {
      return SizedBox(
        height: 220,
        width: double.infinity,
        child: _buildSingleMedia(
          context,
          post.mediaUrls[0],
          post.mediaTypes[0],
          caption: post.content,
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: post.mediaUrls.length,
        itemBuilder: (context, index) {
          return Container(
            width: MediaQuery.of(context).size.width * 0.7,
            margin: const EdgeInsets.only(right: 12),
            child: _buildSingleMedia(
              context,
              post.mediaUrls[index],
              post.mediaTypes[index],
              caption: post.content,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleMedia(
    BuildContext context,
    String url,
    String type, {
    String? caption,
  }) {
    final isVideo = type == 'video';
    final displayUrl = isVideo ? _getVideoThumbnail(url) : url;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: isVideo
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullscreenVideoPlayer(
                            videoUrl: url,
                            caption: caption,
                          ),
                        ),
                      );
                    }
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullscreenImagePreview(
                            imageUrl: url,
                            heroTag: url,
                            caption: caption,
                          ),
                        ),
                      );
                    },
              child: Hero(
                tag: url,
                child: Image.network(
                  displayUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
            if (isVideo)
              IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getVideoThumbnail(String videoUrl) {
    return videoUrl
        .replaceFirst(
          '/video/upload/',
          '/video/upload/so_0,w_800,h_600,c_fill/',
        )
        .replaceFirst(RegExp(r'\.(mp4|mov|avi|webm)$'), '.jpg');
  }

  Widget _buildSpoilerContent(
    BuildContext context,
    CommunityPost post,
    VoidCallback onReveal,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onReveal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.hintColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.visibility_off, color: theme.hintColor, size: 32),
            const SizedBox(height: 8),
            Text(
              'TAP TO REVEAL SPOILER',
              style: TextStyle(
                color: theme.hintColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostOptions(BuildContext context, CommunityProvider provider) {
    final theme = Theme.of(context);
    final isAuthor = widget.post.authorId == provider.currentUid;

    // Ensure following list is loaded for accurate Follow/Unfollow status
    if (provider.currentUid != null) {
      Provider.of<UserProvider>(
        context,
        listen: false,
      ).ensureFollowingLoaded(provider.currentUid!);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isAuthor)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'This action cannot be undone',
                  style: TextStyle(
                    color: theme.hintColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _confirmDelete(context, provider);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred_rounded),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share Post'),
              onTap: () {
                Navigator.pop(context);
                SharePostSheet.show(context, widget.post);
              },
            ),
            if (widget.post.authorId != provider.currentUid)
              Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  final isFollowing = userProvider.isFollowing(
                    widget.post.authorId,
                  );

                  return ListTile(
                    leading: Icon(
                      isFollowing
                          ? Icons.person_remove_rounded
                          : Icons.person_add_rounded,
                    ),
                    title: Text(isFollowing ? 'Unfollow' : 'Follow'),
                    subtitle: Text(
                      isFollowing
                          ? 'Stop following ${widget.post.authorName}'
                          : 'Follow ${widget.post.authorName}',
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        if (isFollowing) {
                          await userProvider.unfollowUser(widget.post.authorId);
                        } else {
                          await userProvider.followUser(widget.post.authorId);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFollowing
                                    ? 'Unfollowed ${widget.post.authorName}'
                                    : 'Following ${widget.post.authorName}',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to update follow status'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CommunityProvider provider) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.hintColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final result = await provider.deletePost(
                widget.post.id,
                widget.showId,
              );
              if (result && mounted) {
                Navigator.pop(context); // Go back to community feed
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Post deleted')));
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete post')),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
