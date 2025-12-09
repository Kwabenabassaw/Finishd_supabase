import 'package:finishd/Chat/chatScreen.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/chat_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NewChatListScreen extends StatefulWidget {
  const NewChatListScreen({super.key});

  @override
  State<NewChatListScreen> createState() => _NewChatListScreenState();
}

class _NewChatListScreenState extends State<NewChatListScreen> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
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
      final chatId = await _chatService.createChat(_currentUserId, user.uid);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: chatId, otherUser: user),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'New Chat',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterFriends,
              decoration: const InputDecoration(
                hintText: 'Search for your friends',
                hintStyle: TextStyle(color: Colors.grey),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(15.0)),
                  borderSide: BorderSide(color: Colors.grey),
                ),

                isDense: true,
              ),
            ),
          ),

          // List of Friends/Contacts
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                ? const Center(
                    child: Text(
                      'No friends found. Follow someone to chat!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = _filteredFriends[index];

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundImage: friend.profileImage.isNotEmpty
                              ? NetworkImage(friend.profileImage)
                              : null,
                          child: friend.profileImage.isEmpty
                              ? Text(friend.username[0].toUpperCase())
                              : null,
                        ),
                        title: Text(
                          friend.username,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          friend.bio.isNotEmpty ? friend.bio : 'No bio',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        onTap: () => _startChat(friend),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
