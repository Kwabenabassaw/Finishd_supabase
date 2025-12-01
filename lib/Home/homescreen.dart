import 'package:flutter/material.dart';
import 'package:finishd/models/feed_video.dart';
import 'package:finishd/services/youtube_service.dart';
import 'package:finishd/services/fast_video_pool_manager.dart';
import 'package:finishd/Feed/chewie_video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final YouTubeService _youtubeService = YouTubeService();
  final FastVideoPoolManager _videoManager = FastVideoPoolManager();

  final List<FeedVideo> _videos = [];
  bool _isLoading = false;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMoreVideos();
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _videoManager.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      _videoManager.play(_focusedIndex);
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final newVideos = await _youtubeService.fetchVideos();
      if (mounted) {
        setState(() {
          _videos.addAll(newVideos);
          _isLoading = false;
        });

        // Initial setup if this is the first batch
        if (_videos.isNotEmpty && _focusedIndex == 0) {
          _videoManager.initialize(_videos);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint("Error loading videos: $e");
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _focusedIndex = index;
    });

    // Update VideoManager window
    _videoManager.onPageChanged(index, _videos);

    // Infinite scroll: Load more when within 3 items of the end
    if (index >= _videos.length - 3) {
      _loadMoreVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _videos.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _videos.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    return ChewieVideoPlayer(
                      video: _videos[index],
                      index: index,
                      manager: _videoManager,
                    );
                  },
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
              ],
            ),
    );
  }
}
