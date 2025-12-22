import 'dart:io';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Home/Friends/friend_selection_screen.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/SeasonDetailsScreen.dart';
import 'package:finishd/MovieDetails/movie_recommenders_screen.dart';
import 'package:finishd/Widget/ratings_display_widget.dart';
import 'package:finishd/Widget/related_content_section.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Widget/Cast_avatar.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/Model/recommendation_model.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/services/tmdb_sync_service.dart';
import 'package:finishd/Widget/watchmode_streaming_section.dart';
import 'package:finishd/Community/community_detail_screen.dart';
import 'package:finishd/Widget/YouTubeTrailerPlayerDialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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
  Stream<List<Recommendation>>? _recommendationsStream;
  YoutubePlayerController? _previewController;
  bool _showPreview = false;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _show = widget.movie;
    _recommendationsStream = RecommendationService()
        .getMyRecommendationsForMovie(
          FirebaseAuth.instance.currentUser?.uid ?? '',
          _show.id.toString(),
        );
    _syncFullDetails();
  }

  Future<void> _syncFullDetails() async {
    final synced = await _syncService.getTvShowDetails(_show.id);
    if (synced != null && mounted) {
      setState(() {
        _show = synced;
      });

      // Initialize preview controller
      String? youtubeKey;
      if (_show.videos.isNotEmpty) {
        youtubeKey = _show.videos
            .firstWhere(
              (v) => v.site == 'YouTube' && v.type == 'Trailer',
              orElse: () => _show.videos.first,
            )
            .key;
      } else {
        youtubeKey = await tvService.getTVShowTrailerKey(_show.id.toString());
      }

      if (youtubeKey != null && mounted) {
        _previewController =
            YoutubePlayerController(
              initialVideoId: youtubeKey,
              flags: const YoutubePlayerFlags(
                autoPlay: true,
                mute: true,
                disableDragSeek: true,
                loop: true,
                isLive: false,
                forceHD: false,
                enableCaption: false,
              ),
            )..addListener(() {
              if (_previewController!.value.isReady &&
                  !_showPreview &&
                  mounted) {
                setState(() => _showPreview = true);

                // ⏱️ Stop preview after 10 seconds
                _previewTimer = Timer(const Duration(seconds: 10), () {
                  if (mounted) {
                    setState(() {
                      _showPreview = false;
                    });
                    // Slightly delay pausing to allow fade animation to complete
                    Future.delayed(const Duration(milliseconds: 800), () {
                      _previewController?.pause();
                    });
                  }
                });
              }
            });
      }
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _previewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeBackground = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: themeBackground,
      body: CustomScrollView(
        physics: Platform.isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 400.0,
            pinned: true,
            stretch: true,
            backgroundColor: themeBackground,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Platform.isIOS ? Icons.arrow_back_ios_new : Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
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
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'poster_${_show.id}',
                    child: CachedNetworkImage(
                      imageUrl:
                          "https://image.tmdb.org/t/p/original${_show.posterPath}",
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.black12),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
                  ),
                  if (_previewController != null)
                    AnimatedOpacity(
                      opacity: _showPreview ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      child: YoutubePlayer(
                        controller: _previewController!,
                        showVideoProgressIndicator: false,
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          themeBackground,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Title and Metadata
                  Text(
                    _show.name,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _show.firstAirDate.substring(0, 4),
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle()),
                      const SizedBox(width: 8),
                      Text(_show.status, style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _show.genres.take(2).map((g) => g.name).join(', '),
                          style: TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            String? youtubeKey;
                            if (_show.videos.isNotEmpty) {
                              youtubeKey = _show.videos
                                  .firstWhere(
                                    (v) =>
                                        v.site == 'YouTube' &&
                                        v.type == 'Trailer',
                                    orElse: () => _show.videos.first,
                                  )
                                  .key;
                            } else {
                              youtubeKey = await tvService.getTVShowTrailerKey(
                                _show.id.toString(),
                              );
                            }

                            if (youtubeKey != null && mounted) {
                              YouTubeTrailerPlayerDialog.show(
                                context,
                                youtubeKey,
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Trailer not available'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play Trailer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ADE80),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: IconButton(
                          icon: Icon(
                            FontAwesomeIcons.share,
                            color: Theme.of(context).iconTheme.color,
                            size: 24,
                          ),
                          onPressed: () {
                            final movieItem = MovieListItem(
                              id: _show.id.toString(),
                              title: _show.name,
                              posterPath: _show.posterPath,
                              mediaType: 'tv',
                              addedAt: DateTime.now(),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FriendSelectionScreen(movie: movieItem),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.add_rounded,
                            color: Theme.of(context).iconTheme.color,
                          ),
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
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Streaming & Ratings (Watchmode API)
                  WatchmodeStreamingSection(
                    tmdbId: _show.id.toString(),
                    mediaType: 'tv',
                    title: _show.name,
                  ),
                  const SizedBox(height: 25),

                  RatingsDisplayWidget(
                    tmdbId: _show.id,
                    tmdbRating: _show.voteAverage,
                  ),

                  const SizedBox(height: 30),

                  // overview
                  Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _show.overview,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Community Section
                  _buildCommunityButton(),

                  const SizedBox(height: 30),

                  // Cast
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cast',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  CastAvatar(showId: _show.id),

                  const SizedBox(height: 30),

                  // Recommendations
                  _buildRecommendedSection(context),

                  const SizedBox(height: 30),

                  // Seasons Section
                  _buildSeasonsSection(context, _show.seasons),

                  const SizedBox(height: 30),

                  // Related Content
                  RelatedContentSection(
                    contentId: _show.id,
                    mediaType: 'tv',
                    title: _show.name,
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------

  Widget _buildRecommendedSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _recommendationsStream == null)
      return const SizedBox.shrink();

    final UserService userService = UserService();

    return StreamBuilder<List<Recommendation>>(
      stream: _recommendationsStream,
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
                  icon: Icon(
                    Icons.arrow_forward,
                    color: Theme.of(context).iconTheme.color,
                  ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seasons',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 220,
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
                  child: SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl:
                                "https://image.tmdb.org/t/p/w500${season.posterPath}",
                            height: 180,
                            width: 130,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.white10),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white10,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          season.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
