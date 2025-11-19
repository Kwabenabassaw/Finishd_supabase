import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AnimatedTrailerCoverShimmer extends StatelessWidget {
  const AnimatedTrailerCoverShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.24;

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: height,
            width: double.infinity,
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
