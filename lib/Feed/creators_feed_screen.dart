import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Widget/comments/comment_sheet.dart';
import '../provider/creators_feed_provider.dart';
import '../provider/app_navigation_provider.dart';
import '../core/video_controller_pool.dart';
import '../core/tiktok_scroll_physics.dart';
import '../core/cache/feed_cache_manager.dart';
import '../main.dart';
import 'creator_video_player.dart';

/// TikTok-style vertical feed for creator videos.
///
/// ── Architecture ────────────────────────────────────────────────────────────
/// This screen delegates ALL controller lifecycle to [VideoControllerPool].
/// [CreatorVideoPlayer] is a dumb display widget — it receives a controller,
/// it never creates one.
///
/// ── Memory Contract ────────────────────────────────────────────────────────
/// Maximum 3 controllers alive at any time (current - 1, current, current + 1).
/// The next controller is pre-created so swiping forward is instant.
/// Controllers outside the window are disposed immediately on page change.
///
/// ── Lifecycle ──────────────────────────────────────────────────────────────
/// Uses [WidgetsBindingObserver] to pause all playback when the app enters
/// background and resume the current video when it returns.
/// Also listens to [AppNavigationProvider] to pause when the user switches
/// away from the Home tab and resume when they return.
class CreatorsFeedScreen extends StatefulWidget {
  const CreatorsFeedScreen({super.key});

  @override
  State<CreatorsFeedScreen> createState() => _CreatorsFeedScreenState();
}

class _CreatorsFeedScreenState extends State<CreatorsFeedScreen>
    with WidgetsBindingObserver, RouteAware {
  late final PageController _pageController;
  late final VideoControllerPool _pool;
  final FeedCacheManager _cacheManager = FeedCacheManager();

  int _currentIndex = 0;
  late CreatorsFeedProvider _provider;

  /// Tracks whether playback is paused due to nav tab switch
  bool _pausedByNav = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // CRITICAL: keepPage: false prevents Flutter from keeping all pages alive
    _pageController = PageController(keepPage: false, viewportFraction: 1.0);

    _pool = VideoControllerPool();

    // Configure image cache limits on init
    _cacheManager.configureImageCache();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _provider = context.read<CreatorsFeedProvider>();
      await _provider.initialize();
      if (mounted && _provider.videos.isNotEmpty) {
        _pool.setVideos(_provider.videos);
        await _pool.onPageChanged(0);
        if (mounted) setState(() {});
      }

      // Listen to bottom nav changes — pause when leaving Home tab
      if (mounted) {
        context.read<AppNavigationProvider>().addListener(_onNavChanged);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  /// Called when bottom nav tab changes
  void _onNavChanged() {
    if (!mounted) return;
    final navIndex = context.read<AppNavigationProvider>().currentIndex;
    if (navIndex != 0 && !_pausedByNav) {
      // User left the Home tab — pause all creator video playback
      _pausedByNav = true;
      _pool.pauseAll();
      _provider.pauseTracking();
    } else if (navIndex == 0 && _pausedByNav) {
      // User returned to Home tab — resume current video
      _pausedByNav = false;
      _pool.resumeCurrent();
      _provider.resumeTracking();
    }
  }

  // ─── App Lifecycle ───────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _pool.pauseAll();
        _provider.pauseTracking();
        break;
      case AppLifecycleState.resumed:
        if (!_pausedByNav) {
          _pool.resumeCurrent();
          _provider.resumeTracking();
        }
        break;
      default:
        break;
    }
  }

  @override
  void didPushNext() {
    // Route was pushed onto navigator and is now on top of this route.
    _pool.pauseAll();
    _provider.pauseTracking();
  }

  @override
  void didPopNext() {
    // Covering route was popped off the navigator.
    if (!_pausedByNav) {
      _pool.resumeCurrent();
      _provider.resumeTracking();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    // Remove nav listener
    try {
      context.read<AppNavigationProvider>().removeListener(_onNavChanged);
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _pool.disposeAll();
    super.dispose();
  }

  // ─── Page change handler ─────────────────────────────────────────────────

  void _onPageChanged(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;

    // Trigger pagination when nearing the end.
    if (index >= _provider.videos.length - 4) {
      _provider.fetchMoreDebounced();
    }

    // Update pool with latest video list (may have grown from pagination)
    _pool.setVideos(_provider.videos);

    // Activate new page in pool (handles play/pause/dispose/preload)
    _pool.onPageChanged(index).then((_) {
      if (mounted) setState(() {});
    });

    // Record view via data source
    _provider.recordView(index);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<CreatorsFeedProvider>(
      builder: (context, provider, _) {
        _provider = provider;

        if (provider.videos.isEmpty && provider.isLoading) {
          return const Center(child: LogoLoadingScreen());
        }

        if (provider.error != null && provider.videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white54,
                  size: 32.sp, // replaced 48
                ),
                SizedBox(height: 1.5.h), // replaced 12
                Text(
                  'Could not load videos',
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                ),
                SizedBox(height: 1.h), // replaced 8
                TextButton(
                  onPressed: () async {
                    await provider.refresh();
                    if (mounted && provider.videos.isNotEmpty) {
                      _pool.reset();
                      _pool.setVideos(provider.videos);
                      await _pool.onPageChanged(0);
                      setState(() {});
                    }
                  },
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        }

        // Sync pool with provider's video list (handles pagination appends)
        if (provider.videos.length != _pool.videoCount) {
          _pool.setVideos(provider.videos);
        }

        return RefreshIndicator(
          onRefresh: () async {
            _pool.disposeAll();
            await provider.refresh();
            if (mounted && provider.videos.isNotEmpty) {
              _pool.reset();
              _pool.setVideos(provider.videos);
              _currentIndex = 0;
              // Jump the PageView back to page 0
              if (_pageController.hasClients) {
                _pageController.jumpToPage(0);
              }
              await _pool.onPageChanged(0);
              setState(() {});
            }
          },
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const TikTokScrollPhysics(),
            itemCount: provider.videos.length,
            onPageChanged: _onPageChanged,
            allowImplicitScrolling: false,
            itemBuilder: (context, index) {
              final video = provider.videos[index];
              final controller = _pool.getController(index);
              final thumbnailUrl = _pool.getThumbnailUrl(index);

              return CreatorVideoPlayer(
                key: ValueKey(video.id),
                video: video,
                isLiked: provider.isLiked(video.id),
                controller: controller,
                isVisible: index == _currentIndex,
                resolvedThumbnailUrl: thumbnailUrl,
                onLike: () {
                  provider.toggleLike(index);
                },
                onComment: () async {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) return;

                  final metadata = user.userMetadata;
                  // We record the interaction right away for simply opening the comments,
                  // or we could do it after. Let's do it immediately.
                  provider.recordComment(index);

                  await CommentSheet.show(
                    context: context,
                    videoId: video.id,
                    userId: user.id,
                    userName: metadata?['username'] ?? 'User',
                    userAvatar: metadata?['avatar_url'],
                  );
                },
                onShare: () {
                  provider.recordShare(index);
                  Share.share(
                    'Check out this video on Finishd!\n\n${video.videoUrl}',
                    subject: video.title.isNotEmpty
                        ? video.title
                        : 'Finishd Video',
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
