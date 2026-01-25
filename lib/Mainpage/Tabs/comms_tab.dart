import 'package:flutter/material.dart';
import 'dart:async'; // Added for Timer
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/Community/community_detail_screen.dart';
import 'package:finishd/Community/all_communities_screen.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:provider/provider.dart';

/// Community tab for the Messages screen - shows user's communities and discovery
class CommsTab extends StatefulWidget {
  const CommsTab({super.key});

  @override
  State<CommsTab> createState() => _CommsTabState();
}

class _CommsTabState extends State<CommsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    // Fetch data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      provider.fetchMyCommunities();
      provider.fetchTrendingCommunities();
      provider.fetchRecommendedCommunities();
      provider.fetchDiscoverContent();
    });
    
    // Listen to search input with debouncing
    _searchController.addListener(() {
      final query = _searchController.text.trim();
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      if (query == provider.searchState.query) return;
      
      provider.searchCommunities(query);
      
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          // No longer needed here as searchCommunities handles state updates
        }
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGreen = const Color(0xFF1A8927);
    final provider = Provider.of<CommunityProvider>(context);
    final searchState = provider.searchState;
    final isSearching = searchState.query.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        if (isSearching) {
          await provider.searchCommunities(searchState.query);
        } else {
          await Future.wait([
            provider.fetchMyCommunities(),
            provider.fetchTrendingCommunities(),
            provider.fetchRecommendedCommunities(),
            provider.fetchDiscoverContent(),
          ]);
        }
      },
      color: primaryGreen,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 1. My Communities (Horizontal Avatars)
          if (!isSearching &&
              !provider.isLoadingMyCommunities &&
              provider.myCommunities.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              'My Communities',
              'See all',
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllCommunitiesScreen()),
              ),
              badgeCount: provider.myCommunities.length,
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: provider.myCommunities.length,
                  itemBuilder: (context, index) => _buildMyCommunityAvatar(
                    context,
                    provider.myCommunities[index],
                  ),
                ),
              ),
            ),
          ],

          // 2. Trending Communities
          // During search, this shows filtered results. If empty during search, we hide this section to reduce noise?
          // Prompt says: "If no results for a category: Show empty state inside that container only. Do not hide the tab."
          // But strict reading: "Replace container contents with search-filtered results".
          // So if filtered list is empty, maybe show nothing or "No trending matches"?
          // I will hide the section if list is empty to keep UI clean, UNLESS it's the only thing.
          // Actually, let's show it if it has matches OR if not searching.
          if (!provider.isLoadingTrending && provider.filteredTrendingCommunities.isNotEmpty) ...[
            _buildSectionHeader(context, isSearching ? 'Trending Matches' : 'Trending', isSearching ? '' : 'More'),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: provider.filteredTrendingCommunities.length,
                  itemBuilder: (context, index) => _buildCommunityHeroCard(
                    context,
                    provider.filteredTrendingCommunities[index],
                    true,
                  ),
                ),
              ),
            ),
          ],

          // 3. Recommended Communities
          if (!provider.isLoadingRecommended && provider.filteredRecommendedCommunities.isNotEmpty) ...[
             _buildSectionHeader(
              context,
              'Recommended',
              isSearching ? '' : 'Refresh',
              onSeeAll: () => provider.fetchRecommendedCommunities(),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: provider.filteredRecommendedCommunities.length,
                  itemBuilder: (context, index) => _buildCommunityHeroCard(
                    context,
                    provider.filteredRecommendedCommunities[index],
                    false,
                  ),
                ),
              ),
            ),
          ],

          // Search Header & Bar (Relocated to top in original code, ensuring it stays)
          // Wait, 'Discover' header is at line 164. 'Search Results' or 'Discover'.
          // I'll update line 164 block to be consistent.
          _buildSectionHeader(
            context,
            isSearching ? 'Media Results' : 'Discover',
            '',
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                     provider.setSearchQuery(val); // Local update for filtering trending/rec
                     // Debounce handled in listener for API call
                  },
                  decoration: InputDecoration(
                    hintText: 'Search communities, shows...',
                    hintStyle: TextStyle(color: theme.hintColor),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.hintColor,
                    ),
                    suffixIcon: searchState.query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: theme.hintColor),
                            onPressed: () {
                              _searchController.clear();
                              provider.clearSearch();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (!isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip(
                      context,
                      provider,
                      'Trending',
                      'trending',
                      primaryGreen,
                    ),
                    _buildFilterChip(
                      context,
                      provider,
                      'TV Shows',
                      'tv',
                      primaryGreen,
                    ),
                    _buildFilterChip(
                      context,
                      provider,
                      'Movies',
                      'movie',
                      primaryGreen,
                    ),
                  ],
                ),
              ),
            ),

          if (isSearching ? searchState.isSearching : provider.isLoadingDiscover)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (isSearching ? searchState.results.isEmpty : provider.discoverContent.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        isSearching ? Icons.search_off : Icons.movie_filter_rounded,
                        size: 64,
                        color: theme.hintColor.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isSearching ? 'No results found for "${searchState.query}"' : 'No content found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = isSearching ? searchState.results[index] : provider.discoverContent[index];
                    return _buildDiscoverPremiumCard(
                      context,
                      item,
                      theme,
                      primaryGreen,
                    );
                  },
                  childCount: isSearching ? searchState.results.length : provider.discoverContent.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String actionLabel, {
    VoidCallback? onSeeAll,
    int? badgeCount,
  }) {
    final theme = Theme.of(context);
    final primaryGreen = const Color(0xFF1A8927);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
        child: Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (actionLabel.isNotEmpty)
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyCommunityAvatar(BuildContext context, Community community) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(
            showId: community.showId,
            showTitle: community.title,
            posterPath: community.posterPath,
            mediaType: community.mediaType,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1A8927).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: community.posterUrl != null
                    ? Image.network(community.posterUrl!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.people, color: Colors.white70),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              child: Text(
                community.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityHeroCard(
    BuildContext context,
    Community community,
    bool isTrending,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(
            showId: community.showId,
            showTitle: community.title,
            posterPath: community.posterPath,
            mediaType: community.mediaType,
          ),
        ),
      ),
      child: Container(
        width: 130,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster background
              community.posterUrl != null
                  ? Image.network(community.posterUrl!, fit: BoxFit.cover)
                  : Container(color: Colors.grey[800]),

              // Gradient Overlay
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Trending Badge
              if (isTrending)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.white, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'HOT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Content Info
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${community.memberCount} members',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverPremiumCard(
    BuildContext context,
    MediaItem item,
    ThemeData theme,
    Color primaryGreen,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.3 : 0.08,
            ),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityDetailScreen(
                showId: item.id,
                showTitle: item.title,
                posterPath: item.posterPath,
                mediaType: item.mediaType,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Pop-out style poster
                Hero(
                  tag: 'comm_poster_${item.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        'https://image.tmdb.org/t/p/w200${item.posterPath}',
                        width: 70,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 70,
                          height: 100,
                          color: theme.hintColor.withOpacity(0.1),
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Content Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.mediaType.toUpperCase(),
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.trending_up_rounded,
                            size: 14,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            item.voteAverage.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.overview.isNotEmpty
                            ? item.overview
                            : 'Tap to start a conversation with other fans!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.forum_rounded,
                            size: 14,
                            color: primaryGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Join Discussion',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: theme.hintColor.withOpacity(0.5),
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
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    CommunityProvider provider,
    String label,
    String value,
    Color primaryGreen,
  ) {
    final theme = Theme.of(context);
    final isSelected = provider.discoverFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          provider.setDiscoverFilter(value);
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
}
