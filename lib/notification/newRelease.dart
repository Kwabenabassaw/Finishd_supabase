
import 'package:flutter/material.dart';
import 'package:finishd/notification/builditem.dart';
class Newrelease extends StatelessWidget {
  const Newrelease({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: 
       ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Section Header
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    "Important",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                
                // List Items
                NotificationItem(
                  title: "WWEI Entertainment",
                  subtitle: "Uploaded: Wrestling",
                  time: "14hours ago",
                  imageUrl: "https://placehold.co/200x120/000000/FFFFFF/png?text=WWE",
                  isFirst: true,
                ),
                NotificationItem(
                  title: "Romantic Entertainment",
                  subtitle: "Uploaded: Romantic movies 2",
                  time: "8hours ago",
                  imageUrl: "https://placehold.co/200x120/3b2721/FFFFFF/png?text=FRIENDS",
                ),
               NotificationItem(
                  title: "Comedy Entertainment",
                  subtitle: "Uploaded: Comedy moment",
                  time: "8hours ago",
                  imageUrl: "https://placehold.co/200x120/0055aa/FFFFFF/png?text=Superman",
                ),
                
                NotificationItem(
                  title: "Historic Entertainment",
                  subtitle: "Uploaded: History Movie 2",
                  time: "14hours ago",
                  imageUrl: "https://placehold.co/200x120/554433/FFFFFF/png?text=Slow+Horses",
                ),
                NotificationItem(
                  title: "Disney Entertainment",
                  subtitle: "Uploaded: Dead pool Movie",
                  time: "14hours ago",
                  imageUrl: "https://placehold.co/200x120/aa0000/FFFFFF/png?text=Deadpool",
                ),
              ],
            ),
      
    );
  }
}