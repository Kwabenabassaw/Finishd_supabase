import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/recommendation_model.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/recommendation_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:intl/intl.dart';

class MovieRecommendersScreen extends StatefulWidget {
  final String movieId;
  final String movieTitle;

  const MovieRecommendersScreen({
    super.key,
    required this.movieId,
    required this.movieTitle,
  });

  @override
  State<MovieRecommendersScreen> createState() =>
      _MovieRecommendersScreenState();
}

class _MovieRecommendersScreenState extends State<MovieRecommendersScreen> {
  final RecommendationService _recommendationService = RecommendationService();
  final UserService _userService = UserService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommended by',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.movieTitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Recommendation>>(
        stream: _recommendationService.getMyRecommendationsForMovie(
          _currentUserId,
          widget.movieId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading recommendations',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final recommendations = snapshot.data ?? [];

          if (recommendations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recommendations yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nobody has recommended this to you',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {}); // Trigger rebuild to refresh stream
            },
            color: const Color(0xFF1A8927),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final recommendation = recommendations[index];
                return FutureBuilder<UserModel?>(
                  future: _userService.getUser(recommendation.fromUserId),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData || userSnapshot.data == null) {
                      return const SizedBox.shrink();
                    }

                    final user = userSnapshot.data!;
                    return _buildRecommenderCard(user, recommendation);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommenderCard(UserModel user, Recommendation recommendation) {
    final timeAgo = _getTimeAgo(recommendation.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // TODO: Navigate to user profile
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => UserProfileScreen(userId: user.uid),
            //   ),
            // );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Image
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1A8927).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: user.profileImage.isNotEmpty
                            ? CachedNetworkImageProvider(user.profileImage)
                            : const AssetImage('assets/noimage.jpg')
                                  as ImageProvider,
                      ),
                    ),
                    // Online indicator (optional)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A8927),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username.isNotEmpty ? user.username : 'User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (user.firstName.isNotEmpty)
                        Text(
                          '${user.firstName} ${user.lastName}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Recommended $timeAgo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow icon
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return DateFormat('MMM d, yyyy').format(timestamp);
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
