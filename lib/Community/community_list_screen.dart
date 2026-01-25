import 'package:flutter/material.dart';
import 'package:finishd/services/community_service.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/Community/community_detail_screen.dart';
import 'package:finishd/Community/all_communities_screen.dart';
import 'package:finishd/theme/app_theme.dart';

/// Main community list screen showing user's communities and discovery
class CommunityListScreen extends StatefulWidget {
  const CommunityListScreen({super.key});

  @override
  State<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends State<CommunityListScreen>
    with SingleTickerProviderStateMixin {
  final CommunityService _communityService = CommunityService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Community> _myCommunities = [];
  List<Community> _discoverCommunities = [];
  bool _isLoading = true;
  final String _selectedFilter = 'all'; // 'all', 'tv', 'movie'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCommunities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    setState(() => _isLoading = true);

    try {
      final myResults = await _communityService.getMyCommunities();
      final discoverResults = await _communityService.discoverCommunities(
        mediaTypeFilter: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      setState(() {
        _myCommunities = myResults.map((c) => Community.fromJson(c)).toList();
        _discoverCommunities = discoverResults
            .map((c) => Community.fromJson(c))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading communities: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.group, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Community',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Comms'),
            Tab(text: 'Recs'),
            Tab(text: 'Convos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCommsTab(), _buildRecsTab(), _buildConvosTab()],
      ),
    );
  }

  Widget _buildCommsTab() {
    final filteredCommunities = _myCommunities.where((community) {
      final query = _searchQuery.toLowerCase();
      return community.title.toLowerCase().contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadCommunities,
      color: AppTheme.primaryGreen,
      child: CustomScrollView(
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          icon: Icon(Icons.search),
                          hintText: 'Filter rooms, shows, topics...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('TRENDING', true),
                    _buildFilterChip('TV Shows', false),
                    _buildFilterChip('Movies', false),
                    _buildFilterChip('Live', false),
                  ],
                ),
              ),
            ),
          ),

          // My Communities section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'My Communities',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllCommunitiesScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'View all',
                      style: TextStyle(color: AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Communities list
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_myCommunities.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else if (filteredCommunities.isEmpty)
            _searchQuery.isNotEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No communities found',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  )
                : SliverToBoxAdapter(child: _buildEmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildCommunityCard(filteredCommunities[index]),
                childCount: filteredCommunities.length,
              ),
            ),

          // Discover section
          if (!_isLoading && _discoverCommunities.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Looking for more communities?',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showDiscoverDialog(),
                      icon: Icon(Icons.explore, color: AppTheme.primaryGreen),
                      label: Text(
                        'Discover Communities',
                        style: TextStyle(color: AppTheme.primaryGreen),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primaryGreen),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
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

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {},
        backgroundColor: AppTheme.cardBackground,
        selectedColor: AppTheme.primaryGreen,
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildCommunityCard(Community community) {
    // Calculate time ago for recent post if available
    String timeAgo = '';
    if (community.recentPostTime != null) {
      final diff = DateTime.now().difference(community.recentPostTime!);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24)
        timeAgo = '${diff.inHours}h ago';
      else
        timeAgo = '${diff.inDays}d ago';
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
          color: Colors.white, // As per image background looks white/light
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Poster + Title + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12), // Rounded poster
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: community.posterUrl != null
                        ? Image.network(
                            community.posterUrl!,
                            width: 100,
                            height: 70, // Slightly taller poster
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 100,
                            height: 70,
                            color: Colors.grey[200],
                            child: Icon(Icons.movie, color: Colors.grey[400]),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title and Online Status (Members)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              community.title,
                              style: const TextStyle(
                                color: Colors.black87, // Strong dark text
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Optional: 3 dots icon or status indicator
                          // Icon(Icons.more_horiz, size: 20, color: Colors.grey[400]),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Green dot
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80), // Bright green
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${community.memberCount} members', // "members" as requested (was online)
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (timeAgo.isNotEmpty) ...[
                            Text(
                              ' • $timeAgo',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Recent Post Section
            if (community.recentPostContent != null &&
                community.recentPostContent!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFF8FAFC,
                  ), // Very light grey background for post
                  borderRadius: BorderRadius.circular(16),
                ),
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: '@${community.recentPostAuthor ?? 'User'}: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, // Bold username
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(text: community.recentPostContent),
                    ],
                  ),
                ),
              ),

              // Hashtags or small avatars could go here if in design, but requested to remove avatars.
              // Image shows hashtags at bottom.
              // if (tags.isNotEmpty) Padding(...)
            ] else ...[
              // Optional: Show "No recent posts" or just empty space?
              // Design usually implies active usage.
              const SizedBox(height: 8),
              Text(
                'Join the discussion...',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text(
            'No communities yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a discussion on your favorite show to create a community!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecsTab() {
    return const Center(
      child: Text('Recommendations', style: TextStyle(color: Colors.white)),
    );
  }

  Widget _buildConvosTab() {
    return const Center(
      child: Text('Conversations', style: TextStyle(color: Colors.white)),
    );
  }

  void _showDiscoverDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Discover Communities',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _discoverCommunities.length,
                itemBuilder: (context, index) =>
                    _buildCommunityCard(_discoverCommunities[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
