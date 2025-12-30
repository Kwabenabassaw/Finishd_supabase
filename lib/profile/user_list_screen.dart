import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/profile/profileScreen.dart';
import 'package:finishd/services/user_service.dart';
import 'package:flutter/material.dart';

class UserListScreen extends StatefulWidget {
  final String title;
  final String uid;
  final bool isFollowers; // true for Followers, false for Following

  const UserListScreen({
    super.key,
    required this.title,
    required this.uid,
    required this.isFollowers,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final UserService _userService = UserService();
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      List<String> userIds = [];
      if (widget.isFollowers) {
        userIds = await _userService.getFollowers(widget.uid);
      } else {
        userIds = await _userService.getFollowing(widget.uid);
      }

      // Use optimized parallel fetching instead of sequential loop
      final loadedUsers = await _userService.getUsers(userIds);

      if (mounted) {
        setState(() {
          _users = loadedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? Center(
              child: Text(
                'No users found',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.profileImage.isNotEmpty
                        ? CachedNetworkImageProvider(user.profileImage)
                        : const AssetImage('assets/noimage.jpg')
                              as ImageProvider,
                    backgroundColor: Colors.grey.shade200,
                  ),
                  title: Text(
                    user.username.isNotEmpty ? user.username : 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    user.firstName.isNotEmpty || user.lastName.isNotEmpty
                        ? '${user.firstName} ${user.lastName}'
                        : '@${user.username}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(uid: user.uid),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
