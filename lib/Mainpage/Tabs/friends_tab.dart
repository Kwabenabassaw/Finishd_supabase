import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/Widget/user_avatar.dart';
import 'package:finishd/profile/profileScreen.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Chat/chatScreen.dart';
import 'package:finishd/services/chat_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final UserService _userService = UserService();
  final String _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  bool _isLoading = false;
  bool _isSearching = false;
  
  List<UserModel> _searchResults = [];
  List<UserModel> _followingUsers = [];
  List<UserModel> _suggestedUsers = []; // Can be extended later
  
  // Follow State Map: { userId: isFollowing }
  final Map<String, bool> _followState = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_currentUserId.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Load users the current user is following
      final followingIds = await _userService.getFollowingCached(_currentUserId);
      final followingUsers = await _userService.getUsersCached(followingIds);
      
      // Load suggestions (for now, just fetching some random users, could be refined)
      final allUsers = await _userService.getAllUsers(limit: 20);
      
      final suggested = allUsers.where((u) => 
        u.uid != _currentUserId && !followingIds.contains(u.uid)
      ).take(5).toList();

      setState(() {
        _followingUsers = followingUsers;
        _suggestedUsers = suggested;
        
        // Initialize follow state
        for (var uid in followingIds) {
          _followState[uid] = true;
        }
      });
    } catch (e) {
      debugPrint('Error loading friends data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
        return;
      }

      setState(() {
        _isSearching = true;
        _isLoading = true;
      });

      try {
        final normalizedQuery = query.trim().replaceAll('@', '');
        final results = await _userService.searchUsers(normalizedQuery);
        // Remove self from results
        results.removeWhere((u) => u.uid == _currentUserId);
        
        // Ensure follow states are populated for search results
        for (var user in results) {
          if (!_followState.containsKey(user.uid)) {
            final isFollowing = await _userService.isFollowing(_currentUserId, user.uid);
            _followState[user.uid] = isFollowing;
          }
        }
        
        if (mounted) {
          setState(() {
            _searchResults = results;
          });
        }
      } catch (e) {
        debugPrint('Search error: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _toggleFollow(String targetUid) async {
    if (_currentUserId.isEmpty) return;

    final isCurrentlyFollowing = _followState[targetUid] ?? false;
    
    // Optimistic UI update
    setState(() {
      _followState[targetUid] = !isCurrentlyFollowing;
    });

    try {
      if (isCurrentlyFollowing) {
        await _userService.unfollowUser(_currentUserId, targetUid);
      } else {
        await _userService.followUser(_currentUserId, targetUid);
      }
      
      // Refresh background data silently
      final newFollowingIds = await _userService.getFollowing(_currentUserId);
      final newFollowingUsers = await _userService.getUsers(newFollowingIds);
      if (mounted) {
        setState(() {
          _followingUsers = newFollowingUsers;
        });
      }
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _followState[targetUid] = isCurrentlyFollowing;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update follow status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search friends or username...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Main Content
            Expanded(
              child: _isLoading && !_isSearching && _followingUsers.isEmpty && _suggestedUsers.isEmpty
                  ? const Center(child: LogoLoadingScreen())
                  : RefreshIndicator(
                      onRefresh: _loadInitialData,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (_isSearching)
                            _buildSection('Search Results', _searchResults, isDark)
                          else ...[
                            if (_suggestedUsers.isNotEmpty)
                              _buildSection('Suggested Friends', _suggestedUsers, isDark),
                            _buildSection('Your Friends', _followingUsers, isDark),
                          ]
                        ],
                      ),
                    ),
            ),
          ],
        ),
    );
  }

  Widget _buildSection(String title, List<UserModel> users, bool isDark) {
    if (users.isEmpty) {
      if (title == 'Your Friends' || title == 'Suggested Friends') {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'No users found',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isFollowing = _followState[user.uid] ?? false;

              return ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(uid: user.uid),
                    ),
                  );
                },
                leading: UserAvatar(
                  profileImageUrl: user.profileImage,
                  firstName: user.firstName,
                  lastName: user.lastName,
                  username: user.username,
                  userId: user.uid,
                  radius: 22,
                ),
                title: Text(
                  user.username.isNotEmpty ? '${user.firstName} ${user.lastName}' : 'No Name',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text(
                  '@${user.username}',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFollowing) ...[
                      IconButton(
                        onPressed: () async {
                          final chatService = ChatService();
                          final chatId = await chatService.createChat(
                            _currentUserId,
                            user.uid,
                          );
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatId: chatId,
                                  otherUser: user,
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          FontAwesomeIcons.message,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ],
                    SizedBox(
                      width: 90,
                      child: ElevatedButton(
                        onPressed: () => _toggleFollow(user.uid),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? (isDark ? Colors.grey[800] : Colors.grey[300])
                              : const Color.fromARGB(255, 3, 130, 7),
                          foregroundColor: isFollowing
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          minimumSize: const Size(80, 32),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
