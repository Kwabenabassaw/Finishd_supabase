import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/Searchdiscover.dart';
import 'package:finishd/MovieDetails/movie_details_screen.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/services/feed_search_service.dart';
import 'package:finishd/tmbd/Search.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/Model/trending.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;

/// Home Screen Search
///
/// Provides real-time search against the feed backend and TMDB.
/// Features:
/// - Debounced search (500ms)
/// - Trending suggestions when empty
/// - Combined feed + TMDB results
class SearchScreenHome extends StatefulWidget {
  const SearchScreenHome({super.key});

  @override
  State<SearchScreenHome> createState() => _SearchScreenHomeState();
}

class _SearchScreenHomeState extends State<SearchScreenHome> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FeedSearchService _feedSearchService = FeedSearchService();
  final SearchDiscover _tmdbSearchApi = SearchDiscover();
  final Trending _trendingApi = Trending();

  List<Result> _results = [];
  List<MediaItem> _trendingItems = [];
  bool _isLoading = false;
  bool _isLoadingTrending = true;
  Timer? _debounce;
  String _lastQuery = '';

  MovieProvider get provider =>
      Provider.of<MovieProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Load trending content for suggestions
  Future<void> _loadTrending() async {
    try {
      final results = await Future.wait([
        _trendingApi.fetchTrendingMovie(),
        _trendingApi.fetchTrendingShow(),
      ]);

      if (!mounted) return;

      final movies = results[0];
      final shows = results[1];

      // Interleave movies and shows, take top 10
      final combined = <MediaItem>[];
      final maxLen = movies.length > shows.length
          ? movies.length
          : shows.length;
      for (int i = 0; i < maxLen && combined.length < 10; i++) {
        if (i < movies.length) combined.add(movies[i]);
        if (i < shows.length && combined.length < 10) combined.add(shows[i]);
      }

      setState(() {
        _trendingItems = combined;
        _isLoadingTrending = false;
      });
    } catch (e) {
      debugPrint('Error loading trending: $e');
      if (mounted) {
        setState(() => _isLoadingTrending = false);
      }
    }
  }

  /// Debounced search handler
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  /// Perform search against feed backend + TMDB
  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      setState(() {
        _results = [];
        _lastQuery = '';
      });
      return;
    }

    if (trimmedQuery == _lastQuery) return;
    _lastQuery = trimmedQuery;

    setState(() => _isLoading = true);

    try {
      // Search both sources in parallel
      final results = await Future.wait([
        _feedSearchService.search(trimmedQuery, limit: 15),
        _tmdbSearchApi.getSearchitem(trimmedQuery),
      ]);

      final feedResults = results[0];
      final tmdbResults = results[1];

      // Merge: feed first (curated), then TMDB (deduplicated)
      final seenIds = <int>{};
      final mergedResults = <Result>[];

      for (final item in feedResults) {
        if (item.id != null && !seenIds.contains(item.id)) {
          seenIds.add(item.id!);
          mergedResults.add(item);
        }
      }

      for (final item in tmdbResults) {
        if (item.id != null && !seenIds.contains(item.id)) {
          seenIds.add(item.id!);
          mergedResults.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _results = mergedResults
              .where(
                (r) =>
                    r.mediaType != null &&
                    r.mediaType != 'unknown' &&
                    r.mediaType != 'person',
              )
              .take(20)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
    }
  }

  /// Navigate to movie/show details
  void _openDetails(Result item, int index) {
    provider.selectSearchItem(_results, index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GenericDetailsScreen()),
    );
  }

  /// Navigate to trending item details
  void _openTrendingDetails(MediaItem item) {
    // Convert to Result and navigate
    final result = provider.convertMediaItemToResult(item);
    provider.selectSearchItem([result], 0);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GenericDetailsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIOS = Platform.isIOS;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Header
            _buildSearchHeader(isDark, isIOS),

            // Content
            Expanded(
              child: _searchController.text.isEmpty
                  ? _buildTrendingSuggestions(isDark)
                  : _buildSearchResults(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark, bool isIOS) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isIOS ? CupertinoIcons.back : Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : Colors.black,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (value) {
                  setState(() {}); // Update UI for clear button
                  _onSearchChanged(value);
                },
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade500,
                    size: 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            isIOS
                                ? CupertinoIcons.clear_thick_circled
                                : Icons.cancel,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                            setState(() {});
                          },
                        )
                      : null,
                  hintText: "Search movies, shows...",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSuggestions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Trending Now",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isLoadingTrending)
                GestureDetector(
                  onTap: () {
                    setState(() => _isLoadingTrending = true);
                    _loadTrending();
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Refresh",
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Trending list
        Expanded(
          child: _isLoadingTrending
              ? const Center(child: CupertinoActivityIndicator())
              : _trendingItems.isEmpty
              ? Center(
                  child: Text(
                    "No trending content available",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _trendingItems.length,
                  itemBuilder: (context, index) {
                    final item = _trendingItems[index];
                    return _buildTrendingItem(item, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTrendingItem(MediaItem item, bool isDark) {
    return InkWell(
      onTap: () => _openTrendingDetails(item),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.posterPath.isNotEmpty
                    ? 'https://image.tmdb.org/t/p/w92${item.posterPath}'
                    : '',
                width: 50,
                height: 75,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 50,
                  height: 75,
                  color: Colors.grey.shade300,
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 50,
                  height: 75,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.movie, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(51),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.mediaType == 'tv' ? 'TV' : 'Movie',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Trending",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "${_searchController.text}"',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return _buildResultItem(item, index, isDark);
      },
    );
  }

  Widget _buildResultItem(Result item, int index, bool isDark) {
    final title = item.title ?? item.name ?? 'Unknown';
    final posterUrl = item.posterPath != null
        ? 'https://image.tmdb.org/t/p/w92${item.posterPath}'
        : '';
    final year = item.releaseDate?.year ?? item.firstAirDate?.year;

    return InkWell(
      onTap: () => _openDetails(item, index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: posterUrl,
                width: 50,
                height: 75,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 50,
                  height: 75,
                  color: Colors.grey.shade300,
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 50,
                  height: 75,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.movie, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(51),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.mediaType == 'tv' ? 'TV' : 'Movie',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (year != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          year.toString(),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (item.voteAverage != null &&
                          item.voteAverage! > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          item.voteAverage!.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
