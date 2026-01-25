import 'package:finishd/Chat/chatScreen.dart';
import 'package:finishd/db/objectbox/chat_entities.dart';
import 'package:finishd/provider/chat_provider.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finishd/Widget/user_avatar.dart';
import 'package:provider/provider.dart';

/// Offline-first Chat List Screen.
///
/// Uses ChatProvider to read from ObjectBox (local).
/// Data syncs in background from Firebase.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final UserService _userService = UserService();
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _activeUsers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
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
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final conversations = chatProvider.conversations;

          return RefreshIndicator(
            onRefresh: () => chatProvider.refreshConversations(),
            child: CustomScrollView(
              slivers: [
                // 1. Header & Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Convos",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            // Pending indicator
                            if (chatProvider.pendingCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${chatProvider.pendingCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 15),
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

                // 2. Active Friends
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
                          return _buildFriendAvatar(user, textColor);
                        },
                      ),
                    ),
                  ),
                ],

                // 3. Conversation List
                if (conversations.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('No messages yet')),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final conv = conversations[index];
                      return _ConversationTile(
                        conversation: conv,
                        searchQuery: _searchQuery,
                        chatProvider: chatProvider,
                      );
                    }, childCount: conversations.length),
                  ),

                // 4. Bottom Padding
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFriendAvatar(UserModel user, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GestureDetector(
        onTap: () async {
          final chatProvider = context.read<ChatProvider>();
          final chatId = await chatProvider.getOrCreateConversation(user.uid);

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(chatId: chatId, otherUser: user),
            ),
          );
        },
        child: Column(
          children: [
            UserAvatar(
              radius: 32,
              profileImageUrl: user.profileImage,
              username: user.username,
              firstName: user.firstName,
              lastName: user.lastName,
              userId: user.uid,
            ),
            const SizedBox(height: 8),
            Text(
              user.firstName.isNotEmpty ? user.firstName : user.username,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual conversation tile with user resolution.
class _ConversationTile extends StatelessWidget {
  final LocalConversation conversation;
  final String searchQuery;
  final ChatProvider chatProvider;

  const _ConversationTile({
    required this.conversation,
    required this.searchQuery,
    required this.chatProvider,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return FutureBuilder<UserModel?>(
      future: chatProvider.getOtherUser(conversation),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final otherUser = snapshot.data!;

        // Search filter
        if (searchQuery.isNotEmpty) {
          final name = otherUser.username.toLowerCase();
          final realName = otherUser.firstName.toLowerCase();
          if (!name.contains(searchQuery) && !realName.contains(searchQuery)) {
            return const SizedBox.shrink();
          }
        }

        final isUnread = conversation.unreadCount > 0;
        final timeString = _formatTime(conversation.lastMessageAt);

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: conversation.firestoreId,
                  otherUser: otherUser,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                UserAvatar(
                  radius: 30,
                  profileImageUrl: otherUser.profileImage,
                  username: otherUser.username,
                  firstName: otherUser.firstName,
                  lastName: otherUser.lastName,
                  userId: otherUser.uid,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              color: isUnread ? textColor : Colors.grey,
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
                              conversation.lastMessageText ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUnread ? textColor : Colors.grey[600],
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
  }

  String _formatTime(DateTime? msgTime) {
    if (msgTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(msgTime);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 2) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('E').format(msgTime);
    } else {
      return DateFormat('MMM d').format(msgTime);
    }
  }
}
