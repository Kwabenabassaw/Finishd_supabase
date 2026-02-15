import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:finishd/services/user_preferences_service.dart';
import 'package:finishd/tmbd/Search.dart';
import 'package:finishd/tmbd/fetchDiscover.dart';

const Color primaryGreen = Color(0xFF1A8927);

class EditFavoriteContentScreen extends StatefulWidget {
  const EditFavoriteContentScreen({super.key});

  @override
  State<EditFavoriteContentScreen> createState() =>
      _EditFavoriteContentScreenState();
}

class _EditFavoriteContentScreenState extends State<EditFavoriteContentScreen> {
  final UserPreferencesService _prefsService = UserPreferencesService();
  final Fetchdiscover _fetchDiscover = Fetchdiscover();
  final SearchDiscover _searchApi = SearchDiscover();
  final TextEditingController _searchController = TextEditingController();

  List<MediaItem>? _discoverContent;
  final Map<String, SelectedMedia> _selectedMovies = {};
  final Map<String, SelectedMedia> _selectedShows = {};

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      // Load discover content and user preferences in parallel
      final results = await Future.wait([
        _fetchDiscover.fetchDiscover(),
        _prefsService.getUserPreferences(userId),
      ]);

      final content = results[0] as List<MediaItem>;
      final prefs = results[1] as UserPreferences?;

      // Build selected maps from existing preferences
      if (prefs != null) {
        for (final movie in prefs.selectedMovies) {
          _selectedMovies['${movie.id}_movie'] = movie;
        }
        for (final show in prefs.selectedShows) {
          _selectedShows['${show.id}_tv'] = show;
        }
      }

      if (mounted) {
        setState(() {
          _discoverContent = content;
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

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
      });
      await _loadData();
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _searchApi.getSearch(query);
      if (mounted) {
        setState(() {
          _discoverContent = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _toggleMedia(MediaItem item) {
    final key = '${item.id}_${item.mediaType}';

    setState(() {
      if (item.mediaType == 'movie') {
        if (_selectedMovies.containsKey(key)) {
          _selectedMovies.remove(key);
        } else {
          _selectedMovies[key] = SelectedMedia(
            id: item.id,
            title: item.title,
            posterPath: item.posterPath,
            mediaType: item.mediaType,
          );
        }
      } else {
        if (_selectedShows.containsKey(key)) {
          _selectedShows.remove(key);
        } else {
          _selectedShows[key] = SelectedMedia(
            id: item.id,
            title: item.title,
            posterPath: item.posterPath,
            mediaType: item.mediaType,
          );
        }
      }
    });
  }

  bool _isSelected(MediaItem item) {
    final key = '${item.id}_${item.mediaType}';
    return _selectedMovies.containsKey(key) || _selectedShows.containsKey(key);
  }

  Future<void> _saveChanges() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      // Save movies
      await _prefsService.updateSelectedMovies(
        userId,
        _selectedMovies.values.map((m) => m.toJson()).toList(),
      );

      // Save shows
      await _prefsService.updateSelectedShows(
        userId,
        _selectedShows.values.map((s) => s.toJson()).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Favorites updated!'),
            backgroundColor: primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSelected = _selectedMovies.length + _selectedShows.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Content'),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryGreen,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _buildBody(isDark, totalSelected),
    );
  }

  Widget _buildBody(bool isDark, int totalSelected) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shows & movies you love',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select content you\'ve enjoyed for personalized recommendations.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$totalSelected selected',
                style: const TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                // Debounce search
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (value == _searchController.text) {
                    _performSearch(value);
                  }
                });
              },
              decoration: InputDecoration(
                hintText: 'Search movies & shows...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(top: 15),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Content grid
        if (_isSearching)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.65,
              ),
              itemCount: _discoverContent?.length ?? 0,
              itemBuilder: (context, index) {
                final item = _discoverContent![index];
                final isSelected = _isSelected(item);

                return _PosterTile(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => _toggleMedia(item),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PosterTile extends StatelessWidget {
  final MediaItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _PosterTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: "https://image.tmdb.org/t/p/w500${item.posterPath}",
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.movie, color: Colors.grey),
              ),
            ),
          ),
          // Selection overlay
          if (isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.5),
                  border: Border.all(color: primaryGreen, width: 3),
                ),
              ),
            ),
          // Checkmark
          if (isSelected)
            const Positioned(
              top: 5,
              right: 5,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: primaryGreen,
                child: Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
          // Media type badge
          Positioned(
            bottom: 5,
            left: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.mediaType == 'movie' ? 'Movie' : 'TV',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
