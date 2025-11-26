import 'package:finishd/Mainpage/Discover.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/Widget/ImageSlideshow.dart';
import 'package:finishd/Widget/community_avatar.dart';
import 'package:finishd/Widget/loading.dart';
import 'package:finishd/Widget/movie_section.dart';
import 'package:finishd/tmbd/airingToday.dart';
import 'package:finishd/tmbd/fetchDiscover.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finishd/Model/trendingmovies.dart';
import 'package:finishd/Model/trendingshow.dart';
import 'package:finishd/tmbd/fetchtrending.dart';

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
      final airingTodayshow = List<MediaItem>.from(await airingToday.fetchAiringToday());

      final provider = Provider.of<MovieProvider>(context, listen: false);
      provider.setDiscover(discover);
      provider.setMovies(movies);
      provider.setShows(shows);
      provider.setPopular(popular);
      provider.setUpcoming(upcoming);
      provider.setAiringToday(airingTodayshow);

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
          ? const Center(child: ExploreShimmer())
          : error != null
          ? Center(child: Text('Error: $error'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carousel Banner
                  if (provider.movies.isNotEmpty)
                    BannerCarousel(movies: provider.movies, movieApi: movieApi),
                  const SizedBox(height: 5),
                  const Text(
                    "Suggested Communities",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

                  MovieSection(
                    title: "Popular",
                    items: provider.popular,
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
    );
  }
}
