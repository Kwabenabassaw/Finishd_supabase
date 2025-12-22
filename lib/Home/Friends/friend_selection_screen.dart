import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/services/user_service.dart';

class FriendSelectionScreen extends StatefulWidget {
  final MovieListItem movie;

  const FriendSelectionScreen({super.key, required this.movie});

  @override
  State<FriendSelectionScreen> createState() => _FriendSelectionScreenState();
}

class _FriendSelectionScreenState extends State<FriendSelectionScreen> {
  final UserService _userService = UserService();
  final RecommendationService _recommendationService = RecommendationService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<UserModel> _friends = [];
  Set<String> _selectedUserIds = {};
  Set<String> _alreadyRecommendedUserIds =
      {}; // Friends who already got this movie
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    if (_currentUserId.isEmpty) return;
    try {
      // Fetch friends and already-recommended users in parallel
      final followerIdsFuture = _userService.getFollowers(_currentUserId);
      final alreadyRecommendedFuture = _recommendationService
          .getAlreadyRecommendedFriends(
            fromUserId: _currentUserId,
            movieId: widget.movie.id,
          );

      final results = await Future.wait([
        followerIdsFuture,
        alreadyRecommendedFuture,
      ]);
      final List<String> followerIds = results[0] as List<String>;
      final Set<String> alreadyRecommended = results[1] as Set<String>;

      List<UserModel> friends = await _userService.getUsers(followerIds);

      if (mounted) {
        setState(() {
          _friends = friends;
          _alreadyRecommendedUserIds = alreadyRecommended;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching friends: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendRecommendation() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final result = await _recommendationService.sendRecommendation(
        fromUserId: _currentUserId,
        toUserIds: _selectedUserIds.toList(),
        movie: widget.movie,
      );

      final int sent = result['sent'] ?? 0;
      final int skipped = result['skipped'] ?? 0;

      if (mounted) {
        String message;
        if (sent > 0 && skipped == 0) {
          message = 'Recommended to $sent friend${sent > 1 ? 's' : ''}!';
        } else if (sent > 0 && skipped > 0) {
          message =
              'Recommended to $sent friend${sent > 1 ? 's' : ''}. $skipped already had it.';
        } else {
          message = 'Already recommended to all selected friends!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: sent > 0 ? const Color(0xFF1A8927) : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Close screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending recommendation: $e')),
        );
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommend to...',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_selectedUserIds.isNotEmpty)
              Text(
                '${_selectedUserIds.length} selected',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _selectedUserIds.isNotEmpty ? 1.0 : 0.5,
                child: FilledButton(
                  onPressed: _selectedUserIds.isNotEmpty && !_isSending
                      ? _sendRecommendation
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Send',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 80,
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No friends found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add friends to share recommendations',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Movie preview header
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.movie.posterPath != null
                                ? 'https://image.tmdb.org/t/p/w200${widget.movie.posterPath}'
                                : 'https://via.placeholder.com/200x300',
                            width: 56,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.movie.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.movie.mediaType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).primaryColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Section Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      'YOUR FRIENDS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.5),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),

                // Friends list
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final user = _friends[index];
                      final isSelected = _selectedUserIds.contains(user.uid);
                      final isAlreadyRecommended = _alreadyRecommendedUserIds
                          .contains(user.uid);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isAlreadyRecommended
                                ? null
                                : () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedUserIds.remove(user.uid);
                                      } else {
                                        _selectedUserIds.add(user.uid);
                                      }
                                    });
                                  },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected && !isAlreadyRecommended
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.05)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected && !isAlreadyRecommended
                                      ? Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.3)
                                      : Theme.of(
                                          context,
                                        ).dividerColor.withOpacity(0.05),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Profile Image
                                  Stack(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                isSelected &&
                                                    !isAlreadyRecommended
                                                ? Theme.of(context).primaryColor
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Opacity(
                                          opacity: isAlreadyRecommended
                                              ? 0.5
                                              : 1.0,
                                          child: CircleAvatar(
                                            radius: 28,
                                            backgroundColor: Theme.of(
                                              context,
                                            ).dividerColor.withOpacity(0.1),
                                            backgroundImage:
                                                user.profileImage.isNotEmpty
                                                ? CachedNetworkImageProvider(
                                                    user.profileImage,
                                                  )
                                                : const AssetImage(
                                                        'assets/noimage.jpg',
                                                      )
                                                      as ImageProvider,
                                          ),
                                        ),
                                      ),
                                      if (isSelected && !isAlreadyRecommended)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).scaffoldBackgroundColor,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),

                                  // User Info
                                  Expanded(
                                    child: Opacity(
                                      opacity: isAlreadyRecommended ? 0.5 : 1.0,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.username.isNotEmpty
                                                ? user.username
                                                : 'User',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            user.firstName.isNotEmpty
                                                ? '${user.firstName} ${user.lastName}'
                                                : user.email,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Status or Checkbox
                                  if (isAlreadyRecommended)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).dividerColor.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                      ),
                                      child: Text(
                                        'Sent',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withOpacity(0.5),
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    )
                                  else
                                    _buildCustomCheckbox(context, isSelected),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }, childCount: _friends.length),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomCheckbox(BuildContext context, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).dividerColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}
