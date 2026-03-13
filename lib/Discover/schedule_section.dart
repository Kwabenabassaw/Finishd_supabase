import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finishd/models/simkl/trakt_model.dart';
import 'package:finishd/Discover/schedule_see_all_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';

// Note: SIMKL schedule models don't have posterPath directly. We might need to fetch posters,
// but since the instruction says "dont check anything that does not relate with the simkl sechedule",
// we will display a nice text-based card if the poster isn't available, or rely on TMDB ID if we must.
// For simplicity and to follow strict instructions, we will build a card based strictly on the schedule data.

class ScheduleSection extends StatelessWidget {
  final List<ShowRelease> scheduleItems;

  const ScheduleSection({super.key, required this.scheduleItems});

  @override
  Widget build(BuildContext context) {
    if (scheduleItems.isEmpty) return const SizedBox.shrink();

    // Group items for display (just take the first 10 for the horizontal scroll)
    final displayItems = scheduleItems.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "TV Shows Schedule",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: -0.4,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ScheduleSeeAllScreen(scheduleItems: scheduleItems),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "See All",
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 180, // Height for our custom cards
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 16),
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final item = displayItems[index];
              return _buildScheduleCard(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(BuildContext context, ShowRelease item) {
    String formattedDate = '';
    try {
      final dt = DateTime.parse(item.date);
      formattedDate = DateFormat('MMM d, yyyy').format(dt);
    } catch (e) {
      formattedDate = item.date;
    }

    String episodeText = '';
    if (item.season != null && item.episode != null) {
      episodeText =
          "S${item.season.toString().padLeft(2, '0')}E${item.episode.toString().padLeft(2, '0')}";
    }

    // Construct TMDB poster URL if posterPath is available
    final String? posterUrl = item.posterPath != null
        ? "https://image.tmdb.org/t/p/w500${item.posterPath}"
        : null;

    return GestureDetector(
      onTap: () {
        if (item.tmdbId != null) {
          final shallowShow = TvShowDetails(
            id: item.tmdbId!,
            name: item.title,
            originalName: item.title,
            overview: '',
            posterPath: item.posterPath,
            backdropPath: null,
            firstAirDate: item.date,
            inProduction: false,
            genres: [],
            languages: [],
            networks: [],
            numberOfEpisodes: 0,
            numberOfSeasons: 0,
            seasons: [],
            status: 'Loading...',
            type: 'tv',
            voteAverage: 0.0,
            voteCount: 0,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShowDetailsScreen(movie: shallowShow),
            ),
          );
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Backend Image Layer
              if (posterUrl != null)
                CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Theme.of(context).cardColor),
                  errorWidget: (context, url, error) =>
                      Container(color: Theme.of(context).cardColor),
                ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black,
                    ],
                  ),
                ),
              ),

              // Text Content Layer
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header / Date block
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.9),
                    ),
                    child: Text(
                      formattedDate,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            item.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (episodeText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                episodeText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
