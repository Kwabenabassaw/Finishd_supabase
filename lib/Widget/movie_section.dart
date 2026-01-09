import 'package:finishd/Model/trending.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/Widget/movie_card.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:flutter/material.dart';

class MovieSection extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final Trending movieApi;
  final VoidCallback? onSeeAllTap;

  const MovieSection({
    super.key,
    required this.title,
    required this.items,
    required this.movieApi,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.90 > 160
        ? 135.0
        : screenWidth * 0.35; // Reduced from 160
    final imgHeight = cardWidth * 1.45; // Slightly taller ratio for modern look
    final listHeight =
        imgHeight + 65; // Increased height overhead to prevent overflow

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ), // Consistent horizontal padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12, // Reduced from 22
                  letterSpacing: -0.4,
                ),
              ),
              if (onSeeAllTap != null)
                GestureDetector(
                  onTap: onSeeAllTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          "See All",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8), // Reduced gap

        SizedBox(
          height: listHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              left: 16,
            ), // Added horizontal padding at start
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final genres = movieApi.getGenreNames(item.genreIds);
              final limited = genres.length > 2
                  ? genres.take(2).toList()
                  : genres;

              return GenericMovieCard<MediaItem>(
                item: item,
                titleBuilder: (m) => m.title,
                posterBuilder: (m) =>
                    "https://image.tmdb.org/t/p/w500${m.posterPath}",
                typeBuilder: (m) => limited.join(", "),
                width: cardWidth,
                imageHeight: imgHeight,
                onActionMenuTap: () {
                  // Convert MediaItem to MovieListItem
                  final movieListItem = MovieListItem(
                    id: item.id.toString(),
                    title: item.title,
                    posterPath: item.posterPath,
                    mediaType: item.mediaType,
                    addedAt: DateTime.now(),
                  );

                  // Show action drawer
                  showMovieActionDrawer(context, movieListItem);
                },
                onTap: () {
                  if (item.mediaType == 'tv') {
                    final shallowShow = TvShowDetails.shallowFromMediaItem(
                      item,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ShowDetailsScreen(movie: shallowShow),
                      ),
                    );
                  } else {
                    final shallowMovie = MovieDetails.shallowFromMediaItem(
                      item,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MovieDetailsScreen(movie: shallowMovie),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
