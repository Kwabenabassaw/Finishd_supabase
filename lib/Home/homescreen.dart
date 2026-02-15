import 'package:finishd/Home/widgets/contentNav.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/youtube_feed_provider.dart';
import '../Feed/tiktok_scroll_wrapper.dart';
import '../services/cache/feed_cache_service.dart';
import 'package:finishd/main.dart'; // routeObserver
import 'package:finishd/provider/app_navigation_provider.dart'; // AppNavigationProvider

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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this); // Unsubscribe from route events
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route events
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  // Called when this screen is covered by another route (e.g., chat, notification)
  @override
  void didPushNext() {
    debugPrint('[HomeScreen] 🧊 Covered by another route - PAUSING');
    final provider = context.read<YoutubeFeedProvider>();
    provider.pauseAll();
  }

  // Called when the top route is popped and this screen becomes visible again
  @override
  void didPopNext() {
    debugPrint('[HomeScreen] 🔥 Returned to view - Checking tab index');
    final navProvider = context.read<AppNavigationProvider>();
    final feedProvider = context.read<YoutubeFeedProvider>();

    if (navProvider.currentIndex == 0) {
      debugPrint('[HomeScreen] ✅ On Home tab - RESUMING');
      feedProvider.resumeCurrent();
    } else {
      debugPrint('[HomeScreen] 🧊 Not on Home tab - STAYING PAUSED');
      // Ensure it stays paused just in case
      feedProvider.pauseAll();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final provider = context.read<YoutubeFeedProvider>();
    final navProvider = context.read<AppNavigationProvider>();

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint('[HomeScreen] 📱 App Latency: $state - PAUSING');
      provider.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[HomeScreen] 📱 App Resumed - Checking visibility');
      // Only resume if we are successfully visible AND on the Home tab
      final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
      final isHomeTab = navProvider.currentIndex == 0;

      if (isTopRoute && isHomeTab) {
        debugPrint('[HomeScreen] 🚀 Top route & Home tab - RESUMING');
        provider.resumeCurrent();
      } else {
        debugPrint(
          '[HomeScreen] 🧊 Not visible or not on Home tab - STAYING PAUSED (isTopRoute: $isTopRoute, isHomeTab: $isHomeTab)',
        );
        provider.pauseAll();
      }
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
      body: Stack(
        children: [
          // 1. FULL SCREEN CONTENT (Video Scroller)
          // We remove SafeArea from the scroller to let it bleed into the top/bottom
          Consumer<YoutubeFeedProvider>(
            builder: (context, provider, _) {
              // Loading state
              if (provider.videos.isEmpty && provider.isLoading) {
                return const Center(child: LogoLoadingScreen());
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
                      const SizedBox(height: 10),
                      const Text(
                        'Something went wrong',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
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

              // Empty state (no videos, no error, not loading)
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
                      const SizedBox(height: 8),
                      const Text(
                        'Pull to refresh or try again later',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
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
                  // Main TikTok-style scroller (Full Screen)
                  RefreshIndicator(
                    onRefresh: provider.refresh,
                    child: const TikTokScrollWrapper(),
                  ),

                  // Debug Button (Positioned relative to full screen)
                  Positioned(
                    top: 150, // Below the header
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
                        onPressed: () => _showDebugOptions(context, provider),
                      ),
                    ),
                  ),

                  // Loading More Indicator
                  if (provider.isLoadingMore)
                    const Positioned(
                      bottom: 120,
                      left: 0,
                      right: 0,
                      child: Center(child: LogoLoadingScreen()),
                    ),
                ],
              );
            },
          ),

          // 2. OVERLAY HEADER (Positioned at Top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildHeader(provider)),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// New Dedicated Header (Now Overlays the Player)
  /// --------------------------------------------------------------------------
  Widget _buildHeader(YoutubeFeedProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      decoration: BoxDecoration(
        // Solid black background to cover YouTube edges
        color: Colors.black.withOpacity(0.8),
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
                // Pause handled by didPushNext, resume by didPopNext
                Navigator.pushNamed(context, 'notification');
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
                // Pause handled by didPushNext, resume by didPopNext
                Navigator.pushNamed(context, 'friends');
              },
            ),
          ),

          // 4. Search Icon
          SizedBox(
            width: 44,
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 24),
              onPressed: () {
                // Pause handled by didPushNext, resume by didPopNext
                Navigator.pushNamed(context, 'homesearch');
              },
            ),
          ),
        ],
      ),
    );
  }
}
