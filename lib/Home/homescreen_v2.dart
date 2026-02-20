import 'package:flutter/material.dart';
import 'package:finishd/models/feed_item.dart';
import 'package:finishd/services/api_client.dart';
import 'package:finishd/services/feed_video_manager.dart';
import 'package:finishd/Feed/feed_video_player_v2.dart';

/// New HomeScreen using TMDB-based feed
/// Displays both TMDB trailers and YouTube BTS/Interview content
class HomeScreenV2 extends StatefulWidget {
  const HomeScreenV2({super.key});

  @override
  State<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends State<HomeScreenV2>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final ApiClient _apiClient = ApiClient();
  final FeedVideoManager _videoManager = FeedVideoManager();

  final List<FeedItem> _feedItems = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentIndex = 0;
  int _currentPage = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFeed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _videoManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint('[HomeScreenV2] 📱 App Paused/Inactive - PAUSING ALL');
      _videoManager.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[HomeScreenV2] 📱 App Resumed - Checking visibility');
      // Only resume if this screen is actually visible
      final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (isTopRoute) {
        debugPrint('[HomeScreenV2] 🚀 Top route - RESUMING');
        _videoManager.resumeCurrent();
      } else {
        debugPrint('[HomeScreenV2] 🧊 Not top route - STAYING PAUSED');
        _videoManager.pauseAll();
      }
    }
  }

  Future<void> _loadFeed({bool refresh = false, int page = 1}) async {
    if (_isLoading && page == 1) return;

    if (page == 1) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        if (refresh) _currentPage = 1;
      });
    }

    try {
      print('📡 Loading TMDB-based feed (Page $page)...');

      var items = await _apiClient.getPersonalizedFeedV2(
        refresh: refresh,
        limit: 50,
        page: page,
      );

      print('📥 Personalized feed response: ${items.length} items');

      // Fallback to global feed if personalized is empty
      if (items.isEmpty) {
        print('⚠️ Personalized feed empty, trying global feed...');
        items = await _apiClient.getGlobalFeed(limit: 50);
        print('📥 Global feed response: ${items.length} items');
      }

      // Debug: log first item if available
      if (items.isNotEmpty) {
        final first = items.first;
        print(
          '🎬 First item: ${first.title} (${first.type}) - hasVideo: ${first.hasYouTubeVideo}',
        );
      }

      if (mounted) {
        setState(() {
          if (refresh || page == 1) {
            _feedItems.clear();
            _feedItems.addAll(items);
          } else {
            // Deduplicate when appending
            final existingIds = _feedItems.map((i) => i.id).toSet();
            final uniqueItems = items
                .where((i) => !existingIds.contains(i.id))
                .toList();

            if (uniqueItems.isNotEmpty) {
              _feedItems.addAll(uniqueItems);
              print(
                '✅ Appended ${uniqueItems.length} unique items (skipped ${items.length - uniqueItems.length} duplicates)',
              );
            } else {
              print('⚠️ All items from this page were duplicates.');
            }
          }

          _isLoading = false;
          _isLoadingMore = false;
        });

        print('✅ Loaded ${items.length} feed items');

        // Initialize video manager for first page
        if ((refresh || page == 1) && _feedItems.isNotEmpty) {
          _videoManager.setCurrentIndex(0, _feedItems);
        }

        // Log content breakdown
        final tmdbCount = items.where((i) => i.source == 'tmdb').length;
        final youtubeCount = items
            .where((i) => i.source == 'youtube_cached')
            .length;
        print('📊 TMDB: $tmdbCount | YouTube BTS: $youtubeCount');
      }
    } catch (e) {
      print('❌ Error loading feed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Update video manager for preloading
    _videoManager.setCurrentIndex(index, _feedItems);

    // Load more when near the end (prevents duplicate calls)
    // Increased threshold to ensure it triggers before actually hitting the wall
    if (index >= _feedItems.length - 3 && !_isLoading && !_isLoadingMore) {
      print(
        '📜 Reached index $index (total ${_feedItems.length}), triggering load more...',
      );
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    print('🔄 triggered load more for page $nextPage');

    await _loadFeed(page: nextPage);

    if (mounted) {
      setState(() => _currentPage = nextPage);
    }
  }

  Future<void> _onRefresh() async {
    await _loadFeed(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading && _feedItems.isEmpty) {
      return _buildLoadingState();
    }

    if (_hasError && _feedItems.isEmpty) {
      return _buildErrorState();
    }

    if (_feedItems.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        // Main Feed
        RefreshIndicator(
          onRefresh: _onRefresh,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _feedItems.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return FeedVideoPlayerV2(
                item: _feedItems[index],
                index: index,
                videoManager: _videoManager,
              );
            },
          ),
        ),

        // Top Bar
        _buildTopBar(),

        // Stats Overlay (debug)
        // Stats Overlay (debug)
        if (true) // Set to false in production
          Positioned(bottom: 20, left: 16, child: _buildStatsOverlay()),

        // Debug/Refresh Button (User Request)
        Positioned(
          top: 160, // Below Mute button (which is at 100)
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: IconButton(
              icon: const Icon(Icons.build, color: Colors.white, size: 20),
              onPressed: _showDebugOptions,
            ),
          ),
        ),
      ],
    );
  }

  void _showDebugOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "🛠️ Debug & Refresh Tools",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.blue),
            title: Text(
              "Load Next Page (Page ${_currentPage + 1})",
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              "Force manual pagination query",
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(context);
              _loadMore();
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.green),
            title: const Text(
              "Force Full Refresh",
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              "Clear local cache and fetch Page 1",
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(context);
              _onRefresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync, color: Colors.orange),
            title: const Text(
              "Trigger Backend Cron Job",
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              "Tell server to fetch fresh content from TMDB/YouTube",
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Triggering backend job...")),
              );
              final success = await _apiClient.triggerBackendRefresh();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? "✅ Backend job started!"
                          : "❌ Failed to start job",
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pushNamed(context, 'notification'),
              ),

              // Feed type indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getCurrentItemIcon(), color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'For You',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 28),
                onPressed: () => Navigator.pushNamed(context, 'homesearch'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCurrentItemIcon() {
    if (_feedItems.isEmpty || _currentIndex >= _feedItems.length) {
      return Icons.movie;
    }

    final item = _feedItems[_currentIndex];
    if (item.isBTS) return Icons.videocam;
    if (item.isInterview) return Icons.mic;
    return Icons.movie;
  }

  Widget _buildStatsOverlay() {
    final tmdbCount = _feedItems.where((i) => i.source == 'tmdb').length;
    final youtubeCount = _feedItems
        .where((i) => i.source == 'youtube_cached')
        .length;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '📊 Feed Stats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'TMDB: $tmdbCount',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'YouTube: $youtubeCount',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Loading your personalized feed...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load feed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadFeed(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.movie_creation_outlined,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No content available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
