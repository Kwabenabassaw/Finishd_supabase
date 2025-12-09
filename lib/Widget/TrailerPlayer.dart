import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
// No need for dart:async now that we removed the Timer

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
  // Set initial state to false: always show the poster first.
  bool showTrailer = false; 
  late YoutubePlayerController _controller;
  

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.youtubeKey,

      flags: const YoutubePlayerFlags(
        // CHANGED: Set autoPlay to false, so the user must initiate playback.
        autoPlay: false, 
        controlsVisibleAtStart: true,
        disableDragSeek: true,
        
      ),
    );
  }

  @override
  void dispose() {
    // The controller is disposed when the widget is removed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the screen width for responsive height calculation
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
                      // Ensure it starts playing when rendered
                      onReady: () => _controller.play(),
                    )
                  : ColorFiltered(
                      key: const ValueKey("poster"),
                      colorFilter: ColorFilter.mode(
                        Colors.black87.withOpacity(0.1),
                        BlendMode.srcATop,
                      ),
                      child: Image.network(
                        "https://image.tmdb.org/t/p/w500${widget.poster}",
                        width: double.infinity,
                        height: height,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(Icons.movie, color: Colors.white54, size: 50),
                          ),
                        ),
                      ),
                    ),
            ),

            // Play Icon (only visible when trailer is NOT showing)
            if (!showTrailer)
              Center(
                child: GestureDetector(
                  // When tapped, switch to the player and start playback
                  onTap: () {
                    setState(() {
                      showTrailer = true;
                    });
                    // The video will now play automatically because of onReady: _controller.play()
                    // or it will start immediately because the player is being built.
                  },
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 90,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}