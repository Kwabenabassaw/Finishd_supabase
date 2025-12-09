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
          return _buildLoadingState();
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.0),
          child: Text(
            'Ratings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        // Horizontally scrollable ratings
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            children: [
              // TMDB Rating with circular progress
              if (tmdbRating != null && tmdbRating! > 0)
                _buildTmdbScoreCard(tmdbRating!),

              // IMDb Rating
              if (ratings.imdbRating != 'N/A')
                _buildRatingCard(
                  icon: Icons.movie,
                  iconColor: const Color(0xFFF5C518),
                  label: 'IMDb',
                  rating: ratings.imdbRating,
                  subtitle: _formatVotes(ratings.imdbVotes),
                ),

              // Rotten Tomatoes
              if (ratings.rotten != 'N/A')
                _buildRatingCard(
                  icon: Icons.local_movies,
                  iconColor: const Color(0xFFFA320A),
                  label: 'Rotten',
                  rating: ratings.rotten,
                  subtitle: 'Tomatometer',
                ),

              // Metacritic
              if (ratings.metacritic != 'N/A')
                _buildRatingCard(
                  icon: Icons.score,
                  iconColor: const Color(0xFF66CC33),
                  label: 'Metacritic',
                  rating: ratings.metacritic,
                  subtitle: 'Metascore',
                ),
            ],
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildTmdbScoreCard(double score) {
    final int percent = (score * 10).round();
    final Color progressColor = _getProgressColor(percent);

    return Container(
      width: 160,
      height: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.star, color: const Color(0xFF1A8927), size: 20),
              const SizedBox(width: 8),
              Text(
                'TMDB',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  
                ),
              ),
            ],
          ),
          // Circular Progress
          Center(
            child: TweenAnimationBuilder<double>(
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
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 5,
                 
                        valueColor: AlwaysStoppedAnimation<Color>(currentColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$currentPercent%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: currentColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Subtitle
          Center(
            child: Text(
              'User Score',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String rating,
    required String subtitle,
  }) {
    return Container(
      width: 160,
      height: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
       
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon and Label
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                 
                ),
              ),
            ],
          ),
          // Rating
          Text(
            rating,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
             
            ),
          ),
          // Subtitle
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          child: Text(
            'Ratings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: List.generate(
              3,
              (index) => Container(
                width: 160,
                height: 130,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  /// Gets color based on percentage score
  Color _getProgressColor(int percent) {
    if (percent >= 80) return Colors.green.shade600;
    if (percent >= 50) return Colors.amber.shade600;
    return Colors.red.shade600;
  }

  /// Formats vote count for display (e.g., "1,234,567" → "1.2M votes")
  String _formatVotes(String votes) {
    try {
      final cleanVotes = votes.replaceAll(',', '');
      final numVotes = int.tryParse(cleanVotes) ?? 0;

      if (numVotes >= 1000000) {
        return '${(numVotes / 1000000).toStringAsFixed(1)}M votes';
      } else if (numVotes >= 1000) {
        return '${(numVotes / 1000).toStringAsFixed(1)}K votes';
      } else {
        return '$numVotes votes';
      }
    } catch (e) {
      return votes;
    }
  }
}
