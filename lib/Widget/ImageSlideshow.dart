import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class ImageSlideshow extends StatefulWidget {
  final Function(int)? changedIndex; // callback when slide changes

  const ImageSlideshow({super.key, this.changedIndex});

  @override
  State<ImageSlideshow> createState() => _ImageSlideshowState();
}

class _ImageSlideshowState extends State<ImageSlideshow> {
  final List<String> imageUrls = [
    'https://image.tmdb.org/t/p/w500/9Gtg2DzBhmYamXBS1hKAhiwbBKS.jpg',
    'https://image.tmdb.org/t/p/w500/8UlWHLMpgZm9bx6QYh0NFoq67TZ.jpg',
    'https://image.tmdb.org/t/p/w500/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg',
  ];

  int _currentPage = 0;
  final PageController _controller = PageController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Auto-slide every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_controller.hasClients) {
        _currentPage = (_currentPage + 1) % imageUrls.length;

        // Notify parent widget about page change
        if (widget.changedIndex != null) {
          widget.changedIndex!(_currentPage);
        }

        _controller.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: screenWidth * 0.55,
      child: PageView.builder(
        controller: _controller,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return CachedNetworkImage(
            imageUrl: imageUrls[index],
            width: double.infinity,
            height: screenWidth * 0.55,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) =>
                const Icon(Icons.error, color: Colors.red),
          );
        },
        // If you want to detect manual swipes too:
        onPageChanged: (index) {
          setState(() => _currentPage = index);
          if (widget.changedIndex != null) {
            widget.changedIndex!(index);
          }
        },
      ),
    );
  }
}
