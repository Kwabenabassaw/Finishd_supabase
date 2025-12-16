import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    // Fetch data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CommunityProvider>(context, listen: false);
      provider.fetchMyCommunities();
      provider.fetchDiscoverContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGreen = const Color(0xFF1A8927);
    final provider = Provider.of<CommunityProvider>(context);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          provider.fetchMyCommunities(),
          provider.fetchDiscoverContent(),
        ]);
      },
      color: primaryGreen,
      child: CustomScrollView(
        slivers: [
          // Search bar
          SliverToBoxAdapter(
          
                child: Row(
                  children: [

                 
                    Expanded(
                      
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search shows and movies...',
                            hintStyle: TextStyle(color: theme.hintColor),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                
              
            ),
          ),

          // My Communities section (vertical cards with recent posts)
          if (!provider.isLoadingMyCommunities &&
              provider.myCommunities.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'My Communities',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${provider.myCommunities.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllCommunitiesScreen(),
                        ),
                      ),
                      child: Text(
                        'View all',
                        style: TextStyle(color: primaryGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Vertical list of community cards (limited to 3 for preview)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildCommunityCard(
                  context,
                  provider.myCommunities[index],
                  theme,
                  primaryGreen,
                ),
                childCount: provider.myCommunities.take(3).length,
              ),
            ),
          ],

          // Discover section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Discover',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Start a new discussion',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          // Filter chips for discover
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Loading / Empty / Discover list
          if (provider.isLoadingDiscover)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.discoverContent.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No trending content found',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildDiscoverCard(
                  context,
                  provider.discoverContent[index],
                  theme,
                  primaryGreen,
                ),
                childCount: provider.discoverContent.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
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

  Widget _buildCommunityCard(
    BuildContext context,
    Community community,
    ThemeData theme,
    Color primaryGreen,
  ) {
    // Calculate time ago for recent post if available
    String timeAgo = '';
    if (community.recentPostTime != null) {
      final diff = DateTime.now().difference(community.recentPostTime!);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CommunityDetailScreen(
            showId: community.showId,
            showTitle: community.title,
            posterPath: community.posterPath,
            mediaType: community.mediaType,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Poster + Title + Members
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster with shadow
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: community.posterUrl != null
                        ? Image.network(
                            community.posterUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 50,
                              height: 70,
                              color: theme.hintColor.withOpacity(0.2),
                              child: Icon(Icons.movie, color: theme.hintColor),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 70,
                            color: theme.hintColor.withOpacity(0.2),
                            child: Icon(Icons.movie, color: theme.hintColor),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title and Members
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      
                      Row(
                        children: [
                          // Green dot
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${community.memberCount} members',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                          if (timeAgo.isNotEmpty) ...[
                            Text(
                              ' • $timeAgo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor.withOpacity(0.7),
                              ),
                            ),

                            
                          ],
                        ],
                      ),

                      
            // Recent Post Section
            if (community.recentPostContent != null &&
                community.recentPostContent!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
               
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    children: [
                      TextSpan(
                        text: '@${community.recentPostAuthor ?? 'User'}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: community.recentPostContent),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Join the discussion...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
                    ],
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverCard(
    BuildContext context,
    MediaItem item,
    ThemeData theme,
    Color primaryGreen,
  ) {
    return InkWell(
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://image.tmdb.org/t/p/w200${item.posterPath}',
                width: 56,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 80,
                  color: theme.hintColor.withOpacity(0.3),
                  child: Icon(Icons.movie, color: theme.hintColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.mediaType == 'tv'
                              ? Colors.purple.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.mediaType == 'tv' ? 'TV SHOW' : 'MOVIE',
                          style: TextStyle(
                            color: item.mediaType == 'tv'
                                ? Colors.purple
                                : Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        item.voteAverage.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to start a discussion',
                    style: TextStyle(color: primaryGreen, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.forum_outlined, color: primaryGreen),
          ],
        ),
      ),
    );
  }
}
