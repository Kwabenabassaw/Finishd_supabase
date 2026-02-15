import 'package:finishd/Chat/chatScreen.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/provider/chat_provider.dart';
import 'package:finishd/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class NewChatListScreen extends StatefulWidget {
  const NewChatListScreen({super.key});

  @override
  State<NewChatListScreen> createState() => _NewChatListScreenState();
}

class _NewChatListScreenState extends State<NewChatListScreen> {
  final UserService _userService = UserService();
  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _allFriends = [];
  List<UserModel> _filteredFriends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    if (_currentUserId.isEmpty) return;

    try {
      // Fetch following list as "friends"
      final followingIds = await _userService.getFollowing(_currentUserId);
      if (followingIds.isNotEmpty) {
        final users = await _userService.getUsers(followingIds);
        setState(() {
          _allFriends = users;
          _filteredFriends = users;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching friends: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _allFriends;
      } else {
        _filteredFriends = _allFriends
            .where(
              (user) =>
                  user.username.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  Future<void> _startChat(UserModel user) async {
    try {
      final chatProvider = context.read<ChatProvider>();
      final chatId = await chatProvider.getOrCreateConversation(user.uid);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: chatId, otherUser: user),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor =
        (isDark ? Colors.grey[400] : Colors.grey[500]) ?? Colors.grey;
    final fillColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "New Chat",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: Column(
        children: [
          // Modern Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: _filterFriends,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Search for friends...",
                hintStyle: TextStyle(color: hintColor),
                prefixIcon: Icon(Icons.search, color: hintColor),
                filled: true,
                fillColor: fillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // List Header
          if (!_isLoading && _filteredFriends.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "FOLLOWING",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: hintColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A8927)),
                  )
                : _filteredFriends.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10),
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = _filteredFriends[index];
                      return _buildUserItem(friend, textColor, hintColor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(UserModel user, Color textColor, Color hintColor) {
    return InkWell(
      onTap: () => _startChat(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[200]!,
                  backgroundImage: user.profileImage.isNotEmpty
                      ? NetworkImage(user.profileImage)
                      : null,
                  child: user.profileImage.isEmpty
                      ? Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.black54,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.firstName.isNotEmpty ? user.firstName : "User",
                    style: TextStyle(fontSize: 14, color: hintColor),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A8927).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.message_outlined,
                color: Color(0xFF1A8927),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300]!,
          ),
          const SizedBox(height: 15),
          Text(
            "No friends found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Follow someone to start a conversation",
            style: TextStyle(color: Colors.grey[500]!),
          ),
        ],
      ),
    );
  }
}
