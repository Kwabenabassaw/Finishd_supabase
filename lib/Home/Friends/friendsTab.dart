import 'dart:io' show Platform;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/profile/profileScreen.dart';
import 'package:finishd/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<UserModel> _myFriends = []; // Followers
  List<UserModel> _allUsers = []; // Find Friends
  bool _isLoadingFriends = true;
  bool _isLoadingAll = true;
  bool _isLoadingMore = false; // For pagination
  bool _hasMoreUsers = true; // More users to load
  Set<String> _friendIds = {}; // Cache friend IDs for filtering
  final ScrollController _findFriendsScrollController = ScrollController();

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<UserModel> _filteredMyFriends = [];
  List<UserModel> _filteredAllUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchMyFriends();
    _fetchAllUsers();
    _searchController.addListener(_onSearchChanged);

    // Add scroll listener for infinite scroll
    _findFriendsScrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_findFriendsScrollController.position.pixels >=
            _findFriendsScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreUsers &&
        !_isSearching) {
      _loadMoreUsers();
    }
  }

  void _onSearchChanged() {
    _filterUsers(_searchController.text);
  }

  Future<void> _fetchMyFriends() async {
    if (_currentUserId.isEmpty) return;
    try {
      List<String> followerIds = await _userService.getFollowers(
        _currentUserId,
      );
      _friendIds = followerIds.toSet(); // Cache for filtering
      List<UserModel> friends = await _userService.getUsers(followerIds);
      if (mounted) {
        setState(() {
          _myFriends = friends;
          _filteredMyFriends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  Future<void> _fetchAllUsers() async {
    try {
      // Fetch friend IDs first (if not already fetched)
      if (_friendIds.isEmpty) {
        List<String> friendIds = await _userService.getFollowers(
          _currentUserId,
        );
        _friendIds = friendIds.toSet();
      }

      // Use paginated fetch - only get first 50 users
      List<UserModel> users = await _userService.getAllUsers(limit: 50);
      users.removeWhere(
        (user) => user.uid == _currentUserId || _friendIds.contains(user.uid),
      );

      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredAllUsers = users;
          _isLoadingAll = false;
          _hasMoreUsers = users.length >= 50; // Assume more if we got full page
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAll = false;
        });
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMoreUsers) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Fetch next batch starting after current users
      List<UserModel> moreUsers = await _userService.getAllUsers(limit: 50);

      // Filter out self and friends
      moreUsers.removeWhere(
        (user) =>
            user.uid == _currentUserId ||
            _friendIds.contains(user.uid) ||
            _allUsers.any((existing) => existing.uid == user.uid),
      );

      if (mounted) {
        setState(() {
          _allUsers.addAll(moreUsers);
          _filteredAllUsers = _allUsers;
          _isLoadingMore = false;
          _hasMoreUsers =
              moreUsers.length >= 20; // Stop if we got less than expected
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMyFriends = _myFriends;
        _filteredAllUsers = _allUsers;
      });
      return;
    }

    final searchLower = query.toLowerCase();

    setState(() {
      _filteredMyFriends = _myFriends.where((user) {
        final username = user.username.toLowerCase();
        final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
        return username.contains(searchLower) || fullName.contains(searchLower);
      }).toList();

      _filteredAllUsers = _allUsers.where((user) {
        final username = user.username.toLowerCase();
        final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
        return username.contains(searchLower) || fullName.contains(searchLower);
      }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredMyFriends = _myFriends;
        _filteredAllUsers = _allUsers;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _findFriendsScrollController.dispose();
    super.dispose();
  }

  Widget _buildFriendListItem(UserModel user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Hero(
          tag: 'avatar_${user.uid}',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundImage: user.profileImage.isNotEmpty
                  ? CachedNetworkImageProvider(user.profileImage)
                  : const AssetImage('assets/noimage.jpg') as ImageProvider,
              backgroundColor: theme.disabledColor.withOpacity(0.1),
            ),
          ),
        ),
        title: Text(
          user.username.isNotEmpty ? user.username : 'No Name',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.1,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            user.firstName.isNotEmpty || user.lastName.isNotEmpty
                ? '${user.firstName} ${user.lastName}'
                : '@${user.username}',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(uid: user.uid),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryGreen = Color(0xFF10B981);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: _isSearching
            ? null
            : IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: theme.iconTheme.color,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSearching
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'Search people...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: theme.disabledColor,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: TextStyle(
                      color: theme.disabledColor,
                      fontSize: 14,
                    ),
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
              )
            : Text(
                'Friends',
                style: TextStyle(
                  color: theme.textTheme.titleLarge?.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: theme.iconTheme.color,
            ),
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Platform Adaptive Tab Switcher
          Platform.isIOS
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSegmentedControl<int>(
                      groupValue: _tabController.index,
                      selectedColor: primaryGreen,
                      unselectedColor: isDark
                          ? Colors.grey[900]
                          : Colors.grey[100],
                      borderColor: primaryGreen.withOpacity(0.3),
                      children: const {
                        0: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'My Friends',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        1: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Find Friends',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      },
                      onValueChanged: (int value) {
                        setState(() {
                          _tabController.animateTo(value);
                        });
                      },
                    ),
                  ),
                )
              : Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: primaryGreen,
                    indicatorWeight: 3,
                    labelColor: primaryGreen,
                    unselectedLabelColor: theme.disabledColor,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'My Friends'),
                      Tab(text: 'Find Friends'),
                    ],
                  ),
                ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(
                  _isLoadingFriends,
                  _filteredMyFriends,
                  _isSearching && _searchController.text.isNotEmpty
                      ? "No friends found"
                      : "No friends yet",
                  scrollController: null,
                ),
                _buildTabContent(
                  _isLoadingAll,
                  _filteredAllUsers,
                  _isSearching && _searchController.text.isNotEmpty
                      ? "No users found"
                      : "No users to add",
                  scrollController: _findFriendsScrollController,
                  showLoadingMore: _isLoadingMore,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    bool isLoading,
    List<UserModel> users,
    String emptyMessage, {
    ScrollController? scrollController,
    bool showLoadingMore = false,
  }) {
    if (isLoading) {
      return Center(
        child: Platform.isIOS
            ? const CupertinoActivityIndicator()
            : const CircularProgressIndicator(),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: Theme.of(context).disabledColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(context).disabledColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      physics: const BouncingScrollPhysics(),
      itemCount: users.length + (showLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == users.length && showLoadingMore) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Platform.isIOS
                  ? const CupertinoActivityIndicator()
                  : const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          );
        }
        return _buildFriendListItem(users[index]);
      },
    );
  }
}
