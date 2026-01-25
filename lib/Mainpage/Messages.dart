import 'package:finishd/Chat/chatlist.dart';
import 'package:finishd/Mainpage/Tabs/recs_tab.dart';
import 'package:finishd/Mainpage/Tabs/comms_tab.dart';
import 'package:finishd/Chat/NewChat.dart';
import 'package:finishd/theme/app_theme.dart';
import 'package:finishd/provider/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class Messages extends StatefulWidget {
  const Messages({super.key});

  @override
  State<Messages> createState() => _MessagesState();
}

class _MessagesState extends State<Messages>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: 1,
    ); // Default to Recs
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    } else {
      // Also update when animation finishes to be sure
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

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: isIOS
                ? _buildCustomSegmentedControl(isDark, totalUnread)
                : Text(
                    "Messages",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            bottom: !isIOS
                ? TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primaryGreen,
                    labelColor: isDark ? Colors.white : Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: [
                      const Tab(text: 'Comms'),
                      const Tab(text: 'Recs'),
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
                  padding: const EdgeInsets.only(
                    bottom: 30.0,
                  ),
                  child: FloatingActionButton(
                    backgroundColor: const Color(0xFF1A8927),
                    child: const Icon(Icons.add, color: Colors.white),
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
            children: [
              const CommsTab(), // Community tab
              const RecsTab(),
              const ChatListScreen(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomSegmentedControl(bool isDark, int unreadCount) {
    return Container(
      height: 40,
      width: 280,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _tabController.index == 0
                ? Alignment.centerLeft
                : (_tabController.index == 1
                      ? Alignment.center
                      : Alignment.centerRight),
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 90,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : AppTheme.primaryGreen,
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
              _buildTabItem(0, "Comms", isDark),
              _buildTabItem(1, "Recs", isDark),
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
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white70 : Colors.black54),
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
