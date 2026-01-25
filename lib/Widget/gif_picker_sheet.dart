import 'package:flutter/material.dart';
import 'package:finishd/models/gif_model.dart';
import 'package:finishd/services/klipy_service.dart';
import 'dart:async';

/// Reusable bottom sheet for selecting GIFs
/// Uses Klipy API for search and trending GIFs
class GifPickerSheet extends StatefulWidget {
  const GifPickerSheet({super.key});

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet>
    with SingleTickerProviderStateMixin {
  final KlipyService _klipyService = KlipyService();
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  List<GifModel> _gifs = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  late TabController _tabController;
  int _currentTab = 0; // 0 = Trending, 1 = Search

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTab) {
        setState(() {
          _currentTab = _tabController.index;
          _errorMessage = null;
        });
        if (_currentTab == 0) {
          _loadTrendingGifs();
        }
      }
    });
    _loadTrendingGifs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrendingGifs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final gifs = await _klipyService.getTrendingGifs(limit: 30);
      if (mounted) {
        setState(() {
          _gifs = gifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _gifs = [];
      });
      return;
    }

    // Debounce search by 500ms
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchGifs(query.trim());
    });
  }

  Future<void> _searchGifs(String query) async {
    setState(() {
      _isSearching = true;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final gifs = await _klipyService.searchGifs(query: query, limit: 30);
      if (mounted) {
        setState(() {
          _gifs = gifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryGreen = Color(0xFF1A8927);

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.5,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                child: Row(
                  children: [
                    Text(
                      'Choose a GIF',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onTap: () {
                    // Expand to full height when search is tapped
                    _sheetController.animateTo(
                      0.95,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search GIFs...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Tabs
              if (!_isSearching)
                TabBar(
                  controller: _tabController,
                  labelColor: primaryGreen,
                  unselectedLabelColor: theme.hintColor,
                  indicatorColor: primaryGreen,
                  tabs: const [
                    Tab(text: 'Trending'),
                    Tab(text: 'Search'),
                  ],
                ),

              // Content
              Expanded(
                child: _buildContent(theme, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ThemeData theme, ScrollController scrollController) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1A8927),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.hintColor,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_isSearching && _searchController.text.isNotEmpty) {
                    _searchGifs(_searchController.text.trim());
                  } else {
                    _loadTrendingGifs();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A8927),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_gifs.isEmpty) {
      return CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: theme.hintColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSearching
                          ? 'No GIFs found.\nTry a different search term.'
                          : 'Start typing to search for GIFs',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.hintColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _gifs.length,
      itemBuilder: (context, index) {
        final gif = _gifs[index];
        return _buildGifTile(gif);
      },
    );
  }

  Widget _buildGifTile(GifModel gif) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, gif),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              gif.previewUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1A8927),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                  ),
                );
              },
            ),
            // Tap indicator
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context, gif),
                splashColor: const Color(0xFF1A8927).withOpacity(0.3),
                highlightColor: const Color(0xFF1A8927).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
