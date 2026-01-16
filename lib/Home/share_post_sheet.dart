import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:provider/provider.dart';
import 'package:finishd/provider/chat_provider.dart';

class SharePostSheet extends StatefulWidget {
  final CommunityPost post;

  const SharePostSheet({super.key, required this.post});

  static void show(BuildContext context, CommunityPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SharePostSheet(post: post),
      ),
    );
  }

  @override
  State<SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends State<SharePostSheet> {
  final UserService _userService = UserService();
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
      if (mounted) setState(() => _isLoading = false);
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

  String get _shareUrl => 'https://finishd.app/post/${widget.post.id}';
  String get _shareText =>
      '📝 ${widget.post.authorName} shared a post in ${widget.post.showTitle ?? 'Community'}\n\n"${widget.post.content}"\n\nCheck it out on FINISHD: $_shareUrl';

  Future<void> _shareToFriends() async {
    if (_selectedUserIds.isEmpty) return;
    setState(() => _isSending = true);

    try {
      for (final userId in _selectedUserIds) {
        final conversationId = _getConversationId(_currentUserId, userId);
        await Provider.of<ChatProvider>(context, listen: false).sendPostLink(
          conversationId: conversationId,
          receiverId: userId,
          postId: widget.post.id,
          postContent: widget.post.content,
          authorName: widget.post.authorName,
          showTitle: widget.post.showTitle ?? 'Community',
          showId: widget.post.showId,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to ${_selectedUserIds.length} friends!'),
            backgroundColor: const Color(0xFF1A8927),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
        setState(() => _isSending = false);
      }
    }
  }

  String _getConversationId(String u1, String u2) {
    return u1.compareTo(u2) <= 0 ? '${u1}_$u2' : '${u2}_$u1';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGreen = const Color(0xFF1A8927);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Share Post',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextButton(
                  onPressed: _selectedUserIds.isNotEmpty && !_isSending
                      ? _shareToFriends
                      : null,
                  style: TextButton.styleFrom(
                    backgroundColor: _selectedUserIds.isNotEmpty
                        ? primaryGreen
                        : theme.dividerColor.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
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
                                : theme.hintColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Post Preview
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: primaryGreen.withOpacity(0.1),
                      child: Text(
                        widget.post.authorName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.post.authorName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' in ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.post.showTitle ?? 'Community',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: Icon(Icons.search, color: theme.hintColor),
                filled: true,
                fillColor: theme.dividerColor.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Friends List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) => _buildFriendTile(
                      _filteredFriends[index],
                      theme,
                      primaryGreen,
                    ),
                  ),
          ),

          // External Share
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildExternalAction(Icons.copy_rounded, 'Copy Link', () {
                  Clipboard.setData(ClipboardData(text: _shareUrl));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Link copied!')));
                }, theme),
                const SizedBox(width: 24),
                _buildExternalAction(Icons.ios_share_rounded, 'More', () {
                  Share.share(
                    _shareText,
                    subject: 'Check out this post on FINISHD',
                  );
                }, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(UserModel user, ThemeData theme, Color primaryGreen) {
    final isSelected = _selectedUserIds.contains(user.uid);
    return ListTile(
      onTap: () {
        setState(() {
          if (isSelected)
            _selectedUserIds.remove(user.uid);
          else
            _selectedUserIds.add(user.uid);
        });
      },
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: user.profileImage.isNotEmpty
                ? CachedNetworkImageProvider(user.profileImage)
                : null,
            child: user.profileImage.isEmpty
                ? Text(user.username[0].toUpperCase())
                : null,
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.check, size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Text(
        user.username,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        '${user.firstName} ${user.lastName}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true)
              _selectedUserIds.add(user.uid);
            else
              _selectedUserIds.remove(user.uid);
          });
        },
        activeColor: primaryGreen,
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _buildExternalAction(
    IconData icon,
    String label,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.dividerColor.withOpacity(0.05),
            child: Icon(icon, color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
