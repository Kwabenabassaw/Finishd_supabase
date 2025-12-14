import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/Widget/ImageSlideshow.dart';
import 'package:finishd/Widget/community_avatar.dart';
import 'package:finishd/Widget/loading.dart';
import 'package:finishd/Widget/movie_section.dart';
import 'package:finishd/tmbd/Nowplaying.dart';
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

final Trending movieApi = Trending();
final Fetchdiscover getDiscover = Fetchdiscover();
final Airingtoday airingToday = Airingtoday();

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
      if (uid != null) {
        _userPreferences = await _prefsService.getUserPreferences(uid);
      }

      final provider = Provider.of<MovieProvider>(context, listen: false);
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

  void _navigateToSeeAll(
    BuildContext context,
    String title,
    ContentCategory category,
    List<MediaItem> initialItems,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeeAllScreen(
          title: title,
          category: category,
          initialItems: initialItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MovieProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          Padding(
            padding: EdgeInsetsGeometry.all(15),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, 'Search_discover');
              },
              child: Icon(Icons.search, weight: 20),
            ),
          ),
        ],
      ),
      body: isLoading
          ? LogoLoadingScreen()
          : error != null
          ? Center(child: Text('Error: $error'))
          : RefreshIndicator(
              onRefresh: fetchData,
              color: const Color(0xFF1A8927),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carousel Banner
                    if (provider.movies.isNotEmpty)
                      BannerCarousel(
                        movies: provider.movies,
                        movieApi: movieApi,
                      ),
                    const SizedBox(height: 15),

                    // Streaming Services Section
                    if (_userPreferences != null &&
                        _userPreferences!.streamingProviders.isNotEmpty) ...[
                      _buildStreamingServicesSection(),
                      const SizedBox(height: 15),
                    ],

                    const Text(
                      "Suggested Communities",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsetsGeometry.all(8),
                      child: CommunityAvatarList(),
                    ),

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

                    MovieSection(
                      title: "Trending Shows",
                      items: provider.shows,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Trending Shows",
                        ContentCategory.trendingShows,
                        provider.shows,
                      ),
                    ),

                    // MovieSection(
                    //   title: "Top Rated TV",
                    //   items: provider.topRatedTv,
                    //   movieApi: movieApi,
                    // ),
                    MovieSection(
                      title: "Popular",
                      items: provider.popular,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Popular",
                        ContentCategory.popular,
                        provider.popular,
                      ),
                    ),
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

                    MovieSection(
                      title: "Upcoming",
                      items: provider.upcoming,
                      movieApi: movieApi,
                      onSeeAllTap: () => _navigateToSeeAll(
                        context,
                        "Upcoming",
                        ContentCategory.upcoming,
                        provider.upcoming,
                      ),
                    ),
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
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            "Your Streaming Services",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _userPreferences!.streamingProviders.length,
            itemBuilder: (context, index) {
              final provider = _userPreferences!.streamingProviders[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProviderContentScreen(
                        providerId: provider.providerId,
                        providerName: provider.providerName,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/original${provider.logoPath}',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
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
