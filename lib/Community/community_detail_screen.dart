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
        physics:
            const BouncingScrollPhysics(), // Premium feel for both platforms
        slivers: [
          // Header with poster & Glassmorphism effect
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            leading: CircleAvatar(
              backgroundColor: Colors.black26,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.posterPath != null)
                    Image.network(
                      'https://image.tmdb.org/t/p/w780${widget.posterPath}',
                      fit: BoxFit.cover,
                    ),
                  // Rich Gradient Overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          theme.scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.mediaType.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.showTitle,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${community?.memberCount ?? 0} members',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.hintColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (isMember)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: primaryGreen.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: primaryGreen,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Member',
                                      style: TextStyle(
                                        color: primaryGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: () => provider.joinCommunity(
                                  widget.showId,
                                  community,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                ),
                                child: const Text(
                                  'Join Community',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sort tabs - Modern Pill style
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildSortChip(
                      context,
                      provider,
                      'Trending',
                      'upvotes',
                      Icons.local_fire_department_rounded,
                    ),
                    _buildSortChip(
                      context,
                      provider,
                      'Latest',
                      'createdAt',
                      Icons.schedule_rounded,
                    ),
                    _buildSortChip(
                      context,
                      provider,
                      'Top Rated',
                      'commentCount',
                      Icons.star_rounded,
                    ),
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
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isSelected = provider.currentSortBy == value;
    final primaryGreen = const Color(0xFF1A8927);

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : theme.hintColor,
        ),
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          provider.setSortBy(widget.showId, value);
        },
        backgroundColor: theme.cardColor,
        selectedColor: primaryGreen,
        showCheckmark: false,
        elevation: isSelected ? 4 : 0,
        pressElevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
            color: isSelected
                ? primaryGreen
                : theme.dividerColor.withOpacity(0.05),
          ),
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 13,
        ),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.3 : 0.08,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPostDetail(post),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryGreen.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: post.authorAvatar != null
                            ? NetworkImage(post.authorAvatar!)
                            : null,
                        backgroundColor: primaryGreen.withOpacity(0.1),
                        child: post.authorAvatar == null
                            ? Text(
                                post.authorName[0].toUpperCase(),
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
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
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (post.authorId == community?.createdBy)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'OP',
                                    style: TextStyle(
                                      color: primaryGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            post.timeAgo,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (post.isSpoiler)
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
                    IconButton(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: theme.hintColor.withOpacity(0.5),
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: post.isSpoiler
                      ? _buildSpoilerContent(context, post)
                      : Text(
                          post.content,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),

                // Media
                if (post.mediaUrls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
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
                        child: Image.network(
                          post.mediaUrls.first,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                // Hashtags
                if (post.hashtags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: post.hashtags
                          .map(
                            (tag) => Text(
                              '#$tag',
                              style: TextStyle(
                                color: primaryGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                // Divider
                Divider(
                  color: theme.dividerColor.withOpacity(0.05),
                  height: 32,
                ),

                // Actions row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_circle_up_rounded,
                              size: 24,
                              color: userVote == 1
                                  ? primaryGreen
                                  : theme.hintColor.withOpacity(0.4),
                            ),
                            onPressed: () =>
                                provider.voteOnPost(post.id, widget.showId, 1),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          Text(
                            '${post.score}',
                            style: TextStyle(
                              color: post.score > 0
                                  ? primaryGreen
                                  : post.score < 0
                                  ? Colors.red
                                  : theme.hintColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.arrow_circle_down_rounded,
                              size: 24,
                              color: userVote == -1
                                  ? Colors.red
                                  : theme.hintColor.withOpacity(0.4),
                            ),
                            onPressed: () =>
                                provider.voteOnPost(post.id, widget.showId, -1),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => _openPostDetail(post),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mode_comment_outlined,
                            color: theme.hintColor.withOpacity(0.6),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.commentCount}',
                            style: TextStyle(
                              color: theme.hintColor.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.scaffoldBackgroundColor,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.share_rounded,
                          color: theme.hintColor.withOpacity(0.6),
                          size: 18,
                        ),
                        onPressed: () {},
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
