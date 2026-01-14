import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finishd/provider/youtube_feed_provider.dart';
import 'package:finishd/services/api_client.dart';

/// Content navigation tabs for the TikTok-style feed.
///
/// Connects to YoutubeFeedProvider to switch between:
/// - Trending: Global trending content
/// - Following: Friends' activity
/// - For You: Personalized recommendations
class ContentNav extends StatelessWidget {
  const ContentNav({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YoutubeFeedProvider>();

    // Tab order: [Trending, For You]
    final List<String> tabs = ["Trending", "For You"];

    // Map FeedType to tab index
    int selectedIndex;
    switch (provider.activeFeedType) {
      case FeedType.trending:
        selectedIndex = 0;
        break;
      case FeedType.following:
        // Following tab removed, default to For You
        selectedIndex = 1;
        break;
      case FeedType.forYou:
        selectedIndex = 1;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(tabs.length, (index) {
        bool isActive = selectedIndex == index;

        return GestureDetector(
          onTap: () => _onTabTapped(index, provider),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white60,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    fontSize: isActive ? 18 : 16,
                    shadows: [
                      if (isActive)
                        const Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Text(tabs[index]),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  width: isActive ? 24 : 0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      if (isActive)
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                    ],
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
        newType = FeedType.trending;
        break;
      case 1:
        newType = FeedType.forYou;
        break;
      default:
        newType = FeedType.forYou;
    }

    provider.switchFeedType(newType);
  }
}
