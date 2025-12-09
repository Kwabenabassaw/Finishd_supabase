import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Model/movie_item.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/profile/MoviePosterGrid.dart';
import 'package:finishd/tmbd/fetchDiscover.dart';
import 'package:flutter/material.dart';

class ProviderContentScreen extends StatefulWidget {
  final int providerId;
  final String providerName;

  const ProviderContentScreen({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<ProviderContentScreen> createState() => _ProviderContentScreenState();
}

class _ProviderContentScreenState extends State<ProviderContentScreen> {
  final Fetchdiscover _fetchDiscover = Fetchdiscover();
  final ScrollController _scrollController = ScrollController();

  List<MediaItem> _movies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMovies();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && !_isLoading) {
        _loadMoreMovies();
      }
    }
  }

  Future<void> _fetchMovies() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final movies = await _fetchDiscover.fetchContentByProvider(
        widget.providerId,
        page: 1,
      );

      if (mounted) {
        setState(() {
          _movies = movies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreMovies() async {
    try {
      setState(() {
        _isLoadingMore = true;
      });

      final nextPage = _currentPage + 1;
      final newMovies = await _fetchDiscover.fetchContentByProvider(
        widget.providerId,
        page: nextPage,
      );

      if (mounted) {
        setState(() {
          _movies.addAll(newMovies);
          _currentPage = nextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // Optionally show snackbar for pagination error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.providerName),
    
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: LogoLoadingScreen())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading content: $_error'),
                  ElevatedButton(
                    onPressed: _fetchMovies,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _movies.isEmpty
          ? const Center(child: Text('No content available for this provider.'))
          : SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  MoviePosterGrid(
                    physics: const NeverScrollableScrollPhysics(),
                    movies: _movies.map((item) {
                      return MovieItem(
                        id: item.id,
                        title: item.title,
                        posterPath: item.posterPath ?? '',
                        mediaType: item.mediaType,
                        genre: item.mediaType == 'tv' ? 'TV Show' : 'Movie',
                      );
                    }).toList(),
                  ),
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
    );
  }
}
