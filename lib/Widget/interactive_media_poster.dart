import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    HapticFeedback.mediumImpact();

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    await showMenu(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'watching',
          child: ListTile(
            leading: Icon(Icons.play_circle_outline),
            title: Text('Watching'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'watchlist',
          child: ListTile(
            leading: Icon(Icons.bookmark_outline),
            title: Text('Watch Later'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'finishd',
          child: ListTile(
            leading: Image.asset('assets/FINISHD.png', width: 60, height: 60),
            title: const Text('Finishd'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'favorites',
          child: ListTile(
            leading: Icon(Icons.favorite_outline),
            title: Text('Favorite'),
            dense: true,
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleAction(context, value);
      }
    });
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
