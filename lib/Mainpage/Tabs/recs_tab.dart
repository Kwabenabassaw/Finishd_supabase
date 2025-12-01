import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/recommendation_model.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/tmbd/fetchtrending.dart'; // For fetching details if needed

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
                Icon(Icons.recommend_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No recommendations yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'When friends recommend movies,\nthey will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: recommendations.length,
          itemBuilder: (context, index) {
            return _buildRecommendationCard(recommendations[index]);
          },
        );
      },
    );
  }

  Widget _buildRecommendationCard(Recommendation rec) {
    return FutureBuilder<UserModel?>(
      future: _userService.getUser(rec.fromUserId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final senderName = user?.username ?? 'Someone';
        final senderImage = user?.profileImage;

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
                  // Mark as seen
                  if (rec.status == 'unread') {
                    _recommendationService.markAsSeen(rec.id);
                  }
                  _navigateToDetails(rec);
                },
                borderRadius: BorderRadius.circular(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: rec.moviePosterPath != null
                        ? 'https://image.tmdb.org/t/p/w780${rec.moviePosterPath}' // Higher res
                        : 'https://via.placeholder.com/400x600',
                    width: double.infinity,
                    height: 450, // Large height
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
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec.mediaType == 'movie'
                              ? 'Movie'
                              : 'TV Show', // Placeholder for Season/Ep
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.remove_red_eye_outlined, // Binoculars look-alike
                    color: Color(0xFF1A8927), // Green brand color
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Recommender Row (Clickable/Long Press)
              InkWell(
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
                    // Avatar Stack (Placeholder for multiple, currently showing one)
                    SizedBox(
                      width: 40, // Width for overlapping avatars if needed
                      height: 30,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundImage:
                                senderImage != null && senderImage.isNotEmpty
                                ? CachedNetworkImageProvider(senderImage)
                                : const AssetImage('assets/noimage.jpg')
                                      as ImageProvider,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          children: [
                            const TextSpan(text: 'Recommended by '),
                            TextSpan(
                              text: senderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w100,
                                color: Colors.black87,
                              ),
                            ),
                          ],
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
