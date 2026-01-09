import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/Model/movie_item.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/profile/MoviePosterGrid.dart';
import 'package:finishd/profile/edit_profile_screen.dart';
import 'package:finishd/profile/user_list_screen.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Chat/chatScreen.dart';
import 'package:finishd/services/chat_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  // FIX Issue 5: Make services class fields instead of creating new instances
  final UserService _userService = UserService();
  final MovieListService _movieListService = MovieListService();

  bool _isFollowing = false;
  bool _isCheckingFollow = true;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // FIX Bug 2: Store follower/following counts in state to avoid redundant calls
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoadingCounts = true;

  // FIX Bug 3: Store movie lists in state instead of nested StreamBuilders
  List<MovieListItem> _finishedMovies = [];
  List<MovieListItem> _watchingMovies = [];
  List<MovieListItem> _watchlistMovies = [];
  bool _isLoadingMovies = true;

  // Stream subscriptions for cleanup
  StreamSubscription? _finishedSub;
  StreamSubscription? _watchingSub;
  StreamSubscription? _watchlistSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkFollowStatus();
    _loadFollowCounts();
    _subscribeToMovieLists();

    // Fetch user preferences if viewing own profile
    if (_currentUserId == widget.uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<UserProvider>(
          context,
          listen: false,
        ).fetchCurrentUser(_currentUserId);
      });
    }
  }

  // FIX Bug 3: Subscribe to all movie lists with single state update
  void _subscribeToMovieLists() {
    _finishedSub = _movieListService
        .streamMoviesFromList(widget.uid, 'finished')
        .listen((movies) {
          if (mounted) {
            setState(() {
              _finishedMovies = movies;
              _isLoadingMovies = false;
            });
          }
        });

    _watchingSub = _movieListService
        .streamMoviesFromList(widget.uid, 'watching')
        .listen((movies) {
          if (mounted) {
            setState(() {
              _watchingMovies = movies;
              _isLoadingMovies = false;
            });
          }
        });

    _watchlistSub = _movieListService
        .streamMoviesFromList(widget.uid, 'watchlist')
        .listen((movies) {
          if (mounted) {
            setState(() {
              _watchlistMovies = movies;
              _isLoadingMovies = false;
            });
          }
        });
  }

  // FIX Bug 2: Load follower/following counts once
  Future<void> _loadFollowCounts() async {
    try {
      final results = await Future.wait([
        _userService.getFollowersCount(widget.uid),
        _userService.getFollowingCount(widget.uid),
      ]);
      if (mounted) {
        setState(() {
          _followersCount = results[0];
          _followingCount = results[1];
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading follow counts: $e');
      if (mounted) {
        setState(() => _isLoadingCounts = false);
      }
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

    // Store previous state for rollback
    final wasFollowing = _isFollowing;
    final previousFollowersCount = _followersCount;

    setState(() {
      _isFollowing = !_isFollowing; // Optimistic update
      _followersCount += _isFollowing ? 1 : -1;
    });

    try {
      if (_isFollowing) {
        await _userService.followUser(_currentUserId, widget.uid);
      } else {
        await _userService.unfollowUser(_currentUserId, widget.uid);
      }
    } catch (e) {
      // FIX Issue 8: Improved error handling with user-friendly message
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _followersCount = previousFollowersCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not update follow status. Please try again.',
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        debugPrint('Follow toggle error: $e');
      }
    }
  }

  // FIX Issue 6: Proper refresh that reloads data
  Future<void> _refreshProfile() async {
    setState(() => _isLoadingCounts = true);
    await _loadFollowCounts();
  }

  // FIX Bug 1: Safe conversion from MovieListItem to MovieItem
  MovieItem? _convertToMovieItem(MovieListItem item) {
    final id = int.tryParse(item.id);
    if (id == null) {
      debugPrint('Warning: Could not parse movie ID: ${item.id}');
      return null;
    }
    return MovieItem(
      id: id,
      title: item.title,
      posterPath: item.posterPath,
      mediaType: item.mediaType,
      genre: item.mediaType == 'movie' ? 'Movie' : 'TV Show',
    );
  }

  List<MovieItem> _convertMovieList(List<MovieListItem> items) {
    return items.map(_convertToMovieItem).whereType<MovieItem>().toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Clean up stream subscriptions
    _finishedSub?.cancel();
    _watchingSub?.cancel();
    _watchlistSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = _currentUserId == widget.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Convert movie lists using safe parsing
    final finishedMovieItems = _convertMovieList(_finishedMovies);
    final watchingMovieItems = _convertMovieList(_watchingMovies);
    final watchlistMovieItems = _convertMovieList(_watchlistMovies);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: Icon(
                Icons.settings,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () {
                Navigator.pushNamed(context, 'settings');
              },
            ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userService.getUserStream(widget.uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LogoLoadingScreen());
          }

          if (userSnapshot.hasError) {
            return Center(child: Text('Error loading profile'));
          }

          final user = userSnapshot.data;

          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return RefreshIndicator(
            onRefresh: _refreshProfile,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // User Avatar - FIX Issue 7: Null-safe image check
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: user.profileImage.isNotEmpty
                              ? CachedNetworkImageProvider(user.profileImage)
                              : const AssetImage('assets/noimage.jpg')
                                    as ImageProvider,
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 10),
                        // User Name
                        Text(
                          user.username.isNotEmpty ? user.username : 'No Name',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // First Name
                        Text(
                          user.firstName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Stats Row - Now using counts from user document
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatColumn(
                              "FinishD",
                              finishedMovieItems.length,
                            ),
                            _buildStatColumn(
                              "Followers",
                              user.followersCount,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserListScreen(
                                      title: 'Followers',
                                      uid: widget.uid,
                                      isFollowers: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildStatColumn(
                              "Following",
                              user.followingCount,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserListScreen(
                                      title: 'Following',
                                      uid: widget.uid,
                                      isFollowers: false,
                                    ),
                                  ),
                                );
                              },
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
                              fixedSize: const Size(200, 40),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                                        width: 25,
                                        height: 20,
                                        child: LogoLoadingScreen(),
                                      )
                                    : Text(
                                        _isFollowing ? 'Friends' : 'Add Friend',
                                      ),
                              ),
                              if (_isFollowing) ...[
                                const SizedBox(width: 5),
                                IconButton(
                                  onPressed: () async {
                                    final chatService = ChatService();
                                    final chatId = await chatService.createChat(
                                      _currentUserId,
                                      widget.uid,
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
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        const SizedBox(height: 15),

                        // Bio Text
                        if (user.bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              user.bio,
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 25),

                        // Tabs for content
                        _buildTabBar(),
                        // FIX Issue 4: Use proportional height instead of magic numbers
                        SizedBox(
                          height: constraints.maxHeight * 0.5,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _isLoadingMovies
                                  ? const Center(child: LogoLoadingScreen())
                                  : MoviePosterGrid(movies: finishedMovieItems),
                              _isLoadingMovies
                                  ? const Center(child: LogoLoadingScreen())
                                  : MoviePosterGrid(movies: watchingMovieItems),
                              _isLoadingMovies
                                  ? const Center(child: LogoLoadingScreen())
                                  : MoviePosterGrid(
                                      movies: watchlistMovieItems,
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    int count, {
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade700)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.green.shade900,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        tabs: const [
          Tab(text: 'FinishD'),
          Tab(text: 'Watching'),
          Tab(text: 'Watch Later'),
        ],
      ),
    );
  }
}
