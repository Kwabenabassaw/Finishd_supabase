import 'package:flutter/material.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/Community/create_post_screen.dart';
import 'package:finishd/Community/post_detail_screen.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:provider/provider.dart';

/// Detail screen for a specific community showing posts feed
class CommunityDetailScreen extends StatefulWidget {
  final int showId;
  final String showTitle;
  final String? posterPath;
  final String mediaType;

  const CommunityDetailScreen({
    super.key,
    required this.showId,
    required this.showTitle,
    this.posterPath,
    required this.mediaType,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      provider.loadCommunityDetails(widget.showId);
    });
  }

  @override
  void dispose() {
    // Optionally clear data, but maybe keep it cached for back navigation?
    // For now, let's clear it to ensure fresh data next time or handle in provider
    // Provider.of<CommunityProvider>(context, listen: false).clearCurrentCommunity();
    super.dispose();
  }

  void _openCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          showId: widget.showId,
          showTitle: widget.showTitle,
          posterPath: widget.posterPath,
          mediaType: widget.mediaType,
        ),
      ),
    );

    if (result == true) {
      if (mounted) {
        Provider.of<CommunityProvider>(
          context,
          listen: false,
        ).loadCommunityDetails(widget.showId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryGreen = const Color(0xFF1A8927);

    // Watch the provider
    final provider = Provider.of<CommunityProvider>(context);
    final community = provider.currentCommunity;
    final posts = provider.currentPosts;
    final isMember = provider.isMemberOfCurrent;
    final isLoading = provider.isLoadingCommunityDetails;
    final userVotes = provider.currentUserVotes;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header with poster
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search, color: colorScheme.onSurface),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.posterPath != null)
                    Image.network(
                      'https://image.tmdb.org/t/p/w500${widget.posterPath}',
                      fit: BoxFit.cover,
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, colorScheme.surface],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.showTitle,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 16,
                                    color: theme.hintColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${community?.memberCount ?? 0} Watchers',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: primaryGreen,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!isMember)
                          ElevatedButton(
                            onPressed: () => provider.joinCommunity(
                              widget.showId,
                              community,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Join'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () {
                              // Maybe show leave dialog? For now just button
                              // provider.leaveCommunity(widget.showId);
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: primaryGreen),
                            ),
                            child: Text(
                              'Member',
                              style: TextStyle(color: primaryGreen),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sort tabs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSortChip(context, provider, 'Trending', 'upvotes'),
                    _buildSortChip(
                      context,
                      provider,
                      'Most Recent',
                      'createdAt',
                    ),
                    _buildSortChip(context, provider, 'Top', 'commentCount'),
                  ],
                ),
              ),
            ),
          ),

          // Posts or empty state
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (posts.isEmpty)
            SliverFillRemaining(child: _buildEmptyState(context))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildPostCard(
                  context,
                  posts[index],
                  provider,
                  userVotes[posts[index].id] ?? 0,
                  community,
                ),
                childCount: posts.length,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreatePost(),
        backgroundColor: primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSortChip(
    BuildContext context,
    CommunityProvider provider,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final isSelected = provider.currentSortBy == value;
    final primaryGreen = const Color(0xFF1A8927);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          provider.setSortBy(widget.showId, value);
        },
        backgroundColor: theme.cardColor,
        selectedColor: primaryGreen,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(color: theme.dividerColor),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGreen = const Color(0xFF1A8927);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 80, color: theme.hintColor),
          const SizedBox(height: 24),
          Text(
            'No discussions yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Be the first to start a conversation!',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _openCreatePost(),
            icon: const Icon(Icons.add),
            label: const Text('Start Discussion'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    CommunityPost post,
    CommunityProvider provider,
    int userVote,
    Community? community,
  ) {
    final theme = Theme.of(context);
    final primaryGreen = const Color(0xFF1A8927);

    return InkWell(
      onTap: () => _openPostDetail(post),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post.authorAvatar != null
                      ? NetworkImage(post.authorAvatar!)
                      : null,
                  backgroundColor: theme.hintColor.withOpacity(0.3),
                  child: post.authorAvatar == null
                      ? Text(post.authorName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.authorName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (post.authorId == community?.createdBy)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(post.timeAgo, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (post.isSpoiler)
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
                IconButton(
                  icon: Icon(Icons.more_horiz, color: theme.hintColor),
                  onPressed: () {},
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: post.isSpoiler
                  ? _buildSpoilerContent(context, post)
                  : Text(post.content, style: theme.textTheme.bodyLarge),
            ),

            // Media
            if (post.mediaUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(post.mediaUrls.first, fit: BoxFit.cover),
                ),
              ),

            // Hashtags
            if (post.hashtags.isNotEmpty)
              Wrap(
                spacing: 8,
                children: post.hashtags
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
                      provider.voteOnPost(post.id, widget.showId, 1),
                ),
                Text(
                  '${post.score}',
                  style: TextStyle(
                    color: post.score > 0
                        ? primaryGreen
                        : post.score < 0
                        ? Colors.red
                        : theme.hintColor,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    color: userVote == -1 ? Colors.red : theme.hintColor,
                  ),
                  onPressed: () =>
                      provider.voteOnPost(post.id, widget.showId, -1),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.chat_bubble_outline,
                  color: theme.hintColor,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
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
      ),
    );
  }

  Widget _buildSpoilerContent(BuildContext context, CommunityPost post) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {},
      child: Container(
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

  void _openPostDetail(CommunityPost post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(post: post, showId: widget.showId),
      ),
    );
    // Refresh to get updated comments count
    if (mounted) {
      Provider.of<CommunityProvider>(
        context,
        listen: false,
      ).loadCommunityDetails(widget.showId);
    }
  }
}
