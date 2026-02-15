import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/services/movie_list_service.dart';
import 'package:finishd/provider/MovieProvider.dart';
import 'package:finishd/models/friend_activity.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InteractiveMediaPoster extends StatelessWidget {
  final MediaItem item;
  final Widget child;
  final VoidCallback? onActionComplete;
  final bool showSocialBadges;

  const InteractiveMediaPoster({
    super.key,
    required this.item,
    required this.child,
    this.onActionComplete,
    this.showSocialBadges = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (Platform.isIOS)
          _buildIOSMenu(context)
        else
          _buildAndroidMenu(context),
        if (showSocialBadges)
          Positioned(
            bottom: 8,
            left: 8,
            child: _SocialAvatarsBadge(itemId: item.id.toString()),
          ),
      ],
    );
  }

  Widget _buildIOSMenu(BuildContext context) {
    return CupertinoContextMenu(
      actions: _buildCupertinoActions(context),
      child: child,
    );
  }

  Widget _buildAndroidMenu(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        _showAndroidMenu(context, details.globalPosition);
      },
      child: child,
    );
  }

  List<Widget> _buildCupertinoActions(BuildContext context) {
    return [
      CupertinoContextMenuAction(
        onPressed: () {
          _handleAction(context, 'watching');
          Navigator.pop(context);
        },
        trailingIcon: CupertinoIcons.play_circle,
        child: const Text('Watching'),
      ),
      CupertinoContextMenuAction(
        onPressed: () {
          _handleAction(context, 'watchlist');
          Navigator.pop(context);
        },
        trailingIcon: CupertinoIcons.bookmark,
        child: const Text('Watch Later'),
      ),
      CupertinoContextMenuAction(
        onPressed: () {
          _handleAction(context, 'finished');
          Navigator.pop(context);
        },
        trailingIcon: CupertinoIcons.check_mark_circled,
        child: const Text('Finished'),
      ),
      CupertinoContextMenuAction(
        onPressed: () {
          _handleAction(context, 'favorites');
          Navigator.pop(context);
        },
        trailingIcon: CupertinoIcons.heart,
        child: const Text('Favorite'),
      ),
    ];
  }

  void _showAndroidMenu(BuildContext context, Offset position) async {
    HapticFeedback.heavyImpact();

    // Get the render box for position calculations
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    // Show the blur preview overlay
    Navigator.of(context).push(
      _BlurPreviewRoute(
        item: item,
        childSize: size,
        childOffset: offset,
        posterUrl: "https://image.tmdb.org/t/p/w500${item.posterPath}",
        onAction: (action) => _handleAction(context, action),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save movies')),
      );
      return;
    }

    final MovieListService service = MovieListService();
    final movieListItem = MovieListItem(
      id: item.id.toString(),
      title: item.title,
      posterPath: item.posterPath,
      mediaType: item.mediaType,
      addedAt: DateTime.now(),
    );

    try {
      String message = '';
      switch (action) {
        case 'watching':
          await service.addToWatching(uid, movieListItem);
          message = 'Added to Currently Watching';
          break;
        case 'watchlist':
          await service.addToWatchlist(uid, movieListItem);
          message = 'Added to Watch Later';
          break;
        case 'finished':
          await service.addToFinished(uid, movieListItem);
          message = 'Added to Finished';
          break;
        case 'favorites':
          await service.toggleFavorite(uid, movieListItem);
          message = 'Updated Favorites';
          break;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        onActionComplete?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _SocialAvatarsBadge extends StatelessWidget {
  final String itemId;

  const _SocialAvatarsBadge({required this.itemId});

  @override
  Widget build(BuildContext context) {
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);

    return StreamBuilder<List<FriendActivity>>(
      stream: movieProvider.getSocialStream(itemId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final allActivities = snapshot.data!;

        // Defensive filtering: Ensure unique friendUid per itemId
        final Map<String, FriendActivity> uniqueMap = {};
        for (var activity in allActivities) {
          uniqueMap[activity.friendUid] = activity;
        }
        final activities = uniqueMap.values.toList();

        // Show max 3 avatars
        final displayActivities = activities.take(3).toList();
        final extraCount = activities.length - displayActivities.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 18,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayActivities.length,
                  itemBuilder: (context, index) {
                    final activity = displayActivities[index];
                    return Align(
                      widthFactor: 0.6,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: activity.avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(activity.avatarUrl)
                              : null,
                          child: activity.avatarUrl.isEmpty
                              ? Text(
                                  activity.friendName.isNotEmpty
                                      ? activity.friendName
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (extraCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '+$extraCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// PUBLIC HELPER FUNCTION - Show blur preview from any widget
// ============================================================

/// Show the blur preview overlay for a media item
/// Call this from any widget's onLongPress to show the iOS-style preview
void showBlurPreview({
  required BuildContext context,
  required MediaItem item,
  required Size childSize,
  required Offset childOffset,
}) {
  HapticFeedback.heavyImpact();

  Navigator.of(context).push(
    _BlurPreviewRoute(
      item: item,
      childSize: childSize,
      childOffset: childOffset,
      posterUrl: "https://image.tmdb.org/t/p/w500${item.posterPath}",
      onAction: (action) => _handleActionStatic(context, item, action),
    ),
  );
}

/// Static action handler for use with the public helper
Future<void> _handleActionStatic(
  BuildContext context,
  MediaItem item,
  String action,
) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save movies')),
      );
    }
    return;
  }

  final MovieListService service = MovieListService();
  final movieListItem = MovieListItem(
    id: item.id.toString(),
    title: item.title,
    posterPath: item.posterPath,
    mediaType: item.mediaType,
    addedAt: DateTime.now(),
  );

  try {
    String message = '';
    switch (action) {
      case 'watching':
        await service.addToWatching(uid, movieListItem);
        message = 'Added to Currently Watching';
        break;
      case 'watchlist':
        await service.addToWatchlist(uid, movieListItem);
        message = 'Added to Watch Later';
        break;
      case 'finished':
        await service.addToFinished(uid, movieListItem);
        message = 'Added to Finished';
        break;
      case 'favorites':
        await service.toggleFavorite(uid, movieListItem);
        message = 'Updated Favorites';
        break;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ============================================================
// BLUR PREVIEW ROUTE - iOS-style long press preview for Android
// ============================================================

class _BlurPreviewRoute extends PopupRoute {
  final MediaItem item;
  final Size childSize;
  final Offset childOffset;
  final String posterUrl;
  final Function(String action) onAction;

  _BlurPreviewRoute({
    required this.item,
    required this.childSize,
    required this.childOffset,
    required this.posterUrl,
    required this.onAction,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _BlurPreviewContent(
      item: item,
      childSize: childSize,
      childOffset: childOffset,
      posterUrl: posterUrl,
      animation: animation,
      onAction: onAction,
    );
  }
}

class _BlurPreviewContent extends StatefulWidget {
  final MediaItem item;
  final Size childSize;
  final Offset childOffset;
  final String posterUrl;
  final Animation<double> animation;
  final Function(String action) onAction;

  const _BlurPreviewContent({
    required this.item,
    required this.childSize,
    required this.childOffset,
    required this.posterUrl,
    required this.animation,
    required this.onAction,
  });

  @override
  State<_BlurPreviewContent> createState() => _BlurPreviewContentState();
}

class _BlurPreviewContentState extends State<_BlurPreviewContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );

    // Start bounce animation
    _bounceController.forward().then((_) {
      _bounceController.reverse();
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleAction(String action) {
    Navigator.of(context).pop();
    widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Calculate the center position for the preview
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height * 0.35;

    // Calculate preview size (larger than original)
    final previewWidth = widget.childSize.width * 1.4;
    final previewHeight = widget.childSize.height * 1.4;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedBuilder(
        animation: widget.animation,
        builder: (context, child) {
          final curvedAnimation = CurvedAnimation(
            parent: widget.animation,
            curve: Curves.easeOutCubic,
          );

          // Interpolate from original position to center
          final currentX = lerpDouble(
            widget.childOffset.dx + widget.childSize.width / 2,
            centerX,
            curvedAnimation.value,
          )!;
          final currentY = lerpDouble(
            widget.childOffset.dy + widget.childSize.height / 2,
            centerY,
            curvedAnimation.value,
          )!;

          // Interpolate size
          final currentWidth = lerpDouble(
            widget.childSize.width,
            previewWidth,
            curvedAnimation.value,
          )!;
          final currentHeight = lerpDouble(
            widget.childSize.height,
            previewHeight,
            curvedAnimation.value,
          )!;

          return Stack(
            children: [
              // Blurred background
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 15 * curvedAnimation.value,
                    sigmaY: 15 * curvedAnimation.value,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(
                      0.6 * curvedAnimation.value,
                    ),
                  ),
                ),
              ),

              // Animated poster
              Positioned(
                left: currentX - currentWidth / 2,
                top: currentY - currentHeight / 2,
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _bounceAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: currentWidth,
                    height: currentHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 25 * curvedAnimation.value,
                          spreadRadius: 5 * curvedAnimation.value,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CachedNetworkImage(
                        imageUrl: widget.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[900]),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[850],
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Title and actions below the poster
              if (curvedAnimation.value > 0.5)
                Positioned(
                  left: 20,
                  right: 20,
                  top: centerY + previewHeight / 2 + 24,
                  bottom: 20,
                  child: Opacity(
                    opacity: (curvedAnimation.value - 0.5) * 2,
                    child: Material(
                      color: Colors.transparent,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title
                            Text(
                              widget.item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Media type
                            Text(
                              widget.item.mediaType == 'movie'
                                  ? 'Movie'
                                  : 'TV Show',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Action Buttons
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[900]!.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  _buildActionButton(
                                    icon: Icons.play_circle_outline,
                                    label: 'Watching',
                                    onTap: () => _handleAction('watching'),
                                  ),
                                  _divider(),
                                  _buildActionButton(
                                    icon: Icons.bookmark_outline,
                                    label: 'Watch Later',
                                    onTap: () => _handleAction('watchlist'),
                                  ),
                                  _divider(),
                                  _buildActionButton(
                                    icon: Icons.check_circle_outline,
                                    label: 'Finishd',
                                    onTap: () => _handleAction('finished'),
                                  ),
                                  _divider(),
                                  _buildActionButton(
                                    icon: Icons.favorite_outline,
                                    label: 'Favorite',
                                    onTap: () => _handleAction('favorites'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withOpacity(0.15),
    );
  }
}
