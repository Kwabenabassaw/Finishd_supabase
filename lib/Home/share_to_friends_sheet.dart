import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/services/chat_service.dart';

/// Share to Friends bottom sheet with friend selection and video preview
/// Similar to Instagram/TikTok share to direct messages
class ShareToFriendsSheet extends StatefulWidget {
  final String videoId;
  final String videoTitle;
  final String videoThumbnail;
  final String videoChannel;

  const ShareToFriendsSheet({
    super.key,
    required this.videoId,
    required this.videoTitle,
    required this.videoThumbnail,
    required this.videoChannel,
  });

  /// Show the share sheet as a bottom modal
  static void show(
    BuildContext context, {
    required String videoId,
    required String videoTitle,
    required String videoThumbnail,
    required String videoChannel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ShareToFriendsSheet(
        videoId: videoId,
        videoTitle: videoTitle,
        videoThumbnail: videoThumbnail,
        videoChannel: videoChannel,
      ),
    );
  }

  @override
  State<ShareToFriendsSheet> createState() => _ShareToFriendsSheetState();
}

class _ShareToFriendsSheetState extends State<ShareToFriendsSheet> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _friends = [];
  List<UserModel> _filteredFriends = [];
  Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFriends() async {
    if (_currentUserId.isEmpty) return;
    try {
      // Get followers as friends
      // Use paginated fetch (limit 100 for share sheet)
      List<String> followerIds = await _userService.getFollowersPaginated(
        _currentUserId,
        limit: 100,
      );
      // Use cached profiles
      List<UserModel> friends = await _userService.getUsersCached(followerIds);

      if (mounted) {
        setState(() {
          _friends = friends;
          _filteredFriends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching friends: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((user) {
          return user.username.toLowerCase().contains(query) ||
              user.firstName.toLowerCase().contains(query) ||
              user.lastName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _sendVideoToFriends() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isSending = true);

    try {
      // Send video link to each selected friend
      for (final userId in _selectedUserIds) {
        final chatId = await _chatService.createChat(_currentUserId, userId);
        await _chatService.sendVideoLink(
          chatId: chatId,
          senderId: _currentUserId,
          receiverId: userId,
          videoId: widget.videoId,
          videoTitle: widget.videoTitle,
          videoThumbnail: widget.videoThumbnail,
          videoChannel: widget.videoChannel,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sent to ${_selectedUserIds.length} friend${_selectedUserIds.length > 1 ? 's' : ''}!',
            ),
            backgroundColor: const Color(0xFF1A8927),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending video: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2)),
          ),
          // Header with title and send button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Send to',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _selectedUserIds.isNotEmpty && !_isSending
                      ? _sendVideoToFriends
                      : null,
                  style: TextButton.styleFrom(
                    backgroundColor: _selectedUserIds.isNotEmpty
                        ? const Color(0xFF1A8927)
                        : Colors.grey[300],
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
                          _selectedUserIds.isEmpty
                              ? 'Send'
                              : 'Send (${_selectedUserIds.length})',
                          style: TextStyle(
                            color: _selectedUserIds.isNotEmpty
                                ? Colors.white
                                : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Video preview card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.videoThumbnail.isNotEmpty
                        ? widget.videoThumbnail
                        : 'https://img.youtube.com/vi/${widget.videoId}/mqdefault.jpg',
                    width: 80,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 80, height: 50),
                    errorWidget: (_, __, ___) => Container(
                      width: 80,
                      height: 50,

                      child: const Icon(Icons.movie),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and channel
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.videoTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.videoChannel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.videoChannel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',

                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Friends list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) {
                      return _buildFriendTile(_filteredFriends[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isNotEmpty
                ? 'No friends found'
                : 'No friends yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try a different search'
                : 'Add friends to share videos!',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(UserModel user) {
    final isSelected = _selectedUserIds.contains(user.uid);

    return ListTile(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedUserIds.remove(user.uid);
          } else {
            _selectedUserIds.add(user.uid);
          }
        });
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,

            backgroundImage: user.profileImage.isNotEmpty
                ? CachedNetworkImageProvider(user.profileImage)
                : null,
            child: user.profileImage.isEmpty
                ? Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          if (isSelected)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A8927),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, size: 12),
              ),
            ),
        ],
      ),
      title: Text(
        user.username.isNotEmpty ? user.username : 'User',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: user.firstName.isNotEmpty
          ? Text(
              '${user.firstName} ${user.lastName}',
              style: TextStyle(fontSize: 13),
            )
          : null,
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A8927) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF1A8927) : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
