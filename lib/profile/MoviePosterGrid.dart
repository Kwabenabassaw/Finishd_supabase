import 'package:finishd/Model/movie_item.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';

class MoviePosterGrid extends StatelessWidget {
  final List<MovieItem> movies; // Expects a list of MovieItem

  const MoviePosterGrid({super.key, required this.movies});

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30.0),
          child: Text(
            'No movies found in this list.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20.0),
       
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns as per the design
        childAspectRatio: 0.65, // Adjust this ratio to fit poster aspect
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: movies.length,
      // Important: Disable scrolling for the GridView itself,
      // as the SingleChildScrollView of the parent handles it.
      physics: const  AlwaysScrollableScrollPhysics(),
      
      shrinkWrap: true, // Make the grid take only as much space as its children
      itemBuilder: (context, index) {
        final movie = movies[index];
        return GestureDetector(
          onLongPress: () {
            // Convert MovieItem to MovieListItem
            final movieItem = MovieListItem(
              id: movie.id.toString(),
              title: movie.title ?? 'Unknown',
              posterPath: movie.posterPath,
              mediaType: movie.mediaType ?? 'movie',
              addedAt: DateTime.now(),
            );

            showMovieActionDrawer(context, movieItem);
          },
          onTap: () async {
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );

            try {
              if (movie.mediaType == 'tv') {
                // Fetch full TV show details
                final tvDetails = await Trending().fetchDetailsTvShow(movie.id);

                // Close loading indicator
                if (context.mounted) Navigator.pop(context);

                if (tvDetails != null && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShowDetailsScreen(movie: tvDetails),
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
                // Fetch full movie details
                final movieDetails = await Trending().fetchMovieDetails(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: getTmdbImageUrl(
                      movie.posterPath,
                    ), // Use TMDB image helper
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey.shade300),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey,
                      child: const Icon(Icons.error, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title ?? 'No Title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                movie.genre ?? 'Unknown', // Use movie.genre
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              
            ],
          ),
        );
       
      },
      
    );
    
  }
  
}
