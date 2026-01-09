import 'package:finishd/Model/trending.dart';
import 'package:finishd/Widget/interactive_media_poster.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:flutter/material.dart';

class RankingSection extends StatelessWidget {
  final String title;
  final List<MediaItem> items;

  const RankingSection({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 16),
                child: Stack(
                  children: [
                    // Large Number
                    Positioned(
                      left: -5,
                      bottom: -20,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 120,
                          fontWeight: FontWeight.w900,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 2
                            ..color = Colors.white54,
                        ),
                      ),
                    ),
                    // Poster
                    Positioned(
                      left: 40,
                      top: 0,
                      bottom: 10,
                      right: 0,
                      child: InteractiveMediaPoster(
                        item: item,
                        child: GestureDetector(
                          onTap: () => _navigateToDetails(context, item),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: FadeInImage.assetNetwork(
                              placeholder: 'assets/noimage.jpg',
                              image:
                                  'https://image.tmdb.org/t/p/w500${item.posterPath}',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToDetails(BuildContext context, MediaItem item) {
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
