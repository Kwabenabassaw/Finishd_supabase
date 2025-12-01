import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/profile/profileScreen.dart';
import 'package:finishd/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<UserModel> _filteredMyFriends = [];
  List<UserModel> _filteredAllUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMyFriends();
    _fetchAllUsers();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _filterUsers(_searchController.text);
  }

  Future<void> _fetchMyFriends() async {
    if (_currentUserId.isEmpty) return;
    try {
      // Assuming "My Friends" means people who follow me, based on user request "users that follows you"
      // Or it could be "Following". Let's stick to "Followers" as per request description.
      List<String> followerIds = await _userService.getFollowers(
        _currentUserId,
      );
      List<UserModel> friends = await _userService.getUsers(followerIds);
      if (mounted) {
        setState(() {
          _myFriends = friends;
          _filteredMyFriends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      print('Error fetching friends: $e');
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  Future<void> _fetchAllUsers() async {
    try {
      // Get current user's friends first to filter them out
      List<String> friendIds = await _userService.getFollowers(_currentUserId);

      // Fetch all users
      List<UserModel> users = await _userService.getAllUsers();

      // Filter out current user AND existing friends
      users.removeWhere(
        (user) => user.uid == _currentUserId || friendIds.contains(user.uid),
      );

      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredAllUsers = users;
          _isLoadingAll = false;
        });
      }
    } catch (e) {
      print('Error fetching all users: $e');
      if (mounted) {
        setState(() {
          _isLoadingAll = false;
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
        final email = user.email.toLowerCase();

        return username.contains(searchLower) ||
            fullName.contains(searchLower) ||
            email.contains(searchLower);
      }).toList();

      _filteredAllUsers = _allUsers.where((user) {
        final username = user.username.toLowerCase();
        final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
        final email = user.email.toLowerCase();

        return username.contains(searchLower) ||
            fullName.contains(searchLower) ||
            email.contains(searchLower);
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
    super.dispose();
  }

  // --- Helper Widget for the Friend List Item ---
  Widget _buildFriendListItem(UserModel user, IconData icon) {
    const Color primaryGreen = Color(0xFF10B981);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      leading: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(uid: user.uid),
            ),
          );
        },
        child: CircleAvatar(
          radius: 28,
          backgroundImage: user.profileImage.isNotEmpty
              ? CachedNetworkImageProvider(user.profileImage)
              : const AssetImage('assets/noimage.jpg') as ImageProvider,
          backgroundColor: Colors.grey.shade200,
        ),
      ),
      title: Text(
        user.username.isNotEmpty ? user.username : 'No Name',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        user.firstName.isNotEmpty || user.lastName.isNotEmpty
            ? '${user.firstName} ${user.lastName}'
            : user.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(uid: user.uid),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: primaryGreen, size: 28),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen(uid: user.uid)),
        );
      },
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: _isSearching
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search friends...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(color: Colors.black),
              )
            : const Text(
                'Friends',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.black,
            ),
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1.0),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3.0,
              tabs: const [
                Tab(text: 'My Friends'),
                Tab(text: 'Find Friends'),
              ],
            ),
          ),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          // Content for 'My Friends' tab
          _isLoadingFriends
              ? const Center(child: CircularProgressIndicator())
              : _filteredMyFriends.isEmpty
              ? Center(
                  child: Text(
                    _isSearching && _searchController.text.isNotEmpty
                        ? "No friends found"
                        : "No friends yet",
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredMyFriends.length,
                  itemBuilder: (context, index) {
                    return _buildFriendListItem(
                      _filteredMyFriends[index],
                      Icons.person,
                    );
                  },
                ),

          // Content for 'Find Friends' tab
          _isLoadingAll
              ? const Center(child: CircularProgressIndicator())
              : _filteredAllUsers.isEmpty
              ? Center(
                  child: Text(
                    _isSearching && _searchController.text.isNotEmpty
                        ? "No users found"
                        : "No users to add",
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredAllUsers.length,
                  itemBuilder: (context, index) {
                    return _buildFriendListItem(
                      _filteredAllUsers[index],
                      Icons.person_add,
                    );
                  },
                ),
        ],
      ),
    );
  }
}
