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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';
import 'package:provider/provider.dart';

import '../provider/youtube_feed_provider.dart';
import 'youtube_video_item.dart';

class TikTokScrollWrapper extends StatefulWidget {
  const TikTokScrollWrapper({super.key});

  @override
  State<TikTokScrollWrapper> createState() => _TikTokScrollWrapperState();
}

class _TikTokScrollWrapperState extends State<TikTokScrollWrapper> {
  late Controller _scrollController;
  int _currentPageIndex = 0;
  StreamSubscription? _jumpSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize the tiktoklikescroller controller
    _scrollController = Controller()
      ..addListener((event) {
        _handleScrollEvent(event);
      });

    // Listen for remote jump requests
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<YoutubeFeedProvider>();
      _jumpSubscription = provider.jumpToPageStream.listen((index) {
        if (mounted && index != _currentPageIndex) {
          debugPrint(
            '[TikTokScroll] 🚀 Jumping to page $index by remote request',
          );
          _scrollController.jumpToPosition(index);
          // animateTo triggers the listener which calls onPageChanged
          _currentPageIndex = index;
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.disposeListeners();
    _jumpSubscription?.cancel();
    super.dispose();
  }

  void _handleScrollEvent(ScrollEvent event) {
    debugPrint(
      '📜 Scroll event: direction=${event.direction}, '
      'success=${event.success}, currentPage=$_currentPageIndex',
    );

    // Only update on successful scrolls
    if (event.success == ScrollSuccess.SUCCESS) {
      final oldIndex = _currentPageIndex;

      // Update current page based on scroll direction
      if (event.direction == ScrollDirection.FORWARD) {
        _currentPageIndex++;
      } else if (event.direction == ScrollDirection.BACKWARDS &&
          _currentPageIndex > 0) {
        _currentPageIndex--;
      }

      if (oldIndex != _currentPageIndex) {
        debugPrint('📄 Page changed: $oldIndex → $_currentPageIndex');

        // Notify provider of the change
        if (mounted) {
          context.read<YoutubeFeedProvider>().onPageChanged(_currentPageIndex);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<YoutubeFeedProvider>(
      builder: (context, provider, _) {
        if (provider.videos.isEmpty) {
          return const SizedBox.shrink();
        }

        return TikTokStyleFullPageScroller(
          contentSize: provider.videos.length,
          swipePositionThreshold: 0.05,
          // ^ 5% of screen height needed to trigger scroll (MUCH more sensitive)
          swipeVelocityThreshold: 200,
          // ^ velocity threshold for quick flicks (lower = easier to trigger)
          animationDuration: const Duration(milliseconds: 350),
          // ^ smooth animation duration (gives time for provider to update)
          controller: _scrollController,
          // ^ our listener for scroll events
          builder: (BuildContext context, int index) {
            // IMPORTANT: Builder is called for ALL visible pages (prev, current, next)
            // Do NOT trigger state changes here - only build the widget
            // Pass the current page so the item knows if it's active
            return YoutubeVideoItem(
              index: index,
              key: ValueKey('video_$index'),
            );
          },
        );
      },
    );
  }
}
