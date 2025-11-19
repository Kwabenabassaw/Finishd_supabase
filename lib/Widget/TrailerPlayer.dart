import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class AnimatedTrailerCover extends StatefulWidget {
  final String poster;
  final String youtubeKey;

  const AnimatedTrailerCover({
    super.key,
    required this.poster,
    required this.youtubeKey,
  });

  @override
  State<AnimatedTrailerCover> createState() => _AnimatedTrailerCoverState();
}

class _AnimatedTrailerCoverState extends State<AnimatedTrailerCover> {
  bool showTrailer = false;
  late YoutubePlayerController _controller;
  

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.youtubeKey,
      flags: const YoutubePlayerFlags(autoPlay: true, controlsVisibleAtStart: true),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.24;

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 🔥 FADE-IN ANIMATION
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),

              // 🔥 Switch between poster and trailer
              child: showTrailer
                  ? YoutubePlayer(
                      key: const ValueKey("player"),
                      controller: _controller,
                      showVideoProgressIndicator: true,
                    )
                  : ColorFiltered(
                      key: const ValueKey("poster"),
                      colorFilter: ColorFilter.mode(
                        Colors.black87.withOpacity(0),
                        BlendMode.srcATop,
                      ),
                      child: Image.network(
                        "https://image.tmdb.org/t/p/w500${widget.poster}",
                        width: double.infinity,
                        height: height,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),

            // Play Icon (only visible if trailer is not showing)
            if (!showTrailer)
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => showTrailer = true);
                  },
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
