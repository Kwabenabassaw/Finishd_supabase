import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/trailer_item.dart';

class TrailerDetailScreen extends StatefulWidget {
  final TrailerItem trailer;

  const TrailerDetailScreen({Key? key, required this.trailer})
    : super(key: key);

  @override
  _TrailerDetailScreenState createState() => _TrailerDetailScreenState();
}

class _TrailerDetailScreenState extends State<TrailerDetailScreen> {
  YoutubePlayerController? _controller;
  bool _isLiked = false;
  bool _isDisliked = false;

  @override
  void initState() {
    super.initState();
    if (widget.trailer.youtubeKey.isNotEmpty) {
      _controller = YoutubePlayerController(
        initialVideoId: widget.trailer.youtubeKey,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.trailer.title),
      ),
      body: Column(
        children: [
          // Youtube Player 16:9
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _controller != null
                ? YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: Colors.red,
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Text(
                        'Trailer not available',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
          ),

          // Action Row + Details + Comments
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: _isLiked
                          ? Icons.thumb_up
                          : Icons.thumb_up_alt_outlined,
                      label: 'Like',
                      color: _isLiked ? Colors.blue : Colors.white,
                      onTap: () {
                        setState(() {
                          _isLiked = !_isLiked;
                          if (_isLiked) _isDisliked = false;
                        });
                      },
                    ),
                    _buildActionButton(
                      icon: _isDisliked
                          ? Icons.thumb_down
                          : Icons.thumb_down_alt_outlined,
                      label: 'Dislike',
                      color: _isDisliked ? Colors.red : Colors.white,
                      onTap: () {
                        setState(() {
                          _isDisliked = !_isDisliked;
                          if (_isDisliked) _isLiked = false;
                        });
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'Comment',
                      onTap: () {
                        // Focus comment field
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.share,
                      label: 'Share',
                      onTap: () {
                        // Share intent
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 32),

                // Description
                Text(
                  widget.trailer.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // Mock Comments Section
                const Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMockComment('Awesome trailer!', 'user123'),
                _buildMockComment(
                  'Can\'t wait for this to come out.',
                  'moviebuff',
                ),
                _buildMockComment('Looks amazing 🔥', 'john_doe'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMockComment(String text, String user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.person, size: 20, color: Colors.white54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
