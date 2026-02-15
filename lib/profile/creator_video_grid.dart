import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/settings/edit_genres.dart';
import 'package:finishd/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreatorVideoGrid extends StatefulWidget {
  final String userId;

  const CreatorVideoGrid({super.key, required this.userId});

  @override
  State<CreatorVideoGrid> createState() => _CreatorVideoGridState();
}

class _CreatorVideoGridState extends State<CreatorVideoGrid> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      final response = await _supabase
          .from('creator_videos')
          .select()
          .eq('creator_id', widget.userId)
          .eq(
            'status',
            'approved',
          ) // Only show approved videos? Or all for self?
          .order('created_at', ascending: false);

      // If viewing own profile, maybe show pending too?
      // For now, let's just show approved to align with "public" profile view.

      if (mounted) {
        setState(() {
          _videos = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching creator videos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: LogoLoadingScreen());
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_camera_back, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No clips yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 9 / 16, // TikTok style vertical
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        final thumbUrl = video['thumbnail_url'] as String?;
        final views = video['view_count'] ?? 0;

        return GestureDetector(
          onTap: () {
            // TODO: Open full screen feed starting at this video
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbUrl != null)
                CachedNetworkImage(
                  imageUrl: thumbUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey[900]),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.grey[800]),
                )
              else
                Container(color: Colors.black),

              // Gradient for text visibility
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatCount(views),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
