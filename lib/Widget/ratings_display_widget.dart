import 'package:flutter/material.dart';
import 'package:finishd/Model/movie_ratings_model.dart';
import 'package:finishd/services/ratings_service.dart';

/// Widget to display movie ratings from multiple sources
/// Shows TMDB, IMDb, Rotten Tomatoes, and Metacritic ratings
/// in a horizontally scrollable layout
class RatingsDisplayWidget extends StatelessWidget {
  final int tmdbId;
  final double? tmdbRating; // Original TMDB rating (0-10 scale)

  const RatingsDisplayWidget({
    super.key,
    required this.tmdbId,
    this.tmdbRating,
  });

  @override
  Widget build(BuildContext context) {
    final ratingsService = RatingsService();

    return FutureBuilder<MovieRatings>(
      future: ratingsService.getRatings(tmdbId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(context);
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final ratings = snapshot.data!;

        // Don't show if no data available
        if (!ratings.hasData && (tmdbRating == null || tmdbRating == 0)) {
          return const SizedBox.shrink();
        }

        return _buildRatings(context, ratings);
      },
    );
  }

  Widget _buildRatings(BuildContext context, MovieRatings ratings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: Text(
            'Ratings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Horizontally scrollable ratings
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            children: [
              // TMDB Rating with circular progress
              if (tmdbRating != null && tmdbRating! > 0)
                _buildTmdbScoreCard(context, tmdbRating!),

              // IMDb Rating
              if (ratings.imdbRating != 'N/A')
                _buildRatingCard(
                  context: context,
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF5C518),
                  label: 'IMDb',
                  rating: ratings.imdbRating,
                  subtitle: _formatVotes(ratings.imdbVotes),
                ),

              // Rotten Tomatoes
              if (ratings.rotten != 'N/A')
                _buildRatingCard(
                  context: context,
                  icon: Icons.local_movies_rounded,
                  iconColor: const Color(0xFFFA320A),
                  label: 'Rotten',
                  rating: ratings.rotten,
                  subtitle: 'Tomatometer',
                ),

              // Metacritic
              if (ratings.metacritic != 'N/A')
                _buildRatingCard(
                  context: context,
                  icon: Icons.score_rounded,
                  iconColor: const Color(0xFF66CC33),
                  label: 'Meta',
                  rating: ratings.metacritic,
                  subtitle: 'Metascore',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTmdbScoreCard(BuildContext context, double score) {
    final int percent = (score * 10).round();
    final Color progressColor = _getProgressColor(percent);
    final theme = Theme.of(context);

    return Container(
      width: 110,
      height: 90,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TMDB',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: score),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, currentScore, child) {
              final currentPercent = (currentScore * 10).round();
              final currentColor = _getProgressColor(currentPercent);
              final progressValue = currentScore / 10;

              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      value: progressValue,
                      strokeWidth: 3.5,
                      backgroundColor: theme.dividerColor.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(currentColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    '$currentPercent',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String rating,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: 110,
      height: 90,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            rating,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: theme.textTheme.bodySmall?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: Text(
            'Ratings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            children: List.generate(
              3,
              (index) => Container(
                width: 110,
                height: 90,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Gets color based on percentage score
  Color _getProgressColor(int percent) {
    if (percent >= 80) return const Color(0xFF4ADE80); // Green
    if (percent >= 50) return const Color(0xFFFACC15); // Yellow
    return const Color(0xFFF87171); // Red
  }

  /// Formats vote count for display (e.g., "1,234,567" → "1.2M votes")
  String _formatVotes(String votes) {
    try {
      final cleanVotes = votes.replaceAll(',', '');
      final numVotes = int.tryParse(cleanVotes) ?? 0;

      if (numVotes >= 1000000) {
        return '${(numVotes / 1000000).toStringAsFixed(1)}M';
      } else if (numVotes >= 1000) {
        return '${(numVotes / 1000).toStringAsFixed(1)}K';
      } else {
        return '$numVotes';
      }
    } catch (e) {
      return votes;
    }
  }
}
