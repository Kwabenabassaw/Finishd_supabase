import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Widget/interactive_media_poster.dart';
import 'package:flutter/material.dart';

class NetflixHero extends StatelessWidget {
  final MediaItem item;

  const NetflixHero({super.key, required this.item});

  // Complete TMDB genre map for both Movies and TV Shows
  static const Map<int, String> _genreMap = {
    // Movie Genres
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Sci-Fi',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
    // TV Genres
    10759: 'Action & Adventure',
    10762: 'Kids',
    10763: 'News',
    10764: 'Reality',
    10765: 'Sci-Fi & Fantasy',
    10766: 'Soap',
    10767: 'Talk',
    10768: 'War & Politics',
  };

  String _getGenreNames() {
    if (item.genreIds.isEmpty) {
      return item.mediaType == 'tv' ? 'TV Series' : 'Movie';
    }

    final names = <String>[];
    for (final id in item.genreIds.take(2)) {
      final name = _genreMap[id];
      if (name != null) {
        names.add(name);
      }
    }

    if (names.isEmpty) {
      return item.mediaType == 'tv' ? 'TV Series' : 'Movie';
    }

    return names.join(' • ');
  }

  String _getMatchPercentage() {
    // Convert vote average (0-10) to a match percentage (50-99)
    final vote = item.voteAverage.clamp(0.0, 10.0);
    final percentage = (50 + (vote * 4.9)).round();
    return '$percentage% Match';
  }

  String _getReleaseYear() {
    if (item.releaseDate.isEmpty) return '';
    try {
      return item.releaseDate.substring(0, 4);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Use theme-aware colors
    final backgroundColor = theme.scaffoldBackgroundColor;
    final primaryColor = colorScheme.primary;

    return Stack(
      children: [
        // Backdrop Image
        InteractiveMediaPoster(
          item: item,
          child: CachedNetworkImage(
            imageUrl: 'https://image.tmdb.org/t/p/original${item.posterPath}',
            height: screenHeight * 0.7,
            width: screenWidth,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: isDark ? Colors.black26 : Colors.grey[200]),
            errorWidget: (context, url, error) =>
                Icon(Icons.error, color: theme.iconTheme.color),
          ),
        ),
        // Gradient overlay
        Container(
          height: screenHeight * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                backgroundColor.withOpacity(0.3),
                Colors.transparent,
                backgroundColor.withOpacity(0.5),
                backgroundColor,
              ],
              stops: const [0.0, 0.4, 0.8, 1.0],
            ),
          ),
        ),
        // Content
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Title treatment
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  item.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Metadata
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_getReleaseYear().isNotEmpty) ...[
                    const SizedBox(width: 15),
                    Text(
                      _getReleaseYear(),
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(width: 15),
                  Text(
                    _getGenreNames(),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      _navigateToDetails(context);
                    },
                    icon: Icon(
                      Icons.play_arrow,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                    label: Text(
                      'Watch Trailer',
                      style: TextStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white10,
                      minimumSize: const Size(160, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToDetails(BuildContext context) {
    if (item.mediaType == 'tv') {
      final shallowShow = TvShowDetails.shallowFromMediaItem(item);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShowDetailsScreen(movie: shallowShow),
        ),
      );
    } else {
      final shallowMovie = MovieDetails.shallowFromMediaItem(item);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailsScreen(movie: shallowMovie),
        ),
      );
    }
  }
}
