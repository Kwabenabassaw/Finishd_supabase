import 'package:finishd/Model/Searchdiscover.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/trending.dart';

import 'package:finishd/MovieDetails/movie_details_screen.dart';
import 'package:finishd/Widget/movie_action_drawer.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/tmbd/Search.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:provider/provider.dart';

Trending api = Trending();

// Utility for TMDB image URLs
String getTmdbImageUrl(String? path, {String size = 'w500'}) {
  if (path == null || path.isEmpty) {
    return 'https://via.placeholder.com/200x300?text=No+Image';
  }
  return 'https://image.tmdb.org/t/p/$size$path';
}

SearchDiscover search = SearchDiscover();

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Result> _allResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  MovieProvider get provider =>
      Provider.of<MovieProvider>(context, listen: false);

  String _lastQuery = '';

  void fetchTrendingMovies() async {
    try {
      final movies = List<MediaItem>.from(await api.fetchTrendingMovie());
      final shows = List<MediaItem>.from(await api.fetchTrendingShow());
      final popular = List<MediaItem>.from(await api.fetchpopularMovies());
      final upcoming = List<MediaItem>.from(await api.fetchUpcoming());

      final provider = Provider.of<MovieProvider>(context, listen: false);

      provider.setMovies(movies);
      provider.setShows(shows);
      provider.setPopular(popular);
      provider.setUpcoming(upcoming);
      _allResults = movies
          .map((e) => provider.convertMediaItemToResult(e))
          .toList(); // This line is causing the error

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        var error = e.toString();
        _isLoading = false;
        print(error);
      });
    }
  }

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
    super.dispose();
  }

  // 🔥 Debounce Search (fixed)
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  // --- Search Logic ---
  Future<void> _performSearch(String query) async {
    provider.clearSearchSelection();

    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      setState(() => _allResults = []);
      return;
    }

    if (trimmedQuery == _lastQuery) return;
    _lastQuery = trimmedQuery;

    setState(() => _isLoading = true);

    try {
      final results = await search.getSearchitem(trimmedQuery);

      setState(() {
        _allResults = results
            .where(
              (r) =>
                  r.mediaType != null &&
                  r.mediaType != '' &&
                  r.mediaType != 'unknown',
            )
            .toList();

        _isLoading = false;
      });
    } catch (e) {
      print("Search Error: $e");
      setState(() {
        _allResults = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(elevation: 1, title: _buildSearchField(isDark)),
        body: Column(
          children: [
            _buildTabBar(isDark),
            Expanded(
              child: TabBarView(
                children: [
                  _buildResultsGrid('all'),
                  _buildResultsGrid('movie'),
                  _buildResultsGrid('tv'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: "Search movies, shows, people...",
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(
          Icons.search,
          color: isDark ? Colors.white54 : Colors.grey,
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? Colors.grey.shade800 : Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return TabBar(
      indicatorColor: isDark ? Colors.white : Colors.black,
      labelColor: isDark ? Colors.white : Colors.black,
      unselectedLabelColor: Colors.grey,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      tabs: const [
        Tab(text: "All"),
        Tab(text: "Movies"),
        Tab(text: "TV Shows"),
      ],
    );
  }

  Widget _buildResultsGrid(String mediaType) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = mediaType == 'all'
        ? _allResults
        : _allResults.where((r) => r.mediaType == mediaType).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? "Start typing to search..."
              : 'No results found for "${_searchController.text}" in $mediaType.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (_, index) {
        final item = filtered[index];

        final displayName = item.mediaType == 'movie'
            ? item.title ?? "Unknown Movie"
            : item.mediaType == 'tv'
            ? item.name ?? "Unknown Show"
            : item.name ?? "Unknown Person";

        final imagePath = item.mediaType == 'person'
            ? item.profilePath ?? item.posterPath
            : item.posterPath;

        return GestureDetector(
          onLongPress: () {
            if (item.mediaType == 'person') return; // Skip for people

            // Convert Result to MovieListItem
            final movieItem = MovieListItem(
              id: item.id.toString(),
              title: displayName,
              posterPath: item.posterPath,
              mediaType: item.mediaType ?? 'movie',
              addedAt: DateTime.now(),
            );

            showMovieActionDrawer(context, movieItem);
          },
          onTap: () {
            provider.selectSearchItem(filtered, index);

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => GenericDetailsScreen()),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: getTmdbImageUrl(imagePath),
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: Colors.grey.shade300),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey,
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}
