import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/shows.dart';
import 'package:finishd/tmbd/fetch_trialler.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Welcome movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  String? _youtubeKey;
  bool _isPlaying = false;
  late YoutubePlayerController _controller;

  @override
  void dispose() {
    if (_isPlaying) _controller.dispose();
    super.dispose();
  }

  Future<void> _playTrailer() async {
    final TvService trailerService = TvService();
    final key = await trailerService.getTvShowTrailerKey(
      widget.movie.name ?? "",
    );

    if (key != null) {
      _controller = YoutubePlayerController(
        initialVideoId: key,
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );

      setState(() {
        _youtubeKey = key;
        _isPlaying = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.movie.name ?? "Unknown Movie"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Icon(Icons.favorite_border, color: Colors.black),
          SizedBox(width: 16),
          Icon(Icons.share_outlined, color: Colors.black),
          SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // If _isPlaying is true, show YouTubePlayer
                  _isPlaying && _youtubeKey != null
                      ? YoutubePlayer(
                          controller: _controller,
                          showVideoProgressIndicator: true,
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.movie.image?.original ?? "",
                          width: double.infinity,
                          height: screenWidth * 0.55,
                          fit: BoxFit.cover,
                        ),
                  if (!_isPlaying)
                    ElevatedButton(
                      onPressed: _playTrailer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Continue your other widgets here (title, info, cast, etc.)
            Text(
              widget.movie.name.toString(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              children: [
                ...(widget.movie.genres ?? []).map((genre) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(genre),
                    )).toList(),
              ],
            ),

           
            Text(widget.movie.summary.toString() ?? "null"),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ 

            ], ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Recommended by Friends",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "None of your friends have recommended this movie yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A8927),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Invite Friends to Recommend"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
