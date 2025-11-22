import 'package:finishd/notification/newRelease.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 1, // "New Release" is selected in the design
      child: Scaffold(
        appBar: AppBar(
    
          title: const Text('Notifications'),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: const TabBar(
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.green,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(text: 'All'),
                  Tab(text: 'New Release'),
                ],

              
              ),

              
            ),
          ),
        ),
        body: const TabBarView(

          children: [
            Newrelease(),
            Newrelease(),
          ],
         )
      ),
    );
  }
}
