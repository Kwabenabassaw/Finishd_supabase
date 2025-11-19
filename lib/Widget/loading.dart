import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ExploreShimmer extends StatefulWidget {
  const ExploreShimmer({super.key});

  @override
  State<ExploreShimmer> createState() => _ExploreShimmerState();
}

class _ExploreShimmerState extends State<ExploreShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15), // slight slide up
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: _opacity.value,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 400),
            offset: _slide.value,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeleton(height: 230, width: double.infinity, radius: 18),
                  const SizedBox(height: 20),

                  _titleSkeleton(),
                  const SizedBox(height: 10),

                  _horizontalList(),

                  const SizedBox(height: 20),
                  _titleSkeleton(),
                  const SizedBox(height: 10),

                  _horizontalList(),

                  const SizedBox(height: 20),
                  _titleSkeleton(),
                  const SizedBox(height: 10),

                  _horizontalList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- HELPERS BELOW ---

  Widget _titleSkeleton() {
    return _skeleton(height: 18, width: 150);
  }

  Widget _horizontalList() {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _skeleton(height: 150, width: 110, radius: 12),
            const SizedBox(height: 8),
            _skeleton(height: 16, width: 90),
            const SizedBox(height: 5),
            _skeleton(height: 14, width: 70),
          ],
        ),
      ),
    );
  }

  Widget _skeleton({
    required double height,
    required double width,
    double radius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: const Color.fromARGB(255, 231, 226, 226)!,
      highlightColor: Colors.grey[700]!,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
