import 'package:flutter/material.dart';
import 'package:finishd/services/community_service.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/Community/community_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommunityAvatarList extends StatefulWidget {
  const CommunityAvatarList({super.key});

  @override
  State<CommunityAvatarList> createState() => _CommunityAvatarListState();
}

class _CommunityAvatarListState extends State<CommunityAvatarList> {
  final CommunityService _communityService = CommunityService();
  List<Community> _trendingCommunities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrendingCommunities();
  }

  Future<void> _fetchTrendingCommunities() async {
    try {
      final List<Map<String, dynamic>> data = await _communityService
          .discoverCommunities(limit: 10);
      if (mounted) {
        setState(() {
          _trendingCommunities = data
              .map((json) => Community.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching trending communities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }

    if (_trendingCommunities.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _trendingCommunities.length,
        itemBuilder: (context, index) {
          final community = _trendingCommunities[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunityDetailScreen(
                      showId: community.showId,
                      showTitle: community.title,
                      posterPath: community.posterPath,
                      mediaType: community.mediaType,
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.green, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[900],
                      backgroundImage: community.posterPath != null
                          ? CachedNetworkImageProvider(
                              'https://image.tmdb.org/t/p/w200${community.posterPath}',
                            )
                          : null,
                      child: community.posterPath == null
                          ? const Icon(
                              Icons.people,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 60,
                    child: Text(
                      community.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
