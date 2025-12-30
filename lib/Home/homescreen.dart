import 'package:finishd/Home/widgets/contentNav.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/youtube_feed_provider.dart';
import '../Feed/tiktok_scroll_wrapper.dart';
import '../services/cache/feed_cache_service.dart';

/// HomeScreen using Provider for state management.
///
/// Features:
/// - Centralized state via YoutubeFeedProvider
/// - YouTube native player (youtube_player_flutter) for better performance
/// - 3-controller window strategy for memory management
/// - TikTok-style vertical scrolling using tiktoklikescroller package
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final provider = context.read<YoutubeFeedProvider>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      provider.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      provider.resumeCurrent();
    }
  }

  void _showDebugOptions(BuildContext context, YoutubeFeedProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Column(
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
              "Load Next Page (Page ${provider.currentPage + 1})",
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              "Force manual pagination query",
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(ctx);
              provider.loadMore();
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.green),
            title: const Text(
              "Force Full Refresh",
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              "Fetch fresh content from API",
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(ctx);
              provider.refresh();
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
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Triggering backend job...")),
              );
              final success = await provider.triggerBackendRefresh();
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
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text(
              "Clear SQLite Cache & Refresh",
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              "Clears local cache and pulls new data from backend",
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Clearing cache...")),
              );
              // Clear SQLite feed cache
              await FeedCacheService.clearFeed();
              // Refresh from network
              await provider.refresh();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ Cache cleared & feed refreshed!"),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YoutubeFeedProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Sleek Top Navigation Header (Always Visible)
            _buildHeader(provider),

            // 2. Main Content Area (Scroller / Loading / Error)
            Expanded(
              child: Consumer<YoutubeFeedProvider>(
                builder: (context, provider, _) {
                  // Loading state
                  if (provider.videos.isEmpty && provider.isLoading) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LogoLoadingScreen(),
                          SizedBox(height: 16),
                          Text(
                            'Loading your feed...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  }

                  // Error state
                  if (provider.hasError && provider.videos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Something went wrong',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          if (provider.errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              provider.errorMessage!,
                              style: const TextStyle(color: Colors.white54),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => provider.refresh(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Empty state
                  if (provider.videos.isEmpty) {
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
                            onPressed: () => provider.refresh(),
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

                  return Stack(
                    children: [
                      // Main TikTok-style scroller
                      RefreshIndicator(
                        onRefresh: provider.refresh,
                        child: const TikTokScrollWrapper(),
                      ),

                      // Debug Button (Floating on player)
                      Positioned(
                        top: 100, // Adjusted for new header
                        right: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.build,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () =>
                                _showDebugOptions(context, provider),
                          ),
                        ),
                      ),

                      // Loading More Indicator
                      if (provider.isLoadingMore)
                        const Positioned(
                          bottom: 100,
                          left: 0,
                          right: 0,
                          child: Center(child: LogoLoadingScreen()),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// New Dedicated Header (Off the Player)
  /// --------------------------------------------------------------------------
  Widget _buildHeader(YoutubeFeedProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.black, // Dedicated dark background
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Notification Icon
          SizedBox(
            width: 44,
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                // Pause video before navigating
                provider.pauseAll();
                Navigator.pushNamed(context, 'notification').then((_) {
                  // Resume video when returning
                  if (mounted) provider.resumeCurrent();
                });
              },
            ),
          ),

          // 2. Center Tabs (Trending, Following, For You)
          const Expanded(child: ContentNav()),

          // 3. Friends Icon
          SizedBox(
            width: 44,
            child: IconButton(
              icon: const Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                // Pause video before navigating
                provider.pauseAll();
                Navigator.pushNamed(context, 'friends').then((_) {
                  // Resume video when returning
                  if (mounted) provider.resumeCurrent();
                });
              },
            ),
          ),

          // 4. Search Icon
          SizedBox(
            width: 44,
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 24),
              onPressed: () {
                // Pause video before navigating
                provider.pauseAll();
                Navigator.pushNamed(context, 'homesearch').then((_) {
                  // Resume video when returning
                  if (mounted) provider.resumeCurrent();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
