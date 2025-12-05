import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/trending.dart';
import 'package:provider/provider.dart';

class MovieBannerWidget extends StatelessWidget {
  final MediaItem movie;
  final List<String> genere;
  final VoidCallback onWatchTrailerPressed;

  MovieBannerWidget({
    super.key,
    required this.movie,
    required this.genere,
    required this.onWatchTrailerPressed,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie.backdropPath != null
        ? "https://image.tmdb.org/t/p/w780${movie.backdropPath}"
        : "https://image.tmdb.org/t/p/w500${movie.posterPath}";

    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title ?? "",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  genere.take(2).join(" • "),
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),

                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: onWatchTrailerPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: Text("Watch Trailer"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BannerCarousel extends StatefulWidget {
  final List<MediaItem> movies;
  final Trending movieApi;

  const BannerCarousel({
    super.key,
    required this.movies,
    required this.movieApi,
  });

  @override
  _BannerCarouselState createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1);
    _autoScroll();
  }

  void _autoScroll() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      _currentIndex = (_currentIndex + 1) % widget.movies.length;
      _controller.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MovieProvider>(context, listen: false);
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.movies.length,
        itemBuilder: (context, index) {
          final movie = widget.movies[index];
          final genres = widget.movieApi.getGenreNames(movie.genreIds);
          return MovieBannerWidget(
            movie: movie,
            genere: genres.take(2).toList(),
            onWatchTrailerPressed: () async {
              /*
               provider.selectItem(provider.movies, index);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GenericDetailsScreen(),
                                  ),
                                );
                */
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: LogoLoadingScreen()),
              );

              try {
                if (movie.mediaType == 'tv') {
                  // Fetch full TV show details
                  final tvDetails = await widget.movieApi.fetchDetailsTvShow(
                    movie.id,
                  );

                  // Close loading indicator
                  if (context.mounted) Navigator.pop(context);

                  if (tvDetails != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ShowDetailsScreen(movie: tvDetails),
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to load TV show details'),
                      ),
                    );
                  }
                } else {
                  // Default to movie
                  // Fetch full movie details
                  final movieDetails = await widget.movieApi.fetchMovieDetails(
                    movie.id,
                  );

                  // Close loading indicator
                  if (context.mounted) Navigator.pop(context);

                  // Navigate to details screen
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MovieDetailsScreen(movie: movieDetails),
                      ),
                    );
                  }
                }
              } catch (e) {
                // Close loading indicator
                if (context.mounted) Navigator.pop(context);

                // Show error
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load details: $e')),
                  );
                }
              }
            },
          );
        },
      ),
    );
  }
}
