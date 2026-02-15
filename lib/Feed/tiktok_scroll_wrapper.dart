/// TikTok Scroll Wrapper
///
/// Wraps TikTokStyleFullPageScroller with YoutubeFeedProvider integration.
///
/// Features:
/// - Listens to scroll events from tiktoklikescroller
/// - Notifies provider on page changes
/// - Configurable swipe thresholds and animation duration
/// - Uses YoutubeVideoItem for each page
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/youtube_feed_provider.dart';
import 'youtube_video_item.dart';

class TikTokScrollWrapper extends StatefulWidget {
  const TikTokScrollWrapper({super.key});

  @override
  State<TikTokScrollWrapper> createState() => _TikTokScrollWrapperState();
}

class _TikTokScrollWrapperState extends State<TikTokScrollWrapper> {
  late final PageController _pageController;
  int _lastKnownLength = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _precacheNearThumbnails(YoutubeFeedProvider provider, int center) {
    final nextCandidates = [center + 1, center + 2];
    for (final index in nextCandidates) {
      if (index < 0 || index >= provider.videos.length) continue;
      final url = provider.videos[index].thumbnailUrl;
      if (url.isEmpty) continue;
      precacheImage(NetworkImage(url), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<YoutubeFeedProvider, int>(
      selector: (_, provider) => provider.videos.length,
      builder: (context, length, _) {
        final provider = context.read<YoutubeFeedProvider>();
        if (length == 0) return const SizedBox.shrink();

        if (_lastKnownLength != length && _pageController.hasClients) {
          final target = provider.currentIndex.clamp(0, length - 1);
          _pageController.jumpToPage(target);
          _lastKnownLength = length;
        }

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(),
          itemCount: length,
          onPageChanged: (index) {
            provider.onPageChanged(index);
            _precacheNearThumbnails(provider, index);
          },
          itemBuilder: (context, index) => YoutubeVideoItem(
            index: index,
            key: ValueKey(provider.videos[index].videoId),
          ),
        );
      },
    );
  }
}
