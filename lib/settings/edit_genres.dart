import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:finishd/services/user_preferences_service.dart';

const Color primaryGreen = Color(0xFF1A8927);

// Genre data with TMDB IDs
class Genre {
  final String name;
  final String emoji;
  final int genreId;
  Genre(this.name, this.emoji, this.genreId);
}

final List<Genre> allGenres = [
  Genre('Drama', '🎭', 18),
  Genre('Comedy', '😂', 35),
  Genre('Romance', '💖', 10749),
  Genre('Action', '🔫', 28),
  Genre('Horror', '👻', 27),
  Genre('Sci-Fi', '🚀', 878),
  Genre('Documentary', '🎥', 99),
  Genre('Thriller', '🔪', 53),
  Genre('Animation', '✨', 16),
  Genre('Crime', '🕵️', 80),
  Genre('Fantasy', '🧙', 14),
  Genre('Mystery', '🔍', 9648),
];

class EditGenresScreen extends StatefulWidget {
  const EditGenresScreen({super.key});

  @override
  State<EditGenresScreen> createState() => _EditGenresScreenState();
}

class _EditGenresScreenState extends State<EditGenresScreen> {
  final UserPreferencesService _prefsService = UserPreferencesService();
  final int _minSelections = 3;

  Set<String> _selectedGenres = {};
  Set<int> _selectedGenreIds = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      final prefs = await _prefsService.getUserPreferences(userId);

      if (prefs != null) {
        _selectedGenres = Set.from(prefs.selectedGenres);
        _selectedGenreIds = Set.from(prefs.selectedGenreIds);
      }

      if (mounted) {
        setState(() => _isLoading = false);
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

  void _toggleGenre(Genre genre) {
    setState(() {
      if (_selectedGenres.contains(genre.name)) {
        _selectedGenres.remove(genre.name);
        _selectedGenreIds.remove(genre.genreId);
      } else {
        _selectedGenres.add(genre.name);
        _selectedGenreIds.add(genre.genreId);
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_selectedGenres.length < _minSelections) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least $_minSelections genres'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      await _prefsService.updateGenres(
        userId,
        _selectedGenres.toList(),
        _selectedGenreIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Genres updated!'),
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
    final canSave = _selectedGenres.length >= _minSelections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Genres'),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving || !canSave ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryGreen,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: canSave ? primaryGreen : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
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
                'What do you love to watch?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick at least $_minSelections genres you enjoy.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_selectedGenres.length} selected${_selectedGenres.length < _minSelections ? ' (need ${_minSelections - _selectedGenres.length} more)' : ''}',
                style: TextStyle(
                  color: _selectedGenres.length >= _minSelections
                      ? primaryGreen
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.25,
            ),
            itemCount: allGenres.length,
            itemBuilder: (context, index) {
              final genre = allGenres[index];
              final isSelected = _selectedGenres.contains(genre.name);

              return _GenreChip(
                genre: genre,
                isSelected: isSelected,
                onTap: () => _toggleGenre(genre),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  final Genre genre;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenreChip({
    required this.genre,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryGreen.withOpacity(0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(genre.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text(
              genre.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? primaryGreen : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
