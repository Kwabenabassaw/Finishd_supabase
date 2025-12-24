import 'package:finishd/Chat/chatScreen.dart';
import 'package:finishd/models/chat_model.dart';
import 'package:finishd/services/chat_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _activeUsers = [];
  String _searchQuery = '';

  late Stream<List<Chat>> _chatStream;

  @override
  void initState() {
    super.initState();
    _chatStream = _chatService.getChatListStream(_currentUserId);
    _fetchActiveUsers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveUsers() async {
    if (_currentUserId.isEmpty) return;
    try {
      List<String> followerIds = await _userService.getFollowers(
        _currentUserId,
      );
      if (followerIds.isNotEmpty) {
        List<UserModel> friends = await _userService.getUsers(
          followerIds.take(10).toList(),
        );
        if (mounted) {
          setState(() {
            _activeUsers = friends;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching active users: $e');
    }
  }

  // Helper to fetch other user for a chat
  Future<UserModel?> _getChatUser(Chat chat) async {
    final otherUserId = chat.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) return null;
    return await _userService.getUser(otherUserId);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Center(child: Text('Please log in to see messages'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[500];
    final fillColor = isDark ? Colors.grey[800] : Colors.grey[50];

    return Scaffold(
      // backgroundColor: isDark ? Colors.black : Colors.white, // Let theme handle it
      body: StreamBuilder<List<Chat>>(
        stream: _chatStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data ?? [];

          return CustomScrollView(
            slivers: [
              // 1. Header & Search
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Messages",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_square, color: textColor),
                            onPressed: () {
                              // Action for new message
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search for people...",
                          hintStyle: TextStyle(color: hintColor),
                          prefixIcon: Icon(Icons.search, color: hintColor),
                          filled: true,
                          fillColor: fillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Active Now (Renamed to Badge)
              if (_activeUsers.isNotEmpty && _searchQuery.isEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Text(
                      "Friends",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _activeUsers.length,
                      itemBuilder: (context, index) {
                        final user = _activeUsers[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: GestureDetector(
                            onTap: () async {
                              final chatId = _chatService.getChatId(
                                _currentUserId,
                                user.uid,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatId: chatId,
                                    otherUser: user,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage:
                                          user.profileImage.isNotEmpty
                                          ? NetworkImage(user.profileImage)
                                          : null,
                                      child: user.profileImage.isEmpty
                                          ? Text(
                                              user.username.isNotEmpty
                                                  ? user.username[0]
                                                        .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                color: Colors.black54,
                                              ),
                                            )
                                          : null,
                                    ),
                                    // Removed Green Dot
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user.firstName.isNotEmpty
                                      ? user.firstName
                                      : user.username,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // 3. Chat List with Search Filter
              if (chats.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No messages yet')),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    // We need to resolve users to filter, but doing it in builder is tricky for filtering.
                    // For performance in this step, we will still use FutureBuilder for each item
                    // BUT to support search properly, we blindly render all and hide if not matching?
                    // No, that leaves gaps or empty spaces.
                    // Ideal: fetch all users upfront.
                    // Pragmatic compromise for "Search everyday":
                    // We will use a FutureBuilder that resolves the user, and if it doesn't match search, returns SizedBox.shrink().
                    // Note: This is not efficient for huge lists but acceptable for typical user chat list.

                    final chat = chats[index];

                    return FutureBuilder<UserModel?>(
                      future: _getChatUser(chat),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData)
                          return const SizedBox.shrink();

                        final otherUser = userSnapshot.data!;

                        // SEARCH FILTER LOGIC
                        if (_searchQuery.isNotEmpty) {
                          final name = otherUser.username.toLowerCase();
                          final realName = otherUser.firstName.toLowerCase();
                          if (!name.contains(_searchQuery) &&
                              !realName.contains(_searchQuery)) {
                            return const SizedBox.shrink();
                          }
                        }

                        final unreadCount =
                            chat.unreadCounts[_currentUserId] ?? 0;
                        final isUnread = unreadCount > 0;

                        final now = DateTime.now();
                        final msgTime = chat.lastMessageTime.toDate();
                        final diff = now.difference(msgTime);
                        String timeString = '';

                        if (diff.inMinutes < 60) {
                          timeString = '${diff.inMinutes}m';
                        } else if (diff.inHours < 24) {
                          timeString = '${diff.inHours}h';
                        } else if (diff.inDays < 2) {
                          timeString = 'Yesterday';
                        } else if (diff.inDays < 7) {
                          timeString = DateFormat('E').format(msgTime);
                        } else {
                          timeString = DateFormat('MMM d').format(msgTime);
                        }

                        return InkWell(
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage:
                                      otherUser.profileImage.isNotEmpty
                                      ? NetworkImage(otherUser.profileImage)
                                      : null,
                                  child: otherUser.profileImage.isEmpty
                                      ? Text(
                                          otherUser.username[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            color: Colors.black54,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              otherUser.username,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: textColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            timeString,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isUnread
                                                  ? textColor
                                                  : Colors.grey,
                                              fontWeight: isUnread
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              chat.lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isUnread
                                                    ? textColor
                                                    : Colors.grey[600],
                                                fontSize: 14,
                                                fontWeight: isUnread
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF1A8927),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }, childCount: chats.length),
                ),

              // 4. Bottom Padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
    );
  }
}
