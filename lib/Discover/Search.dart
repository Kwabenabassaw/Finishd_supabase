import 'dart:io' show Platform;
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Model/Searchdiscover.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/MovieDetails/movie_details_screen.dart';
import 'package:finishd/Widget/interactive_media_poster.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/tmbd/Search.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/screens/actor_profile_screen.dart';
import 'package:finishd/services/feed_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:provider/provider.dart';

Trending api = Trending();
SearchDiscover searchApi = SearchDiscover();
FeedSearchService feedSearchService = FeedSearchService();

// Utility for TMDB image URLs
String getTmdbImageUrl(String? path, {String size = 'w500'}) {
  if (path == null || path.isEmpty) {
    return 'assets/noimage.jpg';
  }
  return 'https://image.tmdb.org/t/p/$size$path';
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Result> _allResults = [];
  bool _isLoading = false;
  Timer? _debounce;
  String _lastQuery = '';

  MovieProvider get provider =>
      Provider.of<MovieProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    fetchTrendingMovies();
    provider.clearSearchSelection();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void fetchTrendingMovies() async {
    try {
      final movies = List<MediaItem>.from(await api.fetchTrendingMovie());
      final shows = List<MediaItem>.from(await api.fetchTrendingShow());

      if (!mounted) return;

      final provider = Provider.of<MovieProvider>(context, listen: false);

      final moviesAsResults = movies
          .map((e) => provider.convertMediaItemToResult(e))
          .toList();
      final showsAsResults = shows
          .map((e) => provider.convertMediaItemToResult(e))
          .toList();

      setState(() {
        _allResults = [...moviesAsResults, ...showsAsResults];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      provider.clearSearchSelection();
      fetchTrendingMovies();
      return;
    }

    if (trimmedQuery == _lastQuery) return;
    _lastQuery = trimmedQuery;

    setState(() => _isLoading = true);

    try {
      // Search both sources in parallel for speed
      final results = await Future.wait([
        // 1. Feed backend (curated, fast)
        feedSearchService.search(trimmedQuery, limit: 20),
        // 2. TMDB (broader coverage)
        searchApi.getSearchitem(trimmedQuery),
      ]);

      final feedResults = results[0] as List<Result>;
      final tmdbResults = results[1] as List<Result>;

      // Merge results: feed first, then TMDB (deduplicated by ID)
      final seenIds = <int>{};
      final mergedResults = <Result>[];

      // Add feed results first (higher priority - curated content)
      for (final item in feedResults) {
        if (item.id != null && !seenIds.contains(item.id)) {
          seenIds.add(item.id!);
          mergedResults.add(item);
        }
      }

      // Add TMDB results (broader coverage)
      for (final item in tmdbResults) {
        if (item.id != null && !seenIds.contains(item.id)) {
          seenIds.add(item.id!);
          mergedResults.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _allResults = mergedResults
              .where((r) => r.mediaType != null && r.mediaType != 'unknown')
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allResults = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIOS = Platform.isIOS;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: theme.scaffoldBackgroundColor,
          title: _buildSearchHeader(theme, isIOS),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: _buildTabBar(theme),
          ),
        ),
        body: TabBarView(
          children: [
            _buildResultsGrid('all'),
            _buildResultsGrid('movie'),
            _buildResultsGrid('tv'),
            _buildResultsGrid('person'),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(ThemeData theme, bool isIOS) {
    return Row(
      children: [
        if (!isIOS)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        Expanded(
          child: Container(
            height: 40,

            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    style: theme.textTheme.bodyMedium,

                    decoration: const InputDecoration(
                      hintText: "Movies, shows, or people",
                      border: InputBorder.none,

                      contentPadding: EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    child: Icon(
                      isIOS ? CupertinoIcons.clear_thick_circled : Icons.cancel,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isIOS)
          CupertinoButton(
            padding: const EdgeInsets.only(left: 12),
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(fontSize: 16)),
          ),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return TabBar(
      indicatorColor: theme.primaryColor,
      labelColor: theme.textTheme.bodyLarge?.color,
      unselectedLabelColor: Colors.grey,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      tabs: const [
        Tab(text: "Top"),
        Tab(text: "Movies"),
        Tab(text: "TV Shows"),
        Tab(text: "People"),
      ],
    );
  }

  Widget _buildResultsGrid(String mediaType) {
    if (_isLoading) {
      return const Center(child: LogoLoadingScreen());
    }

    final filtered = mediaType == 'all'
        ? _allResults
        : _allResults.where((r) => r.mediaType == mediaType).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty
                    ? "Find your next favorite"
                    : 'No results for "${_searchController.text}"',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 20,
      ),
      itemCount: filtered.length,
      itemBuilder: (_, index) {
        final item = filtered[index];
        final isPerson = item.mediaType == 'person';

        final displayName = isPerson
            ? item.name ?? "Unknown"
            : (item.title ?? item.name ?? "Unknown");

        final imagePath = isPerson ? item.profilePath : item.posterPath;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  // Common tap handler
                  void handleTap() {
                    if (isPerson) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActorProfileScreen(
                            personId: item.id ?? 0,
                            personName: displayName,
                          ),
                        ),
                      );
                    } else {
                      provider.selectSearchItem(filtered, index);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GenericDetailsScreen(),
                        ),
                      );
                    }
                  }

                  // Poster Widget
                  final posterWidget = Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: getTmdbImageUrl(imagePath),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CupertinoActivityIndicator(),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: Image.asset(
                            'assets/noimage.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );

                  // If Person, just basic tap support
                  if (isPerson) {
                    return GestureDetector(
                      onTap: handleTap,
                      child: posterWidget,
                    );
                  }

                  // If Movie/Show, wrap in InteractiveMediaPoster
                  final mediaItem = MediaItem(
                    id: item.id ?? 0,
                    title: displayName,
                    overview: item.overview ?? '',
                    posterPath: item.posterPath ?? '',
                    backdropPath: item.backdropPath ?? '',
                    genreIds: item.genreIds ?? [],
                    voteAverage: item.voteAverage ?? 0.0,
                    mediaType: item.mediaType ?? 'movie',
                    releaseDate:
                        item.releaseDate?.toString() ??
                        item.firstAirDate?.toString() ??
                        '',
                    imageUrl: getTmdbImageUrl(item.posterPath),
                  );

                  return InteractiveMediaPoster(
                    item: mediaItem,
                    child: GestureDetector(
                      onTap: handleTap,
                      child: posterWidget,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                if (!isPerson) {
                  provider.selectSearchItem(filtered, index);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GenericDetailsScreen()),
                  );
                }
              },
              child: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            if (!isPerson &&
                (item.releaseDate != null || item.firstAirDate != null))
              Text(
                (item.releaseDate ?? item.firstAirDate)!.year.toString(),
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
          ],
        );
      },
    );
  }
}
