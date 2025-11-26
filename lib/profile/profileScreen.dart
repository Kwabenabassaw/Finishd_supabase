import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/Model/movie_item.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/profile/MoviePosterGrid.dart';
import 'package:finishd/profile/edit_profile_screen.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Main Profile Screen Widget ---
class ProfileScreen extends StatefulWidget {
  final String uid; // Pass the UID of the user to display

  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  bool _isFollowing = false;
  bool _isCheckingFollow = true;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkFollowStatus();
    // Fetch user preferences if viewing own profile or if needed
    // Ideally UserProvider should already have this if it's the current user
    if (_currentUserId == widget.uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<UserProvider>(
          context,
          listen: false,
        ).fetchCurrentUser(_currentUserId);
      });
    }
  }

  Future<void> _checkFollowStatus() async {
    if (_currentUserId.isEmpty || _currentUserId == widget.uid) {
      setState(() {
        _isCheckingFollow = false;
      });
      return;
    }

    final isFollowing = await _userService.isFollowing(
      _currentUserId,
      widget.uid,
    );
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _isCheckingFollow = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId.isEmpty) return;

    setState(() {
      _isFollowing = !_isFollowing; // Optimistic update
    });

    try {
      if (_isFollowing) {
        await _userService.followUser(_currentUserId, widget.uid);
      } else {
        await _userService.unfollowUser(_currentUserId, widget.uid);
      }
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = _currentUserId == widget.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.black),
              onPressed: () {
                Navigator.pushNamed(context, 'settings');
              },
            ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userService.getUserStream(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final user = snapshot.data;

          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return StreamBuilder<List<MovieListItem>>(
            stream: MovieListService().streamMoviesFromList(
              widget.uid,
              'finished',
            ),
            builder: (context, finishedSnapshot) {
              return StreamBuilder<List<MovieListItem>>(
                stream: MovieListService().streamMoviesFromList(
                  widget.uid,
                  'watching',
                ),
                builder: (context, watchingSnapshot) {
                  return StreamBuilder<List<MovieListItem>>(
                    stream: MovieListService().streamMoviesFromList(
                      widget.uid,
                      'watchlist',
                    ),
                    builder: (context, watchlistSnapshot) {
                      // Convert MovieListItem to MovieItem for the grid
                      final List<MovieItem> finishedMovies =
                          (finishedSnapshot.data ?? [])
                              .map(
                                (item) => MovieItem(
                                  id: int.parse(item.id),
                                  title: item.title,
                                  posterPath: item.posterPath,
                                  mediaType: item.mediaType,
                                  genre: item.mediaType == 'movie'
                                      ? 'Movie'
                                      : 'TV Show',
                                ),
                              )
                              .toList();

                      final List<MovieItem> watchingMovies =
                          (watchingSnapshot.data ?? [])
                              .map(
                                (item) => MovieItem(
                                  id: int.parse(item.id),
                                  title: item.title,
                                  posterPath: item.posterPath,
                                  mediaType: item.mediaType,
                                  genre: item.mediaType == 'movie'
                                      ? 'Movie'
                                      : 'TV Show',
                                ),
                              )
                              .toList();

                      final List<MovieItem> watchLaterMovies =
                          (watchlistSnapshot.data ?? [])
                              .map(
                                (item) => MovieItem(
                                  id: int.parse(item.id),
                                  title: item.title,
                                  posterPath: item.posterPath,
                                  mediaType: item.mediaType,
                                  genre: item.mediaType == 'movie'
                                      ? 'Movie'
                                      : 'TV Show',
                                ),
                              )
                              .toList();

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            // User Avatar
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: user.profileImage.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      user.profileImage,
                                    )
                                  : const AssetImage('assets/noimage.jpg')
                                        as ImageProvider, // Fallback
                              backgroundColor: Colors.grey.shade200,
                            ),
                            const SizedBox(height: 10),
                            // User Name
                            Text(
                              user.username.isNotEmpty
                                  ? user.username
                                  : 'No Name',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // User Email
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Stats Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatColumn(
                                  "Finishd",
                                  finishedMovies.length,
                                ), // Real count from Firebase
                                _buildStatColumn(
                                  "Followers",
                                  user.followersCount,
                                ),
                                _buildStatColumn(
                                  "Following",
                                  user.followingCount,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Edit Profile or Follow Button
                            if (isCurrentUser)
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EditProfileScreen(user: user),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.person_add_alt_1,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Edit Profile',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    3,
                                    130,
                                    7,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 10,
                                  ),
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: _isCheckingFollow
                                    ? null
                                    : _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing
                                      ? Colors.grey.shade300
                                      : const Color.fromARGB(255, 3, 130, 7),
                                  foregroundColor: _isFollowing
                                      ? Colors.black
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 10,
                                  ),
                                ),
                                child: _isCheckingFollow
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isFollowing ? 'Following' : 'Follow',
                                      ),
                              ),
                            const SizedBox(height: 15),

                            // Bio Text
                            if (user.bio.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  user.bio,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 25),

                            // Tabs for content
                            _buildTabBar(),
                            SizedBox(
                              // Adjust height based on content to avoid overflow or empty space
                              height:
                                  MediaQuery.of(context).size.height -
                                  350, // Example adjustment
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  finishedSnapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : MoviePosterGrid(movies: finishedMovies),
                                  watchingSnapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : MoviePosterGrid(movies: watchingMovies),
                                  watchlistSnapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : MoviePosterGrid(
                                          movies: watchLaterMovies,
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- Helper Widgets for ProfileScreen ---

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.black, // Active tab indicator color
        labelColor: Colors.black, // Active tab text color
        unselectedLabelColor: Colors.grey, // Inactive tab text color
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        tabs: const [
          Tab(text: 'Finishd'),
          Tab(text: 'Watching'),
          Tab(text: 'Watch Later'),
        ],
      ),
    );
  }
}
