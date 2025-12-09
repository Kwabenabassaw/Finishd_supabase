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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Discover/provider_content_screen.dart';

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
  UserPreferences? _userPreferences;

  @override
  void initState() {
    super.initState();

    movieApi.loadGenres();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final movies = List<MediaItem>.from(await movieApi.fetchTrendingMovie());
      final shows = List<MediaItem>.from(await movieApi.fetchTrendingShow());
      final popular = List<MediaItem>.from(await movieApi.fetchpopularMovies());
      final upcoming = List<MediaItem>.from(await movieApi.fetchUpcoming());
      final discover = List<MediaItem>.from(await getDiscover.fetchDiscover());
      final airingTodayshow = List<MediaItem>.from(
        await airingToday.fetchAiringToday(),
      );
      final nowPlaying = List<MediaItem>.from(await movieApi.getNowPlaying() );
      final topRatedTv = List<MediaItem>.from(await movieApi.TopRatedTv() );

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
                    ),

                    MovieSection(
                      title: "Trending Movies",
                      items: provider.movies,
                      movieApi: movieApi,
                    ),

                    MovieSection(
                      title: "Trending Shows",
                      items: provider.shows,
                      movieApi: movieApi,
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
                    ),
                    MovieSection(
                      title: "Now Playing",
                      items: provider.nowPlaying,
                      movieApi: movieApi,
                    ),

                    MovieSection(
                      title: "Upcoming",
                      items: provider.upcoming,
                      movieApi: movieApi,
                    ),
                    MovieSection(
                      title: "Airing Today",
                      items: provider.airingToday,
                      movieApi: movieApi,
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
