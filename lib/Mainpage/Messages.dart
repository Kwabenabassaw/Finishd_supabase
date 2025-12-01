import 'package:finishd/Chat/chatlist.dart';
import 'package:finishd/Mainpage/Tabs/recs_tab.dart';
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1A8927),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Comms'),
            Tab(text: 'Recs'),
            Tab(text: 'Convos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const Center(child: Text("Comming Soon")),
          const RecsTab(),
          Container(
            margin: EdgeInsets.only(left: 0,right: 0,bottom:70),
child:  ChatListScreen(),
          )
          

          
          
        ],
      ),
    );
  }
}
