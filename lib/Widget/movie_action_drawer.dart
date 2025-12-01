import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Home/Friends/friend_selection_screen.dart';

/// Interactive bottom sheet drawer for movie list actions
/// Allows users to add movies to watching, watchlist, finished, or favorites
class MovieActionDrawer extends StatefulWidget {
  final MovieListItem movie;
  final VoidCallback? onActionComplete;

  const MovieActionDrawer({
    super.key,
    required this.movie,
    this.onActionComplete,
  });

  @override
  State<MovieActionDrawer> createState() => _MovieActionDrawerState();
}

class _MovieActionDrawerState extends State<MovieActionDrawer> {
  final MovieListService _movieListService = MovieListService();
  bool _isLoading = false;
  Map<String, bool> _movieStatus = {
    'watching': false,
    'watchlist': false,
    'finished': false,
    'favorites': false,
  };

  @override
  void initState() {
    super.initState();
    _loadMovieStatus();
  }

  Future<void> _loadMovieStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final status = await _movieListService.getMovieStatus(
        uid,
        widget.movie.id,
      );
      if (mounted) {
        setState(() {
          _movieStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAction(String action) async {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save movies')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      switch (action) {
        case 'watching':
          await _movieListService.addToWatching(uid, widget.movie);
          _showSuccessMessage('Added to Currently Watching');
          break;
        case 'watchlist':
          await _movieListService.addToWatchlist(uid, widget.movie);
          _showSuccessMessage('Added to Watch Later');
          break;
        case 'finished':
          await _movieListService.addToFinished(uid, widget.movie);
          _showSuccessMessage('Added to Finished');
          break;
        case 'favorites':
          await _movieListService.toggleFavorite(uid, widget.movie);
          final isFavorite = !_movieStatus['favorites']!;
          _showSuccessMessage(
            isFavorite ? 'Added to Favorites' : 'Removed from Favorites',
          );
          break;
        case 'remove':
          // Find which list the movie is in and remove
          final currentList = _getCurrentList();
          if (currentList != null) {
            await _movieListService.removeFromList(
              uid,
              widget.movie.id,
              currentList,
            );
            _showSuccessMessage('Removed from list');
          }
          break;
      }

      // Reload status
      await _loadMovieStatus();

      // Callback for parent to refresh
      widget.onActionComplete?.call();

      // Close drawer after action
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String? _getCurrentList() {
    if (_movieStatus['watching']!) return 'watching';
    if (_movieStatus['watchlist']!) return 'watchlist';
    if (_movieStatus['finished']!) return 'finished';
    return null;
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getTmdbImageUrl(String? path) {
    if (path == null || path.isEmpty) {
      return 'https://via.placeholder.com/200x300?text=No+Image';
    }
    return 'https://image.tmdb.org/t/p/w200$path';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Movie preview header
          Row(
            children: [
              // Movie poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _getTmdbImageUrl(widget.movie.posterPath),
                  width: 60,
                  height: 90,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade300,
                    width: 60,
                    height: 90,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey,
                    width: 60,
                    height: 90,
                    child: const Icon(Icons.error, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Movie title and type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movie.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.movie.mediaType == 'movie' ? 'Movie' : 'TV Show',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
          else
            // Action buttons
            Column(
              children: [
                _buildActionTile(
                  icon: Icons.play_circle_outline,
                  title: 'Currently Watching',
                  isActive: _movieStatus['watching']!,
                  onTap: () => _handleAction('watching'),
                ),
                _buildActionTile(
                  icon: Icons.bookmark_outline,
                  title: 'Watch Later',
                  isActive: _movieStatus['watchlist']!,
                  onTap: () => _handleAction('watchlist'),
                ),
                _buildActionTile(
                  icon: Icons.check_circle_outline,
                  title: 'Finished Watching',
                  isActive: _movieStatus['finished']!,
                  onTap: () => _handleAction('finished'),
                ),
                _buildActionTile(
                  icon: _movieStatus['favorites']!
                      ? Icons.favorite
                      : Icons.favorite_outline,
                  title: _movieStatus['favorites']!
                      ? 'Remove from Favorites'
                      : 'Add to Favorites',
                  isActive: _movieStatus['favorites']!,
                  onTap: () => _handleAction('favorites'),
                  iconColor: _movieStatus['favorites']! ? Colors.red : null,
                ),
                _buildActionTile(
                  icon: Icons.share_outlined,
                  title: 'Recommend to...',
                  isActive: false,
                  onTap: () {
                    Navigator.pop(context); // Close drawer first
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FriendSelectionScreen(movie: widget.movie),
                      ),
                    );
                  },
                ),

                // Show remove option if movie is in any list
                if (_getCurrentList() != null) ...[
                  const Divider(height: 24),
                  _buildActionTile(
                    icon: Icons.delete_outline,
                    title: 'Remove from List',
                    isActive: false,
                    onTap: () => _handleAction('remove'),
                    iconColor: Colors.red.shade400,
                  ),
                ],
              ],
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? (isActive ? Colors.green : Colors.grey.shade700),
        size: 28,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive ? Colors.green.shade700 : Colors.black87,
        ),
      ),
      trailing: isActive
          ? Icon(Icons.check, color: Colors.green.shade700, size: 24)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: Colors.grey.shade100,
    );
  }
}

/// Helper function to show the movie action drawer
void showMovieActionDrawer(
  BuildContext context,
  MovieListItem movie, {
  VoidCallback? onActionComplete,
}) {
  // Check authentication first
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in to save movies')),
    );
    return;
  }

  // Haptic feedback
  HapticFeedback.mediumImpact();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        MovieActionDrawer(movie: movie, onActionComplete: onActionComplete),
  );
}
