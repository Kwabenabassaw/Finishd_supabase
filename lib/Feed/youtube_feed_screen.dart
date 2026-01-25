/// YouTube Feed Screen (TikTok-style)
///
/// Main screen using PageView.builder for vertical scroll.
/// Uses YoutubeFeedProvider for centralized state management.
///
/// Key features:
/// - Vertical PageView for TikTok-style scrolling
/// - Custom TikTok snap physics for smooth scrolling
/// - Lifecycle handling (pause on background, resume on foreground)
/// - Loading/error/empty states
/// - Debug tools for development
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/youtube_feed_provider.dart';
import 'youtube_video_item.dart';
import '../services/cache/feed_cache_service.dart';

class YoutubeFeedScreen extends StatefulWidget {
  const YoutubeFeedScreen({super.key});

  @override
  State<YoutubeFeedScreen> createState() => _YoutubeFeedScreenState();
}

class _YoutubeFeedScreenState extends State<YoutubeFeedScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  late YoutubeFeedProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _provider = YoutubeFeedProvider();
    _provider.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _provider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause video when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _provider.pauseAll();
    }
    // Resume when app comes back
    if (state == AppLifecycleState.resumed) {
      _provider.resumeCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<YoutubeFeedProvider>(
          builder: (context, provider, _) {
            // Loading state
            if (provider.isLoading && provider.videos.isEmpty) {
              return _buildLoadingState();
            }

            // Error state
            if (provider.hasError && provider.videos.isEmpty) {
              return _buildErrorState(provider.errorMessage);
            }

            // Empty state
            if (provider.videos.isEmpty) {
              return _buildEmptyState();
            }

            // Main feed
            return Stack(
              children: [
                // Vertical PageView for TikTok-style scrolling
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const ClampingScrollPhysics(),
                  itemCount: provider.videos.length,
                  onPageChanged: provider.onPageChanged,
                  itemBuilder: (context, index) {
                    return YoutubeVideoItem(index: index);
                  },
                ),

                // Top bar overlay
                _buildTopBar(provider),

                // Debug button
                Positioned(top: 100, right: 16, child: _buildDebugButton()),

                // Loading more indicator
                if (provider.isLoadingMore)
                  const Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading your feed...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _provider.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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
            Icons.video_library_outlined,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No videos available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _provider.refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(YoutubeFeedProvider provider) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'For You',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Loading indicator when refreshing
            if (provider.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            Text(
              '${provider.currentIndex + 1}/${provider.videos.length}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: const Icon(Icons.build_rounded, color: Colors.white, size: 20),
        onPressed: _showDebugOptions,
      ),
    );
  }

  void _showDebugOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '🛠️ Debug & Refresh Tools',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.green),
            title: const Text(
              'Force Refresh',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Clears cache and reloads',
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _provider.refresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync, color: Colors.orange),
            title: const Text(
              'Trigger Backend Refresh',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Tell server to fetch fresh content',
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Triggering backend job...')),
              );
              final success = await _provider.triggerBackendRefresh();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '✅ Backend job started!'
                          : '❌ Failed to start job',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text(
              'Clear SQLite Cache',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Removes all cached feed data',
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              await FeedCacheService.clearFeed();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Cache cleared!')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.blue),
            title: Text(
              'Load More (Page ${_provider.currentPage + 1})',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _provider.loadMore();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
