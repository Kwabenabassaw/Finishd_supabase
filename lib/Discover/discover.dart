import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/Widget/ImageSlideshow.dart';
import 'package:finishd/Widget/community_avatar.dart';
import 'package:finishd/Widget/movie_section.dart';
import 'package:finishd/tmbd/airingToday.dart';
import 'package:finishd/tmbd/fetchDiscover.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:finishd/services/user_preferences_service.dart';
import 'package:finishd/services/discover_cache_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Discover/provider_content_screen.dart';
import 'package:finishd/Discover/see_all_screen.dart';
import 'package:finishd/services/genre_discover_service.dart';
import 'package:finishd/services/social_discovery_service.dart';

final Trending movieApi = Trending();
final Fetchdiscover getDiscover = Fetchdiscover();
final Airingtoday airingToday = Airingtoday();
final GenreDiscoverService _genreService = GenreDiscoverService();
final SocialDiscoveryService _socialService = SocialDiscoveryService();

// Map of common genre names for display
final Map<int, String> _genreNames = {
  28: 'Action',
  18: 'Drama',
  35: 'Comedy',
  878: 'Sci-Fi',
  10765: 'Sci-Fi & Fantasy', // TV equivalent
  53: 'Thriller',
  10749: 'Romance',
  27: 'Horror',
  12: 'Adventure',
  16: 'Animation',
};

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool isLoading = true;
  String? error;
  final UserPreferencesService _prefsService = UserPreferencesService();
  final DiscoverCacheService _cacheService = DiscoverCacheService();
  UserPreferences? _userPreferences;

  @override
  void initState() {
    super.initState();

    movieApi.loadGenres();
    fetchData();
  }

  /// Fetch with cache-first strategy (6-hour TTL)
  Future<List<MediaItem>> _fetchWithCache(
    String cacheKey,
    Future<List<MediaItem>> Function() fetchFn,
  ) async {
    // Try cache first
    final cached = await _cacheService.getCached(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // Fetch from network
    final data = await fetchFn();

    // Save to cache
    if (data.isNotEmpty) {
      await _cacheService.saveToCache(cacheKey, data);
    }

    return data;
  }

  Future<void> fetchData({bool forceRefresh = false}) async {
    try {
      // Clear cache if force refresh
      if (forceRefresh) {
        await _cacheService.clearCache();
      }

      final movies = await _fetchWithCache(
        DiscoverCacheService.keyTrendingMovies,
        () => movieApi.fetchTrendingMovie(),
      );
      final shows = await _fetchWithCache(
        DiscoverCacheService.keyTrendingShows,
        () => movieApi.fetchTrendingShow(),
      );
      final popular = await _fetchWithCache(
        DiscoverCacheService.keyPopular,
        () => movieApi.fetchpopularMovies(),
      );
      final upcoming = await _fetchWithCache(
        DiscoverCacheService.keyUpcoming,
        () => movieApi.fetchUpcoming(),
      );
      final discover = await _fetchWithCache(
        DiscoverCacheService.keyDiscover,
        () => getDiscover.fetchDiscover(),
      );
      final airingTodayshow = await _fetchWithCache(
        DiscoverCacheService.keyAiringToday,
        () => airingToday.fetchAiringToday(),
      );
      final nowPlaying = await _fetchWithCache(
        DiscoverCacheService.keyNowPlaying,
        () => movieApi.getNowPlaying(),
      );
      final topRatedTv = await _fetchWithCache(
        DiscoverCacheService.keyTopRatedTv,
        () => movieApi.TopRatedTv(),
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      List<int> genresToFetch = [28, 18, 35, 878]; // Default fallbacks

      if (uid != null) {
        _userPreferences = await _prefsService.getUserPreferences(uid);
        if (_userPreferences != null &&
            _userPreferences!.selectedGenreIds.isNotEmpty) {
          genresToFetch = _userPreferences!.selectedGenreIds.take(6).toList();
        }
      }

      final provider = Provider.of<MovieProvider>(context, listen: false);

      // Fetch genre content
      for (int genreId in genresToFetch) {
        final content = await _genreService.fetchGenreContent(genreId);
        if (content.isNotEmpty) {
          provider.setGenreSection(genreId, content);
        }
      }

      // Fetch social signals
      if (uid != null) {
        final signals = await _socialService.fetchSocialSignals(uid);
        provider.setSocialSignals(signals);

        // Aggregate "Friends Are Watching" items
        // We'll need to fetch MediaItem details for these IDs if we don't have them
        // For simplicity, we'll look for items already in state or fetch basic info
        final watchingIds = signals.entries
            .where((e) => e.value.friendsWatching.isNotEmpty)
            .map((e) => e.key)
            .toList();

        if (watchingIds.isNotEmpty) {
          // Fetch MediaItem for these IDs (Movies and TV)
          final watchingItems = await _fetchMediaItemsByIds(watchingIds);
          provider.setFriendsWatching(watchingItems);
        }

        // Aggregate "Popular in Your Network"
        final popularInNetworkIds = signals.entries
            .where((e) => e.value.totalCount > 0)
            .toList();

        // Sorting by score: watching*3 + liked*2 + finished*4
        popularInNetworkIds.sort((a, b) {
          final scoreA =
              a.value.friendsWatching.length * 3 +
              a.value.friendsLiked.length * 2 +
              a.value.friendsFinished.length * 4;
          final scoreB =
              b.value.friendsWatching.length * 3 +
              b.value.friendsLiked.length * 2 +
              b.value.friendsFinished.length * 4;
          return scoreB.compareTo(scoreA);
        });

        final top10Ids = popularInNetworkIds
            .take(10)
            .map((e) => e.key)
            .toList();
        if (top10Ids.isNotEmpty) {
          final top10Items = await _fetchMediaItemsByIds(top10Ids);
          provider.setPopularInNetwork(top10Items);
        }
      }

      provider.setDiscover(discover);
      provider.setMovies(movies);
      provider.setShows(shows);
      provider.setPopular(popular);
      provider.setUpcoming(upcoming);
      provider.setAiringToday(airingTodayshow);
      provider.setNowPlaying(nowPlaying);
      provider.setTopRatedTv(topRatedTv);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<List<MediaItem>> _fetchMediaItemsByIds(List<String> ids) async {
    // This is a placeholder since TMDB doesn't have a multi-get
    // In a real app, we'd batch fetch or use a cache
    final List<MediaItem> items = [];
    for (var id in ids.take(10)) {
      // Limit to 10 for speed
      try {
        // Try to fetch as movie first, then TV
        final movie = await movieApi.fetchMovieDetails(int.parse(id));
        if (movie != null) {
          items.add(
            MediaItem(
              id: movie.id,
              title: movie.title,
              overview: movie.overview ?? '',
              posterPath: movie.posterPath ?? '',
              backdropPath: movie.backdropPath ?? '',
              voteAverage: movie.voteAverage ?? 0.0,
              mediaType: 'movie',
              releaseDate: movie.releaseDate ?? '',
              genreIds: movie.genres.map((g) => g.id).toList(),
              imageUrl: '',
            ),
          );
          continue;
        }
      } catch (e) {
        // Try TV
        try {
          final tv = await movieApi.fetchDetailsTvShow(int.parse(id));
          if (tv != null) {
            items.add(
              MediaItem(
                id: tv.id,
                title: tv.name,
                overview: tv.overview,
                posterPath: tv.posterPath ?? '',
                backdropPath: tv.backdropPath ?? '',
                voteAverage: tv.voteAverage ?? 0.0,
                mediaType: 'tv',
                releaseDate: tv.firstAirDate,
                genreIds: tv.genres.map((g) => g.id).toList(),
                imageUrl: '',
              ),
            );
          }
        } catch (_) {}
      }
    }
    return items;
  }

  void _navigateToSeeAll(
    BuildContext context,
    String title,
    ContentCategory category,
    List<MediaItem> initialItems, {
    int? genreId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeeAllScreen(
          title: title,
          category: category,
          initialItems: initialItems,
          genreId: genreId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MovieProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 28),
            onPressed: () => Navigator.pushNamed(context, 'Search_discover'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const LogoLoadingScreen()
          : error != null
          ? Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => fetchData(forceRefresh: true),
              color: Colors.green,
              backgroundColor: Colors.grey[900],
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carousel Banner
                    if (provider.movies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: BannerCarousel(
                          movies: provider.movies,
                          movieApi: movieApi,
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Social Section: Friends Are Watching
                    if (provider.friendsWatching.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: MovieSection(
                          title: "Friends Are Watching",
                          items: provider.friendsWatching,
                          movieApi: movieApi,
                          onSeeAllTap: null, // No pagination for this yet
                        ),
                      ),

                    // Genre-based Carousels (Inserted after Trending Preview and before Provider-based rows)
                    ...provider.genreSections.entries.map((entry) {
                      final name = _genreNames[entry.key] ?? 'Discover';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: MovieSection(
                          title: name,
                          items: entry.value,
                          movieApi: movieApi,
                          onSeeAllTap: () => _navigateToSeeAll(
                            context,
                            name,
                            ContentCategory.genre,
                            entry.value,
                            genreId: entry.key,
                          ),
                        ),
                      );
                    }).toList(),

                    // Social Section: Popular in Your Network
                    if (provider.popularInNetwork.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: MovieSection(
                          title: "Popular in Your Network",
                          items: provider.popularInNetwork,
                          movieApi: movieApi,
                          onSeeAllTap: null,
                        ),
                      ),

                    // Streaming Services Section
                    if (_userPreferences != null &&
                        _userPreferences!.streamingProviders.isNotEmpty) ...[
                      _buildStreamingServicesSection(),
                      const SizedBox(height: 12),
                    ],

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Featured Communities",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,

                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    CommunityAvatarList(),

                    const SizedBox(height: 12), // Tightened gap

                    MovieSection(
                      title: "Discover",
                      items: provider.discover,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Discover",
                        ContentCategory.discover,
                        provider.discover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MovieSection(
                      title: "Trending Movies",
                      items: provider.movies,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Trending Movies",
                        ContentCategory.trendingMovies,
                        provider.movies,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MovieSection(
                      title: "Trending TV Shows",
                      items: provider.shows,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Trending Shows",
                        ContentCategory.trendingShows,
                        provider.shows,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MovieSection(
                      title: "Popular Movies",
                      items: provider.popular,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Popular",
                        ContentCategory.popular,
                        provider.popular,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MovieSection(
                      title: "Now Playing",
                      items: provider.nowPlaying,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Now Playing",
                        ContentCategory.nowPlaying,
                        provider.nowPlaying,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MovieSection(
                      title: "Upcoming Movies",
                      items: provider.upcoming,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Upcoming",
                        ContentCategory.upcoming,
                        provider.upcoming,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MovieSection(
                      title: "Airing Today",
                      items: provider.airingToday,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Airing Today",
                        ContentCategory.airingToday,
                        provider.airingToday,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStreamingServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Your Services",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16, // Slightly smaller header
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54, // Perfectly sized for small circles
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _userPreferences!.streamingProviders.length,
            itemBuilder: (context, index) {
              final service = _userPreferences!.streamingProviders[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProviderContentScreen(
                        providerId: service.providerId,
                        providerName: service.providerName,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 50, // Fixed square size for circle
                  height: 50,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/original${service.logoPath}',
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.white24,
                      ),
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
}
