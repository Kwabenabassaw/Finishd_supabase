import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// A clean YouTube video player with minimal branding and custom controls.
///
/// Usage:
/// ```dart
/// CleanYoutubePlayer(videoId: 'dQw4w9WgXcQ')
/// ```
class CleanYoutubePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final bool mute;
  final VoidCallback? onTap;

  const CleanYoutubePlayer({
    super.key,
    required this.videoId,
    this.autoPlay = true,
    this.mute = false,
    this.onTap,
  });

  @override
  State<CleanYoutubePlayer> createState() => _CleanYoutubePlayerState();
}

class _CleanYoutubePlayerState extends State<CleanYoutubePlayer> {
  late YoutubePlayerController _controller;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: widget.mute,
        hideControls: true,
        controlsVisibleAtStart: false,
        useHybridComposition: true,
        forceHD: false,
        enableCaption: false,
      ),
    )..addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final isPlaying = _controller.value.isPlaying;
    final isBuffering = _controller.value.playerState == PlayerState.buffering;

    if (isPlaying != _isPlaying || isBuffering != _isBuffering) {
      setState(() {
        _isPlaying = isPlaying;
        _isBuffering = isBuffering;
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls && _isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: false,
        bufferIndicator: const SizedBox.shrink(),
      ),
      builder: (context, player) {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              player,

              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    _toggleControlsVisibility();
                    widget.onTap?.call();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),

              if (_showControls) ...[
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.4)),
                ),
                _buildCenterButton(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildProgressBar(),
                ),
              ],

              if (_isBuffering)
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCenterButton() {
    IconData icon;
    if (_isBuffering) {
      icon = Icons.hourglass_empty;
    } else if (_isPlaying) {
      icon = Icons.pause_rounded;
    } else {
      icon = Icons.play_arrow_rounded;
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ValueListenableBuilder<YoutubePlayerValue>(
            valueListenable: _controller,
            builder: (_, value, __) {
              return Text(
                _formatDuration(value.position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ValueListenableBuilder<YoutubePlayerValue>(
              valueListenable: _controller,
              builder: (_, value, __) {
                final position = value.position.inMilliseconds.toDouble();
                final duration = value.metaData.duration.inMilliseconds
                    .toDouble();
                final progress = duration > 0
                    ? (position / duration).clamp(0.0, 1.0)
                    : 0.0;

                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: Colors.red,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.red,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (newValue) {
                      final newPosition = Duration(
                        milliseconds: (newValue * duration).toInt(),
                      );
                      _controller.seekTo(newPosition);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<YoutubePlayerValue>(
            valueListenable: _controller,
            builder: (_, value, __) {
              return Text(
                _formatDuration(value.metaData.duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
