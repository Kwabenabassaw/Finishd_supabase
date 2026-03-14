import 'package:finishd/Chat/chatlist.dart';
import 'package:finishd/Mainpage/Tabs/friends_tab.dart';
import 'package:finishd/Mainpage/Tabs/recs_tab.dart';
import 'package:finishd/Chat/NewChat.dart';
import 'package:finishd/theme/app_theme.dart';
import 'package:finishd/provider/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:io';
import 'package:finishd/provider/app_navigation_provider.dart';
import 'package:finishd/Widget/animated_wallpaper.dart';

class Messages extends StatefulWidget {
  const Messages({super.key});

  @override
  State<Messages> createState() => _MessagesState();
}

class _MessagesState extends State<Messages>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static int _persistedTabIndex = 2; // Persisted across navigations
  int _lastNavIndex = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _persistedTabIndex, // Use persisted index
    );
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Listen to global app navigation changes
    final nav = Provider.of<AppNavigationProvider>(context);
    
    // Removed automatic reset to Convos (index 2). 
    // Tab persistence is now handled via _persistedTabIndex.
    
    _lastNavIndex = nav.currentIndex;
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    } else {
      // Update persisted index when selection stabilizes
      _persistedTabIndex = _tabController.index;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIOS = Platform.isIOS;

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Calculate total unread count from all conversations
        final totalUnread = chatProvider.conversations.fold<int>(
          0,
          (sum, conv) => sum + conv.unreadCount,
        );

        return AnimatedWallpaper(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              centerTitle: true,
              title: isIOS
                  ? _buildCustomSegmentedControl(isDark, totalUnread)
                  : Text(
                      "Messages",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              bottom: !isIOS
                  ? TabBar(
                      controller: _tabController,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      labelColor: Theme.of(context).colorScheme.onSurface,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        const Tab(text: 'Recs'),
                        const Tab(text: 'Friends'),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Convos'),
                              if (totalUnread > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    totalUnread > 99 ? '99+' : '$totalUnread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            floatingActionButton: _tabController.index == 2
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 35.0),
                    child: FloatingActionButton(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(LucideIcons.plus, color: Theme.of(context).colorScheme.onPrimary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NewChatListScreen(),
                          ),
                        );
                      },
                    ),
                  )
                : null,
            body: TabBarView(
              controller: _tabController,
              children: [const RecsTab(), const FriendsTab(), const ChatListScreen()],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomSegmentedControl(bool isDark, int unreadCount) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      width: 240,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.onSurface.withOpacity(0.08)
            : theme.colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _tabController.index == 0
                ? Alignment.centerLeft
                : _tabController.index == 1
                    ? Alignment.center
                    : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 75,
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _buildTabItem(0, "Recs", isDark),
              _buildTabItem(1, "Friends", isDark),
              _buildTabItem(2, "Convos", isDark, badgeCount: unreadCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    int index,
    String label,
    bool isDark, {
    int badgeCount = 0,
  }) {
    bool isActive = _tabController.index == index;
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? (isDark ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary)
                      : (theme.colorScheme.onSurface.withOpacity(isDark ? 0.7 : 0.54)),
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
