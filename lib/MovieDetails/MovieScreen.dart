import 'dart:io';
import 'dart:async';
import 'package:finishd/Home/Friends/friend_selection_screen.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Widget/Cast_avatar.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/tmbd/fetch_trialler.dart';
import 'package:finishd/Model/recommendation_model.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/Model/movie_ratings_model.dart';

import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/MovieDetails/movie_recommenders_screen.dart';
import 'package:finishd/Widget/related_content_section.dart';
import 'package:finishd/Widget/ratings_display_widget.dart';
import 'package:finishd/services/tmdb_sync_service.dart';
import 'package:finishd/Widget/watchmode_streaming_section.dart';
import 'package:finishd/Community/community_detail_screen.dart';
import 'package:finishd/Widget/YouTubeTrailerPlayerDialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:finishd/services/user_titles_service.dart';
import 'package:finishd/Widget/rating_action_button.dart';
import 'package:finishd/Widget/emotion_rating_slider.dart';
import 'package:finishd/MovieDetails/widgets/ai_chat_sheet.dart';
import 'package:finishd/MovieDetails/widgets/ai_floating_button.dart';
import 'package:finishd/provider/ai_assistant_provider.dart';
import 'package:sizer/sizer.dart';
import 'package:finishd/services/ratings_service.dart';
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
  final UserTitlesService _userTitlesService = UserTitlesService();
  late MovieDetails _movie;
  int _userRating = 0;
  Stream<List<Recommendation>>? _recommendationsStream;
  YoutubePlayerController? _previewController;
  bool _showPreview = false;
  bool _showEmojiPicker = false;
  Timer? _previewTimer;
  MovieRatings _ratings = MovieRatings.empty();
  final RatingsService _ratingsService = RatingsService();

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _recommendationsStream = RecommendationService()
        .getMyRecommendationsForMovie(
          FirebaseAuth.instance.currentUser?.uid ?? '',
          _movie.id.toString(),
        );
    _syncFullDetails();
    _loadUserRating();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    final r = await _ratingsService.getRatings(_movie.id);
    if (mounted) {
      setState(() {
        _ratings = r;
      });
    }
  }

  Future<void> _loadUserRating() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final record = await _userTitlesService.getUserTitle(
      uid,
      _movie.id.toString(),
    );
    if (record != null && mounted) {
      setState(() {
        _userRating = record.rating ?? 0;
      });
    }
  }

  Future<void> _syncFullDetails() async {
    final synced = await _syncService.getMovieDetails(_movie.id);
    if (synced != null && mounted) {
      setState(() {
        _movie = synced;
      });

      // Initialize preview controller
      String? youtubeKey;
      if (_movie.videos.isNotEmpty) {
        youtubeKey = _movie.videos
            .firstWhere(
              (v) => v.site == 'YouTube' && v.type == 'Trailer',
              orElse: () => _movie.videos.first,
            )
            .key;
      } else {
        youtubeKey = await tvService.getMovieTrailerKey(_movie.id);
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
      floatingActionButton: AiFloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AiChatSheet(movie: _movie, ratings: _ratings),
          );
        },
      ),
      body: CustomScrollView(
        physics: Platform.isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 45.h,
            pinned: true,
            stretch: true,
            backgroundColor: themeBackground,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(shape: BoxShape.circle),
                child: Icon(
                  Platform.isIOS ? Icons.arrow_back_ios_new : Icons.arrow_back,

                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  child: Icon(Icons.more_vert, size: 20),
                ),
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
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'poster_${_movie.id}',
                    child: CachedNetworkImage(
                      imageUrl:
                          "https://image.tmdb.org/t/p/original${_movie.posterPath}",
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
              padding: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 2.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Title and Metadata
                  Text(
                    _movie.title,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      Text(
                        _movie.releaseDate?.substring(0, 4) ?? '',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      SizedBox(width: 2.w),
                      const Text('•'),
                      SizedBox(width: 2.w),
                      Text(
                        '${_movie.runtime} min',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      SizedBox(width: 2.w),
                      const Text('•'),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          _movie.genres.take(2).map((g) => g.name).join(', '),
                          style: TextStyle(fontSize: 12.sp),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 3.h),

                  // Action Buttons Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            String? youtubeKey;
                            if (_movie.videos.isNotEmpty) {
                              youtubeKey = _movie.videos
                                  .firstWhere(
                                    (v) =>
                                        v.site == 'YouTube' &&
                                        v.type == 'Trailer',
                                    orElse: () => _movie.videos.first,
                                  )
                                  .key;
                            } else {
                              youtubeKey = await tvService.getMovieTrailerKey(
                                _movie.id,
                              );
                            }

                            if (youtubeKey != null && mounted) {
                              // Pause preview player to prevent resource conflict
                              _previewTimer?.cancel();
                              _previewController?.pause();
                              setState(() => _showPreview = false);

                              YouTubeTrailerPlayerDialog.show(
                                context,
                                youtubeKey,
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
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
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        RatingActionButton(
                          initialRating: _userRating,
                          onTap: () {
                            setState(() {
                              _showEmojiPicker = !_showEmojiPicker;
                            });
                          },
                          onRatingChanged: (rating) {
                            // This is still needed for internal state update if RatingActionButton
                            // was used in dialog mode, but here we'll handle it via the inline slider.
                          },
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
                                id: _movie.id.toString(),
                                title: _movie.title,
                                posterPath: _movie.posterPath,
                                mediaType: 'movie',
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
                                id: _movie.id.toString(),
                                title: _movie.title,
                                posterPath: _movie.posterPath,
                                mediaType: 'movie',
                                addedAt: DateTime.now(),
                              );
                              showMovieActionDrawer(context, movieItem);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showEmojiPicker
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: EmotionRatingSlider(
                              initialRating: _userRating,
                              onRatingChanged: (rating) {
                                final uid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                if (uid != null) {
                                  _userTitlesService.updateRating(
                                    uid: uid,
                                    titleId: _movie.id.toString(),
                                    mediaType: 'movie',
                                    title: _movie.title,
                                    posterPath: _movie.posterPath,
                                    rating: rating,
                                  );
                                  setState(() {
                                    _userRating = rating;
                                    _showEmojiPicker =
                                        false; // Close after rating
                                  });
                                }
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 30),

                  // Streaming & Ratings (Watchmode API)
                  WatchmodeStreamingSection(
                    tmdbId: _movie.id.toString(),
                    mediaType: 'movie',
                    title: _movie.title,
                  ),
                  const SizedBox(height: 25),

                  RatingsDisplayWidget(
                    tmdbId: _movie.id,
                    tmdbRating: _movie.voteAverage,
                  ),

                  const SizedBox(height: 30),

                  // overview
                  Text(
                    'Overview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _movie.overview ?? '',
                    style: TextStyle(fontSize: 16, height: 1.6),
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
                  MovieCastAvatar(movieId: _movie.id),

                  const SizedBox(height: 30),

                  // Recommendations
                  _buildRecommendedSection(),

                  const SizedBox(height: 30),

                  // Related Content
                  RelatedContentSection(
                    contentId: _movie.id,
                    mediaType: 'movie',
                    title: _movie.title,
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
  // Helper Widget Builders (Defined outside the build method for clarity)
  // -------------------------------------------------------------------

  Widget _buildRecommendedSection() {
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
