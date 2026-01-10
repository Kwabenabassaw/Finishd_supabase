import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YouTubeTrailerPlayerDialog extends StatefulWidget {
  final String youtubeKey;

  const YouTubeTrailerPlayerDialog({super.key, required this.youtubeKey});

  @override
  State<YouTubeTrailerPlayerDialog> createState() =>
      _YouTubeTrailerPlayerDialogState();

  static void show(BuildContext context, String youtubeKey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            YouTubeTrailerPlayerDialog(youtubeKey: youtubeKey),
      ),
    );
  }
}

class _YouTubeTrailerPlayerDialogState
    extends State<YouTubeTrailerPlayerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.youtubeKey,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        enableCaption: true,
        playsInline: false,
        origin: 'https://www.youtube-nocookie.com',
      ),
    );

    // Force landscape for fullscreen experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _controller.close();
    // Restore portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: YoutubePlayer(
                controller: _controller,
                aspectRatio: 16 / 9,
              ),
            ),
            // Close button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
