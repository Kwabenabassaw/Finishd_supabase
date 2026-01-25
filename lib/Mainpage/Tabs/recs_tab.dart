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
import 'dart:ui';

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
      // Hybrid stream: loads from cache instantly, listens for new items only
      stream: _recommendationService.getRecommendationsHybrid(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final recommendations = snapshot.data ?? [];

        if (recommendations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No recommendations yet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'When friends recommend movies, they will appear here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
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
          padding: const EdgeInsets.symmetric(vertical: 20),
          physics: const BouncingScrollPhysics(),
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

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                Theme.of(context).cardTheme.color ??
                (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05,
                ),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Large Poster (stack with media type)
              Stack(
                children: [
                  InkWell(
                    onTap: () async {
                      for (final r in recs) {
                        if (r.status == 'unread') {
                          _recommendationService.markAsSeen(r.id);
                        }
                      }
                      _navigateToDetails(rec);
                    },
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: rec.moviePosterPath != null
                                ? 'https://image.tmdb.org/t/p/w780${rec.moviePosterPath}'
                                : 'https://via.placeholder.com/400x600',
                            width: double.infinity,
                            height: 480,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 480,
                              color: Theme.of(
                                context,
                              ).dividerColor.withOpacity(0.05),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                          // Gradient overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 160,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Glassmorphic Media Type Badge
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (recs.any((r) => r.status == 'unread')) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A8927), // Brand Green
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                rec.mediaType.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Row (Title)
                    Text(
                      rec.movieTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),

                    // Recommender Row
                    InkWell(
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
                      onLongPress: () {
                        final movieItem = MovieListItem(
                          id: rec.movieId,
                          title: rec.movieTitle,
                          posterPath: rec.moviePosterPath,
                          mediaType: rec.mediaType,
                          addedAt: DateTime.now(),
                        );
                        showMovieActionDrawer(context, movieItem);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          if (hasUsers)
                            OverlappingAvatarsWidget(
                              imageUrls: profileImages,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        MovieRecommendersScreen(
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white30
                                : Colors.black26,
                          ),
                        ],
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
        if (mounted) {
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
