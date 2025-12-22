import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:finishd/services/genre_discover_service.dart';

/// Enum to identify which category to fetch
enum ContentCategory {
  trendingMovies,
  trendingShows,
  popular,
  nowPlaying,
  upcoming,
  airingToday,
  topRatedTv,
  discover,
  genre,
}

class SeeAllScreen extends StatefulWidget {
  final String title;
  final ContentCategory category;
  final List<MediaItem> initialItems;
  final int? genreId;

  const SeeAllScreen({
    super.key,
    required this.title,
    required this.category,
    required this.initialItems,
    this.genreId,
  });

  @override
  State<SeeAllScreen> createState() => _SeeAllScreenState();
}

class _SeeAllScreenState extends State<SeeAllScreen> {
  final Trending _movieApi = Trending();
  final ScrollController _scrollController = ScrollController();
  final GenreDiscoverService _genreService = GenreDiscoverService();

  List<MediaItem> _items = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
    _movieApi.loadGenres();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);
    _currentPage++;

    try {
      final newItems = await _fetchPage(_currentPage);

      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        setState(() {
          _items.addAll(newItems);
        });
      }
    } catch (e) {
      print('Error loading more: $e');
      _currentPage--;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<MediaItem>> _fetchPage(int page) async {
    switch (widget.category) {
      case ContentCategory.trendingMovies:
        return await _movieApi.fetchTrendingMoviePaginated(page);
      case ContentCategory.trendingShows:
        return await _movieApi.fetchTrendingShowPaginated(page);
      case ContentCategory.popular:
        return await _movieApi.fetchPopularMoviesPaginated(page);
      case ContentCategory.nowPlaying:
        return await _movieApi.getNowPlayingPaginated(page);
      case ContentCategory.upcoming:
        return await _movieApi.fetchUpcomingPaginated(page);
      case ContentCategory.airingToday:
        return await _movieApi.fetchAiringTodayPaginated(page);
      case ContentCategory.topRatedTv:
        return await _movieApi.fetchTopRatedTvPaginated(page);
      case ContentCategory.discover:
        return await _movieApi.fetchDiscoverPaginated(page);
      case ContentCategory.genre:
        if (widget.genreId != null) {
          return await _genreService.fetchGenreContentPaginated(
            widget.genreId!,
            page,
          );
        }
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final item = _items[index];
          return _buildGridItem(context, item);
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, MediaItem item) {
    return GestureDetector(
      onTap: () => _navigateToDetails(context, item),
      onLongPress: () {
        final movieListItem = MovieListItem(
          id: item.id.toString(),
          title: item.title,
          posterPath: item.posterPath,
          mediaType: item.mediaType,
          addedAt: DateTime.now(),
        );
        showMovieActionDrawer(context, movieListItem);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: "https://image.tmdb.org/t/p/w342${item.posterPath}",
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) =>
                    Container(color: Colors.grey.shade300),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.movie, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToDetails(BuildContext context, MediaItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: LogoLoadingScreen()),
    );

    try {
      if (item.mediaType == 'tv') {
        final tvDetails = await _movieApi.fetchDetailsTvShow(item.id);
        if (context.mounted) Navigator.pop(context);

        if (tvDetails != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShowDetailsScreen(movie: tvDetails),
            ),
          );
        }
      } else {
        final movieDetails = await _movieApi.fetchMovieDetails(item.id);
        if (context.mounted) Navigator.pop(context);

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movie: movieDetails),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load details: $e')));
      }
    }
  }
}
