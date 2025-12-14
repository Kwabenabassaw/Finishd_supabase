import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/SeasonDetailsScreen.dart';
import 'package:finishd/MovieDetails/movie_recommenders_screen.dart';
import 'package:finishd/Widget/ratings_display_widget.dart';
import 'package:finishd/Widget/related_content_section.dart';
import 'package:flutter/material.dart';
import 'package:finishd/LoadingWidget/playerloading.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Widget/Cast_avatar.dart';
import 'package:finishd/Widget/TvStreamingprovider.dart';
import 'package:finishd/Widget/TrailerPlayer.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/onboarding/CategoriesTypeMove.dart';
import 'package:finishd/tmbd/fetch_trialler.dart';
import 'package:finishd/Model/recommendation_model.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/services/tmdb_sync_service.dart';
import 'package:finishd/Widget/streaming_section.dart';
import 'package:finishd/Community/community_detail_screen.dart';

// ... other imports ...

class ShowDetailsScreen extends StatefulWidget {
  final TvShowDetails movie;
  const ShowDetailsScreen({super.key, required this.movie});

  @override
  State<ShowDetailsScreen> createState() => _ShowDetailsScreenState();
}

class _ShowDetailsScreenState extends State<ShowDetailsScreen> {
  final TmdbSyncService _syncService = TmdbSyncService();
  late TvShowDetails _show;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _show = widget.movie;
    _syncFullDetails();
  }

  Future<void> _syncFullDetails() async {
    final synced = await _syncService.getTvShowDetails(_show.id);
    if (synced != null && mounted) {
      setState(() {
        _show = synced;
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
          // ... SliverAppBar ...
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  final movieItem = MovieListItem(
                    id: _show.id.toString(),
                    title: _show.name,
                    posterPath: _show.posterPath,
                    mediaType: 'tv',
                    addedAt: DateTime.now(),
                  );
                  showMovieActionDrawer(context, movieItem);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _show.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Stack(
                      children: [
                        // Logic to use _show.videos if available directly, else fallback to FutureBuilder
                        if (_show.videos.isNotEmpty)
                          AnimatedTrailerCover(
                            poster: _show.posterPath.toString(),
                            youtubeKey: _show.videos
                                .firstWhere(
                                  (v) =>
                                      v.site == 'YouTube' &&
                                      v.type == 'Trailer',
                                  orElse: () => _show.videos.first,
                                )
                                .key,
                          )
                        else
                          FutureBuilder(
                            future: tvService.getTVShowTrailerKey(
                              _show.id.toString(),
                            ),
                            // ... existing builder logic ...
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return AnimatedTrailerCoverShimmer();
                              }
                              if (snapshot.hasError) {
                                return _buildcover(
                                  context,
                                  _show.posterPath.toString(),
                                );
                              }
                              if (!snapshot.hasData || snapshot.data == null) {
                                return SizedBox(
                                  height: 200,
                                  child: Image.network(
                                    "https://image.tmdb.org/t/p/w500${_show.posterPath}",
                                    fit: BoxFit.cover,
                                    height: 100,
                                    width: double.infinity,
                                  ),
                                );
                              }
                              final trailerKey = snapshot.data! as String;
                              return AnimatedTrailerCover(
                                poster: _show.posterPath.toString(),
                                youtubeKey: trailerKey,
                              );
                            },
                          ),
                      ],
                    ),

                    _buildTitleAndRuntime(_show.name),
                    const SizedBox(height: 5),
                    Row(
                      spacing: 10,
                      children: [
                        const Flexible(
                          child: Text(
                            "First Aired Date: ",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _show.firstAirDate,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _show.status,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    Text(_show.genres.map((genre) => genre.name).join(", ")),

                    // NEW Streaming Section
                    const SizedBox(height: 15),
                    StreamingSection(
                      watchProviders: _show.watchProviders,
                      title: _show.name,
                      tmdbId: _show.id.toString(),
                    ),

                    if (_show.watchProviders == null && !_isLoading)
                      const Text(
                        "Currently unavailable to stream in your region.",
                        style: TextStyle(color: Colors.grey),
                      ),

                    const SizedBox(height: 15),

                    SizedBox(height: 15),

                    // Ratings from multiple sources
                    RatingsDisplayWidget(
                      tmdbId: _show.id,
                      tmdbRating: _show.voteAverage,
                    ),

                    SizedBox(height: 5),

                    // Genres
                    const SizedBox(height: 16),

                    // Streaming Services (Logos)
                    // _buildStreamingServices(),
                    // const SizedBox(height: 20),

                    // Description/Overview
                    Text(
                      _show.overview,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 20),

                    // Community button - Start discussing this show
                    _buildCommunityButton(),

                    const SizedBox(height: 25),
                    const Text(
                      'Cast',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    CastAvatar(showId: _show.id),
                    // const SizedBox(height: 25),

                    // Cast Section
                    // _buildCastSection(movie.cast),
                    // const SizedBox(height: 25),

                    // Recommended Section (Placeholder for complex logic)
                    _buildRecommendedSection(context),
                    const SizedBox(height: 25),

                    // Seasons/Episodes Section
                    _buildSeasonsSection(context, _show.seasons),

                    // Related TV Shows Section
                    RelatedContentSection(
                      contentId: _show.id,
                      mediaType: 'tv',
                      title: _show.name,
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

  Widget _buildcover(BuildContext context, String poster) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => {},
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 50,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black87.withOpacity(0.5),
              BlendMode.srcATop,
            ),
            child: ClipRRect(
              borderRadius: BorderRadiusGeometry.circular(10),
              child: Image.network(
                "https://image.tmdb.org/t/p/w500${poster}",
                height: MediaQuery.of(context).size.height * 0.24,
                width:
                    MediaQuery.of(context).size.width * 0.5, // Responsive width
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }

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

  Widget scoreWithLabel(double score) {
    int percent = (score * 10).round();

    return Row(
      children: [
        // Score Circle
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: score / 10, // Convert to 0–1
                strokeWidth: 5,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percent >= 70
                      ? Colors.green
                      : percent >= 40
                      ? Colors.yellow
                      : Colors.red,
                ),
              ),
            ),
            Text(
              "$percent%",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(width: 10),

        Column(children: [Text("User"), Text("Score")]),

        // Label
      ],
    );
  }

  // Widget _buildCastSection(List<CastMember> cast) {
  Widget _buildRecommendedSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final RecommendationService recommendationService = RecommendationService();
    final UserService userService = UserService();

    return StreamBuilder<List<Recommendation>>(
      stream: recommendationService.getMyRecommendationsForMovie(
        user.uid,
        widget.movie.id.toString(),
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
                          movieId: widget.movie.id.toString(),
                          movieTitle: widget.movie.name,
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

  Widget _buildSeasonsSection(BuildContext context, List<Season> seasons) {
    if (seasons.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.35 > 140 ? 140.0 : screenWidth * 0.35;
    final cardHeight = cardWidth * 1.3; // Approx aspect ratio

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${seasons.length} Seasons',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: cardHeight + 40, // Height for the season posters
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];
              return Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SeasonDetailsScreen(
                          tvId: widget.movie.id,
                          seasonNumber: season.seasonNumber,
                          showName: widget.movie.name,
                          posterPath: widget.movie.posterPath,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: cardWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl:
                                "https://image.tmdb.org/t/p/w500${season.posterPath}",
                            height: cardHeight,
                            width: cardWidth,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade300,
                              height: cardHeight,
                              width: cardWidth,
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey,
                              height: cardHeight,
                              width: cardWidth,
                              child: const Icon(
                                Icons.error,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          season.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build a button to navigate to the community for this show
  Widget _buildCommunityButton() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommunityDetailScreen(
              showId: _show.id,
              showTitle: _show.name,
              posterPath: _show.posterPath,
              mediaType: 'tv',
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
