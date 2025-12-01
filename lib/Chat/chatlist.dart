import 'package:finishd/Chat/NewChat.dart';
import 'package:finishd/Chat/chatScreen.dart';
import 'package:finishd/models/chat_model.dart';
import 'package:finishd/services/chat_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final chatService = ChatService();
    final userService = UserService();

    if (currentUser == null) {
      return const Center(child: Text('Please log in to see messages'));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A8927),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewChatListScreen()),
          );
        },
      ),
      body: StreamBuilder<List<Chat>>(
        stream: chatService.getChatListStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                // Force refresh by waiting a bit for the stream to update
                await Future.delayed(const Duration(milliseconds: 500));
              },
              color: const Color(0xFF1A8927),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 400,
                    child: Center(child: Text('No messages yet')),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              // Force refresh by waiting a bit for the stream to update
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: const Color(0xFF1A8927),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final otherUserId = chat.participants.firstWhere(
                  (id) => id != currentUser.uid,
                );
                final unreadCount = chat.unreadCounts[currentUser.uid] ?? 0;

                return FutureBuilder<UserModel?>(
                  future: userService.getUser(otherUserId),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const SizedBox.shrink(); // Or a loading placeholder
                    }

                    final otherUser = userSnapshot.data!;
                    final time = DateFormat(
                      'MMM d',
                    ).format(chat.lastMessageTime.toDate());

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: otherUser.profileImage.isNotEmpty
                            ? NetworkImage(otherUser.profileImage)
                            : null,
                        child: otherUser.profileImage.isEmpty
                            ? Text(otherUser.username[0].toUpperCase())
                            : null,
                      ),
                      title: Text(
                        otherUser.username,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? Colors.black87
                              : Colors.grey[500],
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A8927),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatId: chat.chatId,
                              otherUser: otherUser,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
