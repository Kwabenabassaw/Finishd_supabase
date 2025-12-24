import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';

class RelatedContentSection extends StatefulWidget {
  final int contentId;
  final String mediaType; // 'movie' or 'tv'
  final String title;

  const RelatedContentSection({
    super.key,
    required this.contentId,
    required this.mediaType,
    required this.title,
  });

  @override
  State<RelatedContentSection> createState() => _RelatedContentSectionState();
}

class _RelatedContentSectionState extends State<RelatedContentSection> {
  late Future<List<MediaItem>> _relatedFuture;
  final Trending _trending = Trending();

  @override
  void initState() {
    super.initState();
    _relatedFuture = widget.mediaType == 'movie'
        ? _trending.fetchRelatedMovies(widget.contentId)
        : _trending.fetchRelatedTVShows(widget.contentId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MediaItem>>(
      future: _relatedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final relatedItems = snapshot.data ?? [];

        if (relatedItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                'Related ${widget.mediaType == 'movie' ? 'Movies' : 'TV Shows'}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: relatedItems.length,
                itemBuilder: (context, index) {
                  final item = relatedItems[index];
                  return _buildRelatedCard(context, item);
                },
              ),
            ),
            const SizedBox(height: 25),
          ],
        );
      },
    );
  }

  Widget _buildRelatedCard(BuildContext context, MediaItem item) {
    return GestureDetector(
      onTap: () async {
        // Navigate to details screen based on media type
        if (item.mediaType == 'movie') {
          final trending = Trending();
          try {
            final movieDetails = await trending.fetchMovieDetails(item.id);
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailsScreen(movie: movieDetails),
                ),
              );
            }
          } catch (e) {
            print('Error navigating to movie: $e');
          }
        } else if (item.mediaType == 'tv') {
          final trending = Trending();
          try {
            final showDetails = await trending.fetchDetailsTvShow(item.id);
            if (showDetails != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShowDetailsScreen(movie: showDetails),
                ),
              );
            }
          } catch (e) {
            print('Error navigating to TV show: $e');
          }
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.posterPath.isNotEmpty
                        ? 'https://image.tmdb.org/t/p/w500${item.posterPath}'
                        : 'https://via.placeholder.com/140x210?text=No+Image',
                    height: 210,
                    width: 140,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 210,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A8927),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 210,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.movie_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                // Rating badge
                if (item.voteAverage > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.trending_up_rounded,
                            color: Color(0xFF4ADE80),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.voteAverage.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              item.title.isEmpty ? 'Unknown' : item.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            height: 24,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 210,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }
}
