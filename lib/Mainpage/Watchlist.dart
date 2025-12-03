import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        appBar: AppBar(title: const Text("Watchlist"), centerTitle: true),
        body: const Center(child: Text("Please log in to view your watchlist")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Watchlist"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.fill,
          indicatorColor: const Color(0xFF1A8927),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Watchlist"),
            Tab(text: "Fav"),
          ],
        ),
      ),
      body: TabBarView(
      
        controller: _tabController,

        children: [_buildWatchlistTab(), _buildSavedTab()],
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
          return const Center(child: CircularProgressIndicator());
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
    padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 80.0),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final posterPath = movie.posterPath ?? '';
        final imageUrl = posterPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w500$posterPath'
            : '';

        return GestureDetector(
          onTap: () async {
            final Trending trendingService = Trending();
            if (movie.mediaType == 'movie') {
              final movieDetails = await trendingService.fetchMovieDetails(
                int.parse(movie.id),
              );
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MovieDetailsScreen(movie: movieDetails),
                  ),
                );
              }
            } else {
              final showDetails = await trendingService.fetchDetailsTvShow(
                int.parse(movie.id),
              );
              if (context.mounted && showDetails != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShowDetailsScreen(movie: showDetails),
                  ),
                );
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Poster Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: posterPath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.movie, size: 60),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.movie, size: 60),
                        ),
                ),
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                // Movie Info
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          movie.mediaType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                           Text(
                          movie.addedAt.toLocal().year.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
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

  // 2-column grid for Saved tab
  Widget _buildMovieGrid(List<MovieListItem> movies) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 320,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.65,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final posterPath = movie.posterPath ?? '';
        final imageUrl = posterPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w500$posterPath'
            : '';

        return GestureDetector(
          onTap: () async {
            final Trending trendingService = Trending();
            if (movie.mediaType == 'movie') {
              final movieDetails = await trendingService.fetchMovieDetails(
                int.parse(movie.id),
              );
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MovieDetailsScreen(movie: movieDetails),
                  ),
                );
              }
            } else {
              final showDetails = await trendingService.fetchDetailsTvShow(
                int.parse(movie.id),
              );
              if (context.mounted && showDetails != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShowDetailsScreen(movie: showDetails),
                  ),
                );
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: posterPath.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.movie, size: 40),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.movie, size: 40),
                          ),
                  ),
                ),
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
