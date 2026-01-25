import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/Community/create_post_screen.dart';
import 'package:finishd/Community/post_detail_screen.dart';
import 'package:finishd/Widget/report_bottom_sheet.dart';
import 'package:finishd/models/report_model.dart';
import 'package:finishd/Widget/image_preview.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:finishd/Widget/user_avatar.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/Home/share_post_sheet.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Widget/fullscreen_video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finishd/services/social_database_helper.dart';

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
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _revealedSpoilers = {};
  final Set<String> _favoritePosts = {};
  bool _isCommunityFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadFavoritePosts();
    _loadFavoriteCommunityStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      provider.loadCommunityDetails(widget.showId);
      provider.setSearchQuery(''); // Reset search on entry

      // Ensure UserProvider is loaded for follow functionality
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (provider.currentUid != null && userProvider.currentUser == null) {
        userProvider.fetchCurrentUser(provider.currentUid!);
      }
    });
  }

  Future<void> _loadFavoritePosts() async {
    final dbHelper = SocialDatabaseHelper();
    final favorites = await dbHelper.getFavoritePostIdsForShow(widget.showId);
    if (mounted) {
      setState(() {
        _favoritePosts.clear();
        _favoritePosts.addAll(favorites);
      });
    }
  }

  Future<void> _loadFavoriteCommunityStatus() async {
    final dbHelper = SocialDatabaseHelper();
    final isFav = await dbHelper.isFavoriteCommunity(widget.showId);
    if (mounted) {
      setState(() {
        _isCommunityFavorited = isFav;
      });
    }
  }

  @override
  void dispose() {
    // Optionally clear data, but maybe keep it cached for back navigation?
    // For now, let's clear it to ensure fresh data next time or handle in provider
    // Provider.of<CommunityProvider>(context, listen: false).clearCurrentCommunity();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        Provider.of<CommunityProvider>(
          context,
          listen: false,
        ).setSearchQuery('');
      }
    });
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
    final posts = provider.filteredPosts;
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
            title: _isSearching
                ? Hero(
                    tag: 'community_search',
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Search community...',
                          hintStyle: TextStyle(
                            color: theme.hintColor.withOpacity(0.5),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: theme.hintColor,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) => provider.setSearchQuery(value),
                      ),
                    ),
                  )
                : null,
            leading: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: IconButton(
                icon: const Icon(
                  FontAwesomeIcons.arrowLeft,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {
                  if (_isSearching) {
                    _toggleSearch();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            actions: [
              if (!_isSearching)
                CircleAvatar(
                  backgroundColor: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _toggleSearch,
                  ),
                ),
              const SizedBox(width: 8),
              if (!_isSearching)
                CircleAvatar(
                  backgroundColor: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => _showCommunityOptions(context, provider),
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
                      Icons.insights_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Trending Hashtags
          SliverToBoxAdapter(child: _buildTrendingHashtags(context, provider)),

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
    final provider = Provider.of<CommunityProvider>(context, listen: false);
    final isSearching = _searchController.text.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.forum_outlined,
            size: 80,
            color: theme.hintColor.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            isSearching ? 'No results found' : 'No discussions yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSearching
                ? 'Try searching for something else'
                : 'Be the first to start a conversation!',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 32),
          if (!isSearching)
            ElevatedButton.icon(
              onPressed: () => _openCreatePost(),
              icon: const Icon(Icons.add),
              label: const Text('Start Discussion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            )
          else
            TextButton(
              onPressed: () {
                _searchController.clear();
                provider.setSearchQuery('');
              },
              child: const Text('Clear Search'),
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
                      child: UserAvatar(
                        radius: 22,
                        profileImageUrl: post.authorAvatar,
                        username: post.authorName,
                        userId: post.authorId,
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
                      onPressed: () =>
                          _showPostOptions(context, post, provider),
                    ),
                  ],
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: post.isSpoiler && !_revealedSpoilers.contains(post.id)
                      ? _buildSpoilerContent(context, post, () {
                          setState(() {
                            _revealedSpoilers.add(post.id);
                          });
                        })
                      : Text(
                          post.content,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),

                // Media
                if (post.mediaUrls.isNotEmpty &&
                    (!post.isSpoiler || _revealedSpoilers.contains(post.id)))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildMediaGallery(context, post),
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
                            (tag) => InkWell(
                              onTap: () => provider.setHashtagFilter(tag),
                              borderRadius: BorderRadius.circular(4),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
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
                              FontAwesomeIcons.thumbsUp,
                              color: userVote == 1
                                  ? primaryGreen
                                  : theme.hintColor.withOpacity(0.4),
                              size: 24,
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
                              FontAwesomeIcons.thumbsDown,
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
                          const SizedBox(width: 6),
                          Transform.flip(
                            flipX: true,
                            child: Icon(
                              LucideIcons.messageCircle,
                              color: theme.hintColor.withOpacity(0.6),
                              size: 20,
                            ),
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
                    // Share button
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
                        onPressed: () => SharePostSheet.show(context, post),
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

  void _navigateToDetails() {
    if (widget.mediaType == 'movie') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailsScreen(
            movie: MovieDetails.shallowFromListItem(
              MovieListItem(
                id: widget.showId.toString(),
                title: widget.showTitle,
                posterPath: widget.posterPath,
                mediaType: 'movie',
                addedAt: DateTime.now(),
              ),
            ),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShowDetailsScreen(
            movie: TvShowDetails.shallowFromListItem(
              MovieListItem(
                id: widget.showId.toString(),
                title: widget.showTitle,
                posterPath: widget.posterPath,
                mediaType: 'tv',
                addedAt: DateTime.now(),
              ),
            ),
          ),
        ),
      );
    }
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
    // Basic Cloudinary thumbnail transformation
    return videoUrl
        .replaceFirst(
          '/video/upload/',
          '/video/upload/so_0,w_800,h_600,c_fill/',
        )
        .replaceFirst(RegExp(r'\.(mp4|mov|avi|webm)$'), '.jpg');
  }

  void _showPostOptions(
    BuildContext context,
    CommunityPost post,
    CommunityProvider provider,
  ) {
    final theme = Theme.of(context);
    final isAuthor = post.authorId == provider.currentUid;

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
                  _confirmDelete(context, post, provider);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred_rounded),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ReportBottomSheet(
                      type: ReportType.communityPost,
                      contentId: post.id,
                      reportedUserId: post.authorId,
                      communityId: widget.showId.toString(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share Post'),
              onTap: () {
                Navigator.pop(context);
                SharePostSheet.show(context, post);
              },
            ),
            ListTile(
              leading: Icon(
                _favoritePosts.contains(post.id)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _favoritePosts.contains(post.id) ? Colors.red : null,
              ),
              title: Text(
                _favoritePosts.contains(post.id)
                    ? 'Remove from Favorites'
                    : 'Add to Fav',
              ),
              onTap: () async {
                Navigator.pop(context);
                final dbHelper = SocialDatabaseHelper();
                final isFav = _favoritePosts.contains(post.id);

                if (isFav) {
                  await dbHelper.removeFavoritePost(post.id);
                  setState(() => _favoritePosts.remove(post.id));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Removed from favorites'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  await dbHelper.addFavoritePost(post.id, widget.showId);
                  setState(() => _favoritePosts.add(post.id));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to favorites'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            if (!isAuthor)
              Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  final isFollowing = userProvider.isFollowing(post.authorId);

                  return ListTile(
                    leading: Icon(
                      isFollowing
                          ? Icons.person_remove_rounded
                          : Icons.person_add_rounded,
                    ),
                    title: Text(isFollowing ? 'Unfollow' : 'Follow'),
                    subtitle: Text(
                      isFollowing
                          ? 'Stop following ${post.authorName}'
                          : 'Follow ${post.authorName}',
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        if (isFollowing) {
                          await userProvider.unfollowUser(post.authorId);
                        } else {
                          await userProvider.followUser(post.authorId);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFollowing
                                    ? 'Unfollowed ${post.authorName}'
                                    : 'Following ${post.authorName}',
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

  void _confirmDelete(
    BuildContext context,
    CommunityPost post,
    CommunityProvider provider,
  ) {
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
              final result = await provider.deletePost(post.id, widget.showId);
              if (result && mounted) {
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

  void _showCommunityOptions(BuildContext context, CommunityProvider provider) {
    if (Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS) {
      _showCupertinoCommunityMenu(context, provider);
    } else {
      _showMaterialCommunityMenu(context, provider);
    }
  }

  void _showMaterialCommunityMenu(
    BuildContext context,
    CommunityProvider provider,
  ) {
    final theme = Theme.of(context);
    final community = provider.currentCommunity;
    if (community == null) return;

    final isCreator = community.createdBy == provider.currentUid;
    final isMember = provider.isMemberOfCurrent;

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
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Info'),
              subtitle: Text(
                'View ${widget.mediaType == 'movie' ? 'movie' : 'TV show'} details',
              ),
              onTap: () {
                Navigator.pop(context);
                _navigateToDetails();
              },
            ),
            ListTile(
              leading: Icon(
                _isCommunityFavorited
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _isCommunityFavorited ? Colors.red : null,
              ),
              title: Text(
                _isCommunityFavorited
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
              ),
              onTap: () async {
                Navigator.pop(context);
                final dbHelper = SocialDatabaseHelper();
                if (_isCommunityFavorited) {
                  await dbHelper.removeFavoriteCommunity(widget.showId);
                  setState(() => _isCommunityFavorited = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Removed from favorites'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  await dbHelper.addFavoriteCommunity(
                    widget.showId,
                    widget.showTitle,
                  );
                  setState(() => _isCommunityFavorited = true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to favorites'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            if (isMember)
              ListTile(
                leading: const Icon(Icons.exit_to_app_rounded),
                title: const Text('Leave Community'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLeave(context, provider);
                },
              ),
            if (isCreator)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete Community',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteCommunity(context, provider);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCupertinoCommunityMenu(
    BuildContext context,
    CommunityProvider provider,
  ) {
    final community = provider.currentCommunity;
    if (community == null) return;

    final isCreator = community.createdBy == provider.currentUid;
    final isMember = provider.isMemberOfCurrent;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(community.title),
        message: const Text('Community Options'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToDetails();
            },
            child: const Text('Info'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final dbHelper = SocialDatabaseHelper();
              if (_isCommunityFavorited) {
                await dbHelper.removeFavoriteCommunity(widget.showId);
                setState(() => _isCommunityFavorited = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Removed from favorites'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                await dbHelper.addFavoriteCommunity(
                  widget.showId,
                  widget.showTitle,
                );
                setState(() => _isCommunityFavorited = true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to favorites'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text(
              _isCommunityFavorited
                  ? 'Remove from Favorites'
                  : 'Add to Favorites',
            ),
          ),
          if (isMember)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _confirmLeave(context, provider);
              },
              child: const Text('Leave Community'),
            ),
          if (isCreator)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteCommunity(context, provider);
              },
              child: const Text('Delete Community'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _confirmLeave(BuildContext context, CommunityProvider provider) {
    final theme = Theme.of(context);
    final community = provider.currentCommunity;
    if (community == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Community?'),
        content: Text('Are you sure you want to leave ${community.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.hintColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.leaveCommunity(community.showId);
              if (mounted) {
                Navigator.pop(
                  context,
                ); // Go back to discover or previous screen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Left ${community.title}')),
                );
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCommunity(
    BuildContext context,
    CommunityProvider provider,
  ) {
    final theme = Theme.of(context);
    final community = provider.currentCommunity;
    if (community == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Community?'),
        content: const Text(
          'This will permanently delete this community and all its data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.hintColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await provider.deleteCommunity(community.showId);
              if (result && mounted) {
                Navigator.pop(context); // Go back
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Community deleted')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete community')),
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

  Widget _buildTrendingHashtags(
    BuildContext context,
    CommunityProvider provider,
  ) {
    final trending = provider.trendingHashtags;
    if (trending.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final primaryGreen = const Color(0xFF1A8927);
    final selectedTag = provider.selectedHashtag;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Topics',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.hintColor.withOpacity(0.8),
                ),
              ),
              if (selectedTag != null)
                TextButton(
                  onPressed: () => provider.setHashtagFilter(null),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Clear Filter',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: trending.map((tag) {
                final isSelected = selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('#$tag'),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.setHashtagFilter(selected ? tag : null);
                    },
                    backgroundColor: theme.cardColor,
                    selectedColor: primaryGreen.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: isSelected ? primaryGreen : theme.hintColor,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? primaryGreen
                            : theme.dividerColor.withOpacity(0.05),
                      ),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
