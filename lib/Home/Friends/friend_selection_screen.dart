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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recommended to ${_selectedUserIds.length} friend${_selectedUserIds.length > 1 ? 's' : ''}!',
            ),
            backgroundColor: const Color(0xFF1A8927),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommend to...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_selectedUserIds.isNotEmpty)
              Text(
                '${_selectedUserIds.length} selected',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _selectedUserIds.isNotEmpty && !_isSending
                  ? _sendRecommendation
                  : null,
              style: TextButton.styleFrom(
                backgroundColor: _selectedUserIds.isNotEmpty
                    ? const Color(0xFF1A8927)
                    : Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Send',
                      style: TextStyle(
                        color: _selectedUserIds.isNotEmpty
                            ? Colors.white
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No friends found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add friends to share recommendations',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Movie preview card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.movie.posterPath != null
                              ? 'https://image.tmdb.org/t/p/w200${widget.movie.posterPath}'
                              : 'https://via.placeholder.com/60x90',
                          width: 50,
                          height: 75,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.movie.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.movie.mediaType == 'movie'
                                  ? 'Movie'
                                  : 'TV Show',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Friends grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final user = _friends[index];
                      final isSelected = _selectedUserIds.contains(user.uid);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedUserIds.remove(user.uid);
                            } else {
                              _selectedUserIds.add(user.uid);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1A8927)
                                  : Colors.grey.shade200,
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? const Color(0xFF1A8927).withOpacity(0.2)
                                    : Colors.black.withOpacity(0.05),
                                blurRadius: isSelected ? 12 : 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Profile image with selection overlay
                                    Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        Center(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF1A8927)
                                                    : Colors.grey.shade300,
                                                width: 3,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 40,
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              backgroundImage:
                                                  user.profileImage.isNotEmpty
                                                  ? CachedNetworkImageProvider(
                                                      user.profileImage,
                                                    )
                                                  : const AssetImage(
                                                          'assets/noimage.jpg',
                                                        )
                                                        as ImageProvider,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            width: 86,
                                            height: 86,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(
                                                0xFF1A8927,
                                              ).withOpacity(0.3),
                                            ),
                                            child: const Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Username
                                    Text(
                                      user.username.isNotEmpty
                                          ? user.username
                                          : 'User',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFF1A8927)
                                            : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    // Full name
                                    if (user.firstName.isNotEmpty)
                                      Text(
                                        '${user.firstName} ${user.lastName}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                  ],
                                ),
                              ),
                              // Selection checkmark badge
                              if (isSelected)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1A8927),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
