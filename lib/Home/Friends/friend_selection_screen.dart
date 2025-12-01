import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/services/user_service.dart';

class FriendSelectionScreen extends StatefulWidget {
  final MovieListItem movie;

  const FriendSelectionScreen({super.key, required this.movie});

  @override
  State<FriendSelectionScreen> createState() => _FriendSelectionScreenState();
}

class _FriendSelectionScreenState extends State<FriendSelectionScreen> {
  final UserService _userService = UserService();
  final RecommendationService _recommendationService = RecommendationService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<UserModel> _friends = [];
  Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    if (_currentUserId.isEmpty) return;
    try {
      // Fetching followers as "friends" for now, consistent with FriendsTab
      List<String> followerIds = await _userService.getFollowers(
        _currentUserId,
      );
      List<UserModel> friends = await _userService.getUsers(followerIds);

      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching friends: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendRecommendation() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _recommendationService.sendRecommendation(
        fromUserId: _currentUserId,
        toUserIds: _selectedUserIds.toList(),
        movie: widget.movie,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Recommendation sent!')));
        Navigator.pop(context); // Close screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending recommendation: $e')),
        );
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommend to...'),
        actions: [
          TextButton(
            onPressed: _selectedUserIds.isNotEmpty && !_isSending
                ? _sendRecommendation
                : null,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Send',
                    style: TextStyle(
                      color: _selectedUserIds.isNotEmpty
                          ? const Color(0xFF1A8927)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
          ? const Center(child: Text('No friends found to recommend to.'))
          : ListView.builder(
              itemCount: _friends.length,
              itemBuilder: (context, index) {
                final user = _friends[index];
                final isSelected = _selectedUserIds.contains(user.uid);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.profileImage.isNotEmpty
                        ? CachedNetworkImageProvider(user.profileImage)
                        : const AssetImage('assets/noimage.jpg')
                              as ImageProvider,
                  ),
                  title: Text(
                    user.username.isNotEmpty ? user.username : 'User',
                  ),
                  subtitle: Text(
                    user.firstName.isNotEmpty
                        ? '${user.firstName} ${user.lastName}'
                        : '',
                  ),
                  trailing: Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF1A8927),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedUserIds.add(user.uid);
                        } else {
                          _selectedUserIds.remove(user.uid);
                        }
                      });
                    },
                  ),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedUserIds.remove(user.uid);
                      } else {
                        _selectedUserIds.add(user.uid);
                      }
                    });
                  },
                );
              },
            ),
    );
  }
}
