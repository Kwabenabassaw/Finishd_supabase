import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finishd/provider/app_navigation_provider.dart';
import 'package:finishd/provider/unread_state_provider.dart';
import 'package:finishd/provider/youtube_feed_provider.dart';
import 'package:finishd/screens/video_upload_screen.dart';

/// Nav item descriptor
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

/// Dynamic center icon nav bar.
///
/// The selected tab's icon moves to the floating center button.
/// The 4 inactive tabs shift to maintain exactly 2 items on the left and 2 on the right.
///
/// Layout (5 tabs total, inactive split 2 | FAB | 2):
class DynamicNavBar extends StatelessWidget {
  const DynamicNavBar({super.key});

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.explore_rounded, label: 'Discover'),
    _NavItem(icon: Icons.people_rounded, label: 'Comms'),
    _NavItem(icon: Icons.chat_bubble_rounded, label: 'Inbox'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<AppNavigationProvider>();
    final unread = context.watch<UnreadStateProvider>();
    final active = nav.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final accent = const Color(0xFF1A8927);
    final inactive = isDark ? Colors.white54 : Colors.grey.shade500;

    // Distribute the 4 inactive tabs to the left and right
    final List<int> inactiveIndices = [];
    for (int i = 0; i < _items.length; i++) {
      if (i != active) inactiveIndices.add(i);
    }

    return BottomAppBar(
      color: bg,
      elevation: 8,
      notchMargin: 6,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: 2 inactive items
            _buildSlot(context, inactiveIndices[0], active, accent, inactive, unread),
            _buildSlot(context, inactiveIndices[1], active, accent, inactive, unread),

            // Center gap for FAB
            const SizedBox(width: 64),

            // Right: 2 inactive items
            _buildSlot(context, inactiveIndices[2], active, accent, inactive, unread),
            _buildSlot(context, inactiveIndices[3], active, accent, inactive, unread),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(
    BuildContext context,
    int index,
    int active,
    Color accent,
    Color inactive,
    UnreadStateProvider unread,
  ) {
    final nav = context.read<AppNavigationProvider>();
    final item = _items[index];

    // Inbox badge
    final showBadge = (index == 3) && unread.hasNewActivity;

    return SizedBox(
      width: 56,
      child: InkWell(
        onTap: () {
          // Feed pause/resume when switching tabs
          final feedProvider = context.read<YoutubeFeedProvider>();
          if (index != 0) {
            feedProvider.pauseAll();
          } else if (index == 0 && active != 0) {
            feedProvider.resumeCurrent();
          }
          // Mark inbox as viewed
          if (index == 3) {
            Provider.of<UnreadStateProvider>(context, listen: false)
                .markMessagesAsViewed();
          }
          nav.setTab(index);
        },
        customBorder: const CircleBorder(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey<int>(index),
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(item.icon, color: inactive, size: 24),
                  if (showBadge)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A8927),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(fontSize: 10, color: inactive),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The floating action button part of the navbar.
/// Shows the active tab's icon. Animates to a plus sign and opens upload screen on tap.
class DynamicNavFab extends StatefulWidget {
  const DynamicNavFab({super.key});

  @override
  State<DynamicNavFab> createState() => _DynamicNavFabState();
}

class _DynamicNavFabState extends State<DynamicNavFab> {
  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.explore_rounded, label: 'Discover'),
    _NavItem(icon: Icons.people_rounded, label: 'Comms'),
    _NavItem(icon: Icons.chat_bubble_rounded, label: 'Inbox'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  bool _showPlus = true;
  Timer? _plusTimer;

  @override
  void initState() {
    super.initState();
    // Start the icon/plus cycle immediately when the app loads
    _startCycle();
  }

  @override
  void didUpdateWidget(DynamicNavFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart cycle on tab change
    _startCycle();
  }
  
  void _startCycle() {
    _plusTimer?.cancel();
    setState(() {
      _showPlus = false; // Show the tab icon immediately
    });
    
    _plusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _showPlus = !_showPlus; // Toggle every 5 seconds
        });
      }
    });
  }

  @override
  void dispose() {
    _plusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<AppNavigationProvider>();
    final active = nav.currentIndex;
    final accent = const Color(0xFF1A8927);

    return FloatingActionButton(
      onPressed: () async {
        if (!_showPlus) {
          // If the tab icon is currently showing, clicking it again restarts cycle
          _startCycle();
          return;
        }

        // It is currently the plus sign — act as an upload button
        await Future.delayed(const Duration(milliseconds: 150));
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VideoUploadScreen()),
        );
        if (mounted) {
          _startCycle(); // Reset the timer cycle after coming back
        }
      },
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 12,
      shape: const CircleBorder(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          _showPlus ? Icons.add : _items[active].icon,
          key: ValueKey(_showPlus ? 'plus' : active),
          size: _showPlus ? 30 : 26,
        ),
      ),
    );
  }
}
