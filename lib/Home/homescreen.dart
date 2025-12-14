import 'package:finishd/LoadingWidget/StreamingLoading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/youtube_feed_provider.dart';
import '../Feed/youtube_video_item.dart';
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
  late YoutubeFeedProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = YoutubeFeedProvider();
    _provider.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _provider.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      _provider.resumeCurrent();
    }
  }

  void _showDebugOptions(BuildContext context) {
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
              "Load Next Page (Page ${_provider.currentPage + 1})",
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              "Force manual pagination query",
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _provider.loadMore();
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
              _provider.refresh();
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
              final success = await _provider.triggerBackendRefresh();
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
              await _provider.refresh();
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
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<YoutubeFeedProvider>(
          builder: (context, provider, _) {
            if (provider.videos.isEmpty && provider.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
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

                // Top Bar Overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, 'notification');
                            },
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
                          IconButton(
                            icon: const Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, 'homesearch');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Debug Button
                Positioned(
                  top: 160,
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
                      onPressed: () => _showDebugOptions(context),
                    ),
                  ),
                ),

                // Loading More Indicator
                if (provider.isLoadingMore)
                  const Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(child: LoadingService()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
