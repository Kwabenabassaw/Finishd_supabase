// movie_poster_grid.dart (or define it in the same file for simplicity)
import 'package:finishd/profile/profileScreen.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MoviePosterGrid extends StatelessWidget {
  final List<MovieItem> movies; // Expects a list of MovieItem

  const MoviePosterGrid({super.key, required this.movies});

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('No movies found in this list.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns as per the design
        childAspectRatio: 0.65, // Adjust this ratio to fit poster aspect
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: movies.length,
      // Important: Disable scrolling for the GridView itself,
      // as the SingleChildScrollView of the parent handles it.
      physics: const NeverScrollableScrollPhysics(), 
      shrinkWrap: true, // Make the grid take only as much space as its children
      itemBuilder: (context, index) {
        final movie = movies[index];
        return GestureDetector(
          onTap: () {
            // Navigate to movie details (example)
            // Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)));
            print('Tapped on ${movie.title}');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: getTmdbImageUrl(movie.posterPath), // Use TMDB image helper
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(color: Colors.grey.shade300),
                    errorWidget: (context, url, error) => Container(color: Colors.grey, child: const Icon(Icons.error, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title ?? 'No Title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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