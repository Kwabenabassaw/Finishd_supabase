import 'package:finishd/LoadingWidget/playerloading.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/movie_list_item.dart';

import 'package:finishd/Widget/Cast_avatar.dart';
import 'package:finishd/Widget/MovieStreamingprovider.dart';
import 'package:finishd/Widget/TrailerPlayer.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/tmbd/fetch_trialler.dart';
import 'package:finishd/Model/recommendation_model.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/MovieDetails/movie_recommenders_screen.dart';
import 'package:finishd/Widget/related_content_section.dart';
import 'package:finishd/Widget/ratings_display_widget.dart';
import 'package:finishd/services/tmdb_sync_service.dart';
import 'package:finishd/Widget/streaming_section.dart';
import 'package:finishd/Community/community_detail_screen.dart';
// --- Placeholder/Mock Data Models ---
// Replace these with your actual TMDB models (Movie, CastMember, Season)

TvService tvService = TvService();

// --- The Main Widget ---

// ... other imports ...

class MovieDetailsScreen extends StatefulWidget {
  final MovieDetails movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final TmdbSyncService _syncService = TmdbSyncService();
  late MovieDetails _movie;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _syncFullDetails();
  }

  Future<void> _syncFullDetails() async {
    final synced = await _syncService.getMovieDetails(_movie.id);
    if (synced != null && mounted) {
      setState(() {
        _movie = synced;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _movie.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  final movieItem = MovieListItem(
                    id: _movie.id.toString(),
                    title: _movie.title,
                    posterPath: _movie.posterPath,
                    mediaType: 'movie',
                    addedAt: DateTime.now(),
                  );
                  showMovieActionDrawer(context, movieItem);
                },
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 10),
                    // Logic to use _movie.videos if available directly, else fallback to FutureBuilder
                    if (_movie.videos.isNotEmpty)
                      AnimatedTrailerCover(
                        poster: _movie.posterPath.toString(),
                        youtubeKey: _movie.videos
                            .firstWhere(
                              (v) => v.site == 'YouTube' && v.type == 'Trailer',
                              orElse: () => _movie.videos.first,
                            )
                            .key,
                      )
                    else
                      FutureBuilder(
                        future: tvService.getMovieTrailerKey(_movie.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return AnimatedTrailerCoverShimmer();
                          }
                          if (snapshot.hasError) {
                            return const Text("Couldn't load trailer");
                          }
                          if (!snapshot.hasData || snapshot.data == null) {
                            return SizedBox(
                              height: 200,
                              child: Image.network(
                                "https://image.tmdb.org/t/p/w500${_movie.posterPath}",
                                fit: BoxFit.cover,
                                height: 100,
                                width: double.infinity,
                              ),
                            );
                          }

                          return AnimatedTrailerCover(
                            poster: _movie.posterPath.toString(),
                            youtubeKey: snapshot.data!,
                          );
                        },
                      ),
                    _buildTitleAndRuntime(_movie.title),
                    const SizedBox(height: 5),

                    _buildGenres(
                      _movie.genres.map((genre) => genre.name).toList(),
                    ),

                    // NEW Streaming Section
                    const SizedBox(height: 15),
                    StreamingSection(
                      watchProviders: _movie.watchProviders,
                      title: _movie.title,
                      tmdbId: _movie.id.toString(),
                    ),

                    if (_movie.watchProviders == null && !_isLoading)
                      const Text(
                        "Currently unavailable to stream in your region.",
                        style: TextStyle(color: Colors.grey),
                      ),

                    const SizedBox(height: 15),

                    RatingsDisplayWidget(
                      tmdbId: _movie.id,
                      tmdbRating: _movie.voteAverage,
                    ),

                    const SizedBox(height: 15),

                    // Community button - Start discussing this movie
                    _buildCommunityButton(),

                    const SizedBox(height: 15),

                    Text(
                      _movie.overview ?? '',
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 25),

                    const Text(
                      'Cast',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    MovieCastAvatar(movieId: _movie.id),

                    _buildRecommendedSection(),
                    const SizedBox(height: 25),

                    RelatedContentSection(
                      contentId: _movie.id,
                      mediaType: 'movie',
                      title: _movie.title,
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Helper Widget Builders (Defined outside the build method for clarity)
  // -------------------------------------------------------------------

  Widget fancyScoreWithLabel(double score, {required String label}) {
    // Convert score (assumed 0-10) to percentage (0-100)
    int percent = (score * 10).round();

    // Determine the color based on the percentage
    Color progressColor = percent >= 80
        ? Colors
              .green
              .shade600 // Excellent
        : percent >= 50
        ? Colors
              .amber
              .shade600 // Good
        : Colors.red.shade600; // Needs Improvement

    // Determine a subtle background/fill color for the row
    Color backgroundColor = progressColor.withOpacity(0.1);

    return Container(
      // Make the entire widget block slightly larger and give it a rounded background
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: backgroundColor, // Subtle colored background
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Keep the row content snug
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Score Circle and Text (Larger Stack)
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70, // Increased size
                height: 70, // Increased size
                child: CircularProgressIndicator(
                  value: score / 10, // Convert to 0–1
                  strokeWidth: 8, // Thicker stroke
                  backgroundColor: Colors.grey.shade200,
                  // Using a LinearProgressIndicator as a stand-in for rounded ends
                  // The actual CircularProgressIndicator doesn't easily support rounded ends directly.
                  // The surprise design element: We'll make the color transition nice.
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              // The score text inside the circle
              Text(
                "$percent%",
                style: TextStyle(
                  fontSize: 20, // Bolder score
                  fontWeight: FontWeight.w900,
                  color: progressColor, // Color matches the progress
                ),
              ),
            ],
          ),

          const SizedBox(width: 15), // Increased spacing
          // Label Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                _getScoreGrade(
                  percent,
                ), // Surprise Element: A descriptive grade
                style: TextStyle(
                  fontSize: 14,
                  color: progressColor, // Color matches the score/progress
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper function to provide a descriptive grade
  String _getScoreGrade(int percent) {
    if (percent >= 90) return "Excellent";
    if (percent >= 70) return "Very Good";
    if (percent >= 50) return "Good";
    if (percent >= 30) return "Fair";
    return "Poor";
  }

  // Example usage:
  // fancyScoreWithLabel(8.5, label: "Customer Satisfaction")
  //

  Widget _buildTitleAndRuntime(String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGenres(List<String> genres) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...genres.map(
          (genre) => Text(
            genre,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
        // Runtime
        const Text('•', style: TextStyle(color: Colors.black54, fontSize: 16)),
        Text(
          _movie.runtime.toString(),
          style: const TextStyle(color: Colors.black54, fontSize: 16),
        ),
        const Text(
          'min',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildRecommendedSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final RecommendationService recommendationService = RecommendationService();
    final UserService userService = UserService();

    return StreamBuilder<List<Recommendation>>(
      stream: recommendationService.getMyRecommendationsForMovie(
        user.uid,
        _movie.id.toString(),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recommendations = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recommended by',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.black),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieRecommendersScreen(
                          movieId: _movie.id.toString(),
                          movieTitle: _movie.title,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final rec = recommendations[index];
                  return FutureBuilder<UserModel?>(
                    future: userService.getUser(rec.fromUserId),
                    builder: (context, userSnapshot) {
                      final sender = userSnapshot.data;
                      if (sender == null) return const SizedBox.shrink();

                      return _buildPersonTile(
                        sender.username,
                        sender.profileImage,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPersonTile(String name, String imageUrl) {
    return Padding(
      padding: const EdgeInsets.only(right: 20.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : const AssetImage('assets/noimage.jpg') as ImageProvider,
            backgroundColor: Colors.grey.shade200,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 60,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a button to navigate to the community for this movie
  Widget _buildCommunityButton() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommunityDetailScreen(
              showId: _movie.id,
              showTitle: _movie.title,
              posterPath: _movie.posterPath,
              mediaType: 'movie',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A8927).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1A8927), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum_outlined, color: Color(0xFF1A8927)),
            const SizedBox(width: 8),
            const Text(
              'Join the Discussion',
              style: TextStyle(
                color: Color(0xFF1A8927),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF1A8927),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
