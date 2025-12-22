import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finishd/provider/youtube_feed_provider.dart';
import 'package:finishd/services/api_client.dart';

/// Feed Tabs Wrapper Widget
///
/// Wraps the TikTok-style feed with a three-tab navigation:
/// - Trending: Global trending content
/// - Following: Content from friends and communities
/// - For You: Personalized recommendations
class FeedTabsWrapper extends StatefulWidget {
  final Widget feedWidget;

  const FeedTabsWrapper({super.key, required this.feedWidget});

  @override
  State<FeedTabsWrapper> createState() => _FeedTabsWrapperState();
}

class _FeedTabsWrapperState extends State<FeedTabsWrapper> {
  // Tab labels
  final List<String> _tabs = ['Following', 'For You', 'Trending'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YoutubeFeedProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Map FeedType to tab index
    int selectedIndex;
    switch (provider.activeFeedType) {
      case FeedType.following:
        selectedIndex = 0;
        break;
      case FeedType.forYou:
        selectedIndex = 1;
        break;
      case FeedType.trending:
        selectedIndex = 2;
        break;
    }

    return Stack(
      children: [
        // Feed content (full screen)
        widget.feedWidget,

        // Top gradient overlay for legibility
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Tab bar at top (above the gradient)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 0,
          right: 0,
          child: _buildTabBar(context, selectedIndex, isDark, provider),
        ),
      ],
    );
  }

  Widget _buildTabBar(
    BuildContext context,
    int selectedIndex,
    bool isDark,
    YoutubeFeedProvider provider,
  ) {
    if (Platform.isIOS) {
      return _buildIOSTabBar(context, selectedIndex, provider);
    } else {
      return _buildAndroidTabBar(context, selectedIndex, provider);
    }
  }

  /// iOS-style tab bar with glassmorphic background
  Widget _buildIOSTabBar(
    BuildContext context,
    int selectedIndex,
    YoutubeFeedProvider provider,
  ) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_tabs.length, (index) {
                final isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => _onTabTapped(index, provider),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tabs[index],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: isSelected ? 15 : 14,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  /// Android-style tab bar
  Widget _buildAndroidTabBar(
    BuildContext context,
    int selectedIndex,
    YoutubeFeedProvider provider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_tabs.length, (index) {
        final isSelected = index == selectedIndex;
        return GestureDetector(
          onTap: () => _onTabTapped(index, provider),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _tabs[index],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: isSelected ? 17 : 15,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  width: isSelected ? 24 : 0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _onTabTapped(int index, YoutubeFeedProvider provider) {
    FeedType newType;
    switch (index) {
      case 0:
        newType = FeedType.following;
        break;
      case 1:
        newType = FeedType.forYou;
        break;
      case 2:
        newType = FeedType.trending;
        break;
      default:
        newType = FeedType.forYou;
    }

    provider.switchFeedType(newType);
  }
}
