import 'dart:async';

import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/Model/movie_item.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/profile/MoviePosterGrid.dart';
import 'package:finishd/profile/edit_profile_screen.dart';
import 'package:finishd/profile/user_list_screen.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:finishd/Widget/user_avatar.dart';
import 'package:finishd/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Chat/chatScreen.dart';
import 'package:finishd/services/chat_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:finishd/profile/creator_video_grid.dart'; // Import Creator Grid
import 'package:finishd/Widget/error_dialog.dart';

// --- Main Profile Screen Widget ---
class ProfileScreen extends StatefulWidget {
  final String uid; // Pass the UID of the user to display

  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Use DefaultTabController, so we remove manual TabController

  // FIX Issue 5: Make services class fields instead of creating new instances
  final UserService _userService = UserService();
  final MovieListService _movieListService = MovieListService();

  bool _isFollowing = false;
  bool _isCheckingFollow = true;
  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  // FIX Bug 2: Store follower/following counts in state to avoid redundant calls
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoadingCounts = true;

  // FIX Bug 3: Store movie lists in state instead of nested StreamBuilders
  List<MovieListItem> _finishedMovies = [];
  List<MovieListItem> _watchingMovies = [];
  List<MovieListItem> _watchlistMovies = [];
  bool _isLoadingMovies = true;

  // Stream subscription for unified user titles (single realtime connection)
  StreamSubscription? _titlesSub;

  Stream<UserModel?>? _userStream;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
    _loadFollowCounts();
    _subscribeToMovieLists();

    // Initialize user stream once
    _userStream = _userService.getUserStream(widget.uid);

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

  // Subscribe to all movie lists with a single realtime connection
  void _subscribeToMovieLists() {
    _titlesSub = _movieListService
        .streamAllUserTitlesHybrid(widget.uid)
        .listen(
          (allMovies) {
            if (mounted) {
              setState(() {
                _finishedMovies = allMovies
                    .where((m) => m.status == 'finished')
                    .toList();
                _watchingMovies = allMovies
                    .where((m) => m.status == 'watching')
                    .toList();
                _watchlistMovies = allMovies
                    .where((m) => m.status == 'watchlist')
                    .toList();
                _isLoadingMovies = false;
              });
            }
          },
          onError: (e) {
            debugPrint('Error in movie list stream: $e');
            if (mounted) {
              setState(() => _isLoadingMovies = false);
            }
          },
        );
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
    // Re-initialize user stream to retry connection
    setState(() {
      _userStream = _userService.getUserStream(widget.uid);
      _isLoadingCounts = true;
    });

    await _loadFollowCounts();

    // Force refresh movie lists (bypasses cache)
    try {
      await Future.wait([
        _movieListService.refreshList(widget.uid, 'finished'),
        _movieListService.refreshList(widget.uid, 'watching'),
        _movieListService.refreshList(widget.uid, 'watchlist'),
      ]);
    } catch (e) {
      debugPrint('Error refreshing movie lists: $e');
    }
  }

  void _showErrorPopup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ErrorDialog.show(
        context,
        message: 'Could not load profile. Please check your connection.',
        onRetry: () {
          _refreshProfile();
        },
      );
    });
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
    // Clean up stream subscription
    _titlesSub?.cancel();
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
        stream: _userStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LogoLoadingScreen());
          }

          if (userSnapshot.hasError) {
            _showErrorPopup();
            return const Center(child: LogoLoadingScreen());
          }

          final user = userSnapshot.data;

          if (user == null) {
            _showErrorPopup();
            return const Center(child: LogoLoadingScreen());
          }

          // Determine if Creator
          final isCreator =
              user.role == 'creator' && user.creatorStatus == 'approved';
          final tabCount = isCreator ? 4 : 3;

          return DefaultTabController(
            length: tabCount,
            child: RefreshIndicator(
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
                          UserAvatar(
                            profileImageUrl: user.profileImage,
                            firstName: user.firstName,
                            lastName: user.lastName,
                            username: user.username,
                            userId: user.uid,
                            radius: 50,
                            showBorder: true,
                          ),
                          const SizedBox(height: 10),
                          // User Name + Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                user.username.isNotEmpty
                                    ? '${user.firstName} ${user.lastName}'
                                    : 'No Name',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isCreator) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                          // Username
                          Text(
                            user.username,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Stats Row - Using counts from state (properly loaded)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn(
                                "FinishD",
                                finishedMovieItems.length,
                              ),
                              _buildStatColumn(
                                "Followers",
                                _followersCount,
                                isLoading: _isLoadingCounts,
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
                                _followingCount,
                                isLoading: _isLoadingCounts,
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

                              if (isCreator)
                                // Only show Likes stat if creator (can implement later, stick to design request if it mandates)
                                // Image shows 1.4M Likes. We don't have it yet. Skip or mock?
                                // Let's skip to keep logic clean.
                                Container(),
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
                                          _isFollowing
                                              ? 'Friends'
                                              : 'Add Friend',
                                        ),
                                ),
                                if (_isFollowing) ...[
                                  const SizedBox(width: 5),
                                  IconButton(
                                    onPressed: () async {
                                      final chatService = ChatService();
                                      final chatId = await chatService
                                          .createChat(
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
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ],
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
                                style: const TextStyle(fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 25),

                          // Tabs for content
                          _buildTabBar(isCreator),
                          // FIX Issue 4: Use proportional height instead of magic numbers
                          SizedBox(
                            height: constraints.maxHeight * 0.5,
                            child: TabBarView(
                              children: [
                                _isLoadingMovies
                                    ? const Center(child: LogoLoadingScreen())
                                    : MoviePosterGrid(
                                        movies: finishedMovieItems,
                                      ),

                                if (isCreator)
                                  CreatorVideoGrid(userId: user.uid),

                                _isLoadingMovies
                                    ? const Center(child: LogoLoadingScreen())
                                    : MoviePosterGrid(
                                        movies: watchingMovieItems,
                                      ),
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

  Widget _buildTabBar(bool isCreator) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade700)),
      ),
      child: TabBar(
        indicatorColor: Colors.green.shade900,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        tabs: [
          const Tab(text: 'FinishD'),
          if (isCreator) const Tab(text: 'Clips'),
          const Tab(text: 'Watching'),
          const Tab(text: 'Watch Later'),
        ],
      ),
    );
  }
}
