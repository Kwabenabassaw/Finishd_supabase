import 'package:finishd/Chat/chatlist.dart';
import 'package:finishd/Mainpage/Tabs/recs_tab.dart';
import 'package:finishd/Chat/NewChat.dart';
import 'package:flutter/material.dart';

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

    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1A8927),
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Comms'),
            Tab(text: 'Recs'),
            Tab(text: 'Convos'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 2
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
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
          const Center(child: Text("Comming Soon")),
          Container(
            margin: const EdgeInsets.only(left: 0, right: 0, bottom: 50),
            child: const RecsTab(),
          ),
          Container(
            margin: const EdgeInsets.only(left: 0, right: 0, bottom: 70),
            child: const ChatListScreen(),
          ),
        ],
      ),
    );
  }
}
