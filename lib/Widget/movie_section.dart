import 'package:finishd/Model/trending.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/Widget/movie_card.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finishd/provider/MovieProvider.dart';

class MovieSection extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final Trending movieApi;

  const MovieSection({
    super.key,
    required this.title,
    required this.items,
    required this.movieApi,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.35 > 160 ? 160.0 : screenWidth * 0.35;
    final imgHeight = cardWidth * 1.5;
    final listHeight =
        imgHeight + 60; // Image + spacing + 2 lines of text + padding

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: listHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
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
                onTap: () async {
                  /*
                  final provider = Provider.of<MovieProvider>(
                    context,
                    listen: false,
                  );
                  provider.selectItem(items, index);
                  */

                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    if (item.mediaType == 'tv') {
                      // Fetch full TV show details
                      final tvDetails = await movieApi.fetchDetailsTvShow(
                        item.id,
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
                      final movieDetails = await movieApi.fetchMovieDetails(
                        item.id,
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
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
