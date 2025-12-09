import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/recommendation_model.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/Widget/overlapping_avatars_widget.dart';
import 'package:finishd/MovieDetails/movie_recommenders_screen.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/tmbd/fetchtrending.dart';

class RecsTab extends StatefulWidget {
  const RecsTab({super.key});

  @override
  State<RecsTab> createState() => _RecsTabState();
}

class _RecsTabState extends State<RecsTab> {
  final RecommendationService _recommendationService = RecommendationService();
  final UserService _userService = UserService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final Trending _api = Trending();

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Center(child: Text('Please log in to see recommendations.'));
    }

    return StreamBuilder<List<Recommendation>>(
      stream: _recommendationService.getRecommendations(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final recommendations = snapshot.data ?? [];

        if (recommendations.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.recommend_outlined, size: 64, ),
                SizedBox(height: 16),
                Text(
                  'No recommendations yet',
                  style: TextStyle(fontSize: 18, ),
                ),
                SizedBox(height: 8),
                Text(
                  'When friends recommend movies,\\nthey will appear here.',
                  textAlign: TextAlign.center,
                 
                ),
              ],
            ),
          );
        }

        // Group recommendations by movieId
        final groupedRecs = <String, List<Recommendation>>{};
        for (final rec in recommendations) {
          if (!groupedRecs.containsKey(rec.movieId)) {
            groupedRecs[rec.movieId] = [];
          }
          groupedRecs[rec.movieId]!.add(rec);
        }

        final movieIds = groupedRecs.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: movieIds.length,
          itemBuilder: (context, index) {
            final movieId = movieIds[index];
            final recsForMovie = groupedRecs[movieId]!;
            return _buildRecommendationCard(recsForMovie);
          },
        );
      },
    );
  }

  Widget _buildRecommendationCard(List<Recommendation> recs) {
    // Use the first recommendation for movie details
    final rec = recs.first;
    final recommenderCount = recs.length;

    return FutureBuilder<List<UserModel?>>(
      future: Future.wait(
        recs.map((r) => _userService.getUser(r.fromUserId)).toList(),
      ),
      builder: (context, snapshot) {
        final users = snapshot.data ?? [];
        final profileImages = users.map((u) => u?.profileImage).toList();

        // Handle case where users list might be empty or have nulls
        final hasUsers = users.isNotEmpty && users.any((u) => u != null);
        final firstUsername = users.where((u) => u != null).isNotEmpty
            ? users.firstWhere((u) => u != null)!.username
            : 'a friend';

        return Card(
          margin: const EdgeInsets.only(bottom: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          borderOnForeground: true,
          elevation: 0,
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Large Poster (Clickable)
              InkWell(
                onTap: () async {
                  // Mark all as seen
                  for (final r in recs) {
                    if (r.status == 'unread') {
                      _recommendationService.markAsSeen(r.id);
                    }
                  }
                  _navigateToDetails(rec);
                },
                borderRadius: BorderRadius.circular(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: rec.moviePosterPath != null
                        ? 'https://image.tmdb.org/t/p/w780${rec.moviePosterPath}'
                        : 'https://via.placeholder.com/400x600',
                    width: double.infinity,
                    height: 450,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 450,
                      color: Colors.transparent,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Info Row (Title + Binoculars)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.movieTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec.mediaType == 'movie' ? 'Movie' : 'TV Show',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                 
                ],
              ),
              const SizedBox(height: 12),

              // 3. Recommender Row with Overlapping Avatars
              InkWell(
                onTap: () {
                  // Navigate to recommenders screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieRecommendersScreen(
                        movieId: rec.movieId,
                        movieTitle: rec.movieTitle,
                      ),
                    ),
                  );
                },
                onLongPress: () {
                  // Add to list action
                  final movieItem = MovieListItem(
                    id: rec.movieId,
                    title: rec.movieTitle,
                    posterPath: rec.moviePosterPath,
                    mediaType: rec.mediaType,
                    addedAt: DateTime.now(),
                  );
                  showMovieActionDrawer(context, movieItem);
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    // Overlapping Avatars
                    if (hasUsers)
                      OverlappingAvatarsWidget(
                        imageUrls: profileImages,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MovieRecommendersScreen(
                                movieId: rec.movieId,
                                movieTitle: rec.movieTitle,
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recommenderCount == 1
                            ? 'Recommended by $firstUsername'
                            : 'Recommended by $recommenderCount friends',
                        style: TextStyle(
                       
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _navigateToDetails(Recommendation rec) async {
    showDialog(
      context: context,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (rec.mediaType == 'movie') {
        final movie = await _api.fetchMovieDetails(int.parse(rec.movieId));
        if (mounted) Navigator.pop(context);
        if (movie != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movie: movie),
            ),
          );
        }
      } else {
        final show = await _api.fetchDetailsTvShow(int.parse(rec.movieId));
        if (mounted) Navigator.pop(context);
        if (show != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShowDetailsScreen(movie: show),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading details: $e')));
      }
    }
  }
}
