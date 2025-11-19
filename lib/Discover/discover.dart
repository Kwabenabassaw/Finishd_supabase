import 'package:finishd/Model/trending.dart';
import 'package:finishd/MovieDetails/movie_details_screen.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/Widget/ImageSlideshow.dart';
import 'package:finishd/Widget/community_avatar.dart';
import 'package:finishd/Widget/loading.dart';
import 'package:finishd/Widget/movie_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finishd/Model/trendingmovies.dart';
import 'package:finishd/Model/trendingshow.dart';
import 'package:finishd/tmbd/fetchtrending.dart';



class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final Trending movieApi = Trending();
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

      final provider = Provider.of<MovieProvider>(context, listen: false);
      
      provider.setMovies(movies);
      provider.setShows(shows);
      provider.setPopular(popular);
      provider.setUpcoming(upcoming);

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
      appBar: AppBar(title: const Text('Explore'),actions: [
        Padding(padding:
        EdgeInsetsGeometry.all(15),
        child: GestureDetector(
          onTap: (){
              Navigator.pushNamed(context, 'Search_discover');
          },
          child: Icon(Icons.search,weight: 20,),
        ),
         )
        
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
                        BannerCarousel(
                          movies: provider.movies,
                          movieApi: movieApi,
                        ),
                      const SizedBox(height: 10),
                      Text("Suggested Communities",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 16, ),),
                      Padding(padding: 
                      EdgeInsetsGeometry.all(8),
                      child: 
                        CommunityAvatarList(),
                      
                      ),
                    
                      // Trending Movies
                      const Text(
                        "Trending Movies",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.28,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: provider.movies.length,
                          itemBuilder: (context, index) {
                            final movie = provider.movies[index];
                            final genres = movieApi.getGenreNames(movie.genreIds);
                            final limited = genres.length > 2
                                ? genres.take(2).toList()
                                : genres;
                            return GenericMovieCard<MediaItem>(
                              item: movie,
                              titleBuilder: (m) => m.title ?? "No title",
                              posterBuilder: (m) =>
                                  "https://image.tmdb.org/t/p/w500${m.posterPath}",
                              typeBuilder: (m) => limited.join(", "),
                              onTap: () {
                                provider.selectItem(provider.movies, index);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GenericDetailsScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Trending Shows
                      const Text(
                        "Trending Shows",
                        style: TextStyle(fontWeight: FontWeight.bold ,fontSize: 16,),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.28,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: provider.shows.length,
                          itemBuilder: (context, index) {
                            final show = provider.shows[index];
                            final genres = movieApi.getGenreNames(show.genreIds);
                            final limited = genres.length > 2
                                ? genres.take(2).toList()
                                : genres;
                            return GenericMovieCard<MediaItem>(
                              item: show,
                              titleBuilder: (s) => s.title ,
                              posterBuilder: (s) =>
                                  "https://image.tmdb.org/t/p/w500${s.posterPath}",
                              typeBuilder: (s) => limited.join(", "),
                              onTap: () {
                                provider.selectItem(provider.shows, index);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GenericDetailsScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Popular
                      const Text(
                        "Popular",
                        style: TextStyle(fontWeight: FontWeight.bold ,fontSize: 16,),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                         height: MediaQuery.of(context).size.height * 0.28,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: provider.popular.length,
                          itemBuilder: (context, index) {
                            final show = provider.popular[index];
                            final genres = movieApi.getGenreNames(show.genreIds);
                            final limited = genres.length > 2
                                ? genres.take(2).toList()
                                : genres;
                            return GenericMovieCard<MediaItem>(
                              item: show,
                              titleBuilder: (s) => s.title,
                              posterBuilder: (s) =>
                                  "https://image.tmdb.org/t/p/w500${s.posterPath}",
                              typeBuilder: (s) => limited.join(", "),
                              onTap: () {
                                provider.selectItem(provider.popular, index);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GenericDetailsScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Upcoming
                      const Text(
                        "Upcoming",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.28,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: provider.upcoming.length,
                          itemBuilder: (context, index) {
                            final show = provider.upcoming[index];
                            final genres = movieApi.getGenreNames(show.genreIds);
                            final limited = genres.length > 2
                                ? genres.take(2).toList()
                                : genres;
                            return GenericMovieCard<MediaItem>(
                              item: show,
                              titleBuilder: (s) => s.title ,
                              posterBuilder: (s) =>
                                  "https://image.tmdb.org/t/p/w500${s.posterPath}",
                              typeBuilder: (s) => limited.join(", "),
                              onTap: () {
                                provider.selectItem(provider.upcoming, index);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GenericDetailsScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
