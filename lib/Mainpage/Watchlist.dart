import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:finishd/Widget/interactive_media_poster.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:finishd/theme/app_theme.dart';

class Watchlist extends StatefulWidget {
  const Watchlist({super.key});

  @override
  State<Watchlist> createState() => _WatchlistState();
}

class _WatchlistState extends State<Watchlist>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MovieListService _movieListService = MovieListService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Saved"), centerTitle: true),
        body: const Center(child: Text("Please log in to view your watchlist")),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isIOS = Platform.isIOS;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: isIOS
            ? _buildCustomSegmentedControl(isDark)
            : Text(
                "Saved",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
        bottom: !isIOS
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryGreen,
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: "Watchlist"),
                  Tab(text: "Favorites"),
                ],
              )
            : null,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildWatchlistTab(), _buildSavedTab()],
      ),
    );
  }

  Widget _buildCustomSegmentedControl(bool isDark) {
    return Container(
      height: 40,
      width: 220,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 108,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _tabController.animateTo(0),
                  child: Center(
                    child: Text(
                      "Watchlist",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _selectedIndex == 0
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _tabController.animateTo(1),
                  child: Center(
                    child: Text(
                      "Favorites",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _selectedIndex == 1
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistTab() {
    return StreamBuilder<List<MovieListItem>>(
      stream: _movieListService.streamMoviesFromList(
        _currentUserId,
        'watchlist',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final movies = snapshot.data ?? [];

        if (movies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.watch_later_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No movies in watchlist',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add movies you want to watch later',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return _buildFullWidthList(movies);
      },
    );
  }

  Widget _buildSavedTab() {
    return StreamBuilder<List<MovieListItem>>(
      stream: _movieListService.streamMoviesFromList(
        _currentUserId,
        'favorites',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child:LogoLoadingScreen());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final movies = snapshot.data ?? [];

        if (movies.isEmpty) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 180.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No saved favorites',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save your favorite movies and shows',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return _buildMovieGrid(movies);
      },
    );
  }

  // Full-width list for Watchlist tab
  Widget _buildFullWidthList(List<MovieListItem> movies) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
      physics: const BouncingScrollPhysics(),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final posterPath = movie.posterPath ?? '';
        final imageUrl = posterPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w780$posterPath'
            : '';

        return GestureDetector(
          onTap: () {
            if (movie.mediaType == 'movie') {
              final shallowMovie = MovieDetails.shallowFromListItem(movie);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailsScreen(movie: shallowMovie),
                ),
              );
            } else {
              final shallowShow = TvShowDetails.shallowFromListItem(movie);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShowDetailsScreen(movie: shallowShow),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            height: 480,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Poster Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: posterPath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[900],
                            child: const Center(
                              child:LogoLoadingScreen(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[850],
                            child: const Icon(
                              Icons.movie_filter_rounded,
                              size: 60,
                              color: Colors.white24,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[850],
                          child: const Icon(
                            Icons.movie_filter_rounded,
                            size: 60,
                            color: Colors.white24,
                          ),
                        ),
                ),
                // Gradient Overlays
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.0, 0.2, 0.6, 1.0],
                    ),
                  ),
                ),
                // Media Type Badge
                Positioned(
                  top: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          movie.mediaType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Movie Info
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              movie.addedAt.year.toString(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (movie.genre.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Container(
                                width: 1,
                                height: 12,
                                color: Colors.white24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  movie.genre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovieGrid(List<MovieListItem> movies) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 280,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final posterPath = movie.posterPath ?? '';
        final imageUrl = posterPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w500$posterPath'
            : '';

        return GestureDetector(
          onTap: () {
            if (movie.mediaType == 'movie') {
              final shallowMovie = MovieDetails.shallowFromListItem(movie);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailsScreen(movie: shallowMovie),
                ),
              );
            } else {
              final shallowShow = TvShowDetails.shallowFromListItem(movie);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShowDetailsScreen(movie: shallowShow),
                ),
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InteractiveMediaPoster(
                  item: MediaItem(
                    id: int.tryParse(movie.id) ?? 0,
                    title: movie.title,
                    posterPath: posterPath,
                    mediaType: movie.mediaType,
                    overview: '',
                    backdropPath: '',
                    voteAverage: 0.0,
                    releaseDate: '',
                    genreIds: [],
                    imageUrl: '',
                  ),
                  showSocialBadges: true,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: posterPath.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[900],
                                child: const Center(
                                  child: LogoLoadingScreen(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[850],
                                child: const Icon(
                                  Icons.movie_filter_rounded,
                                  size: 40,
                                  color: Colors.white24,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[850],
                              child: const Icon(
                                Icons.movie_filter_rounded,
                                size: 40,
                                color: Colors.white24,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              if (movie.genre.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    movie.genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.5)
                          : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
