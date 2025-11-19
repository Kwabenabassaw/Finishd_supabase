import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';


class LoadingService extends StatefulWidget {
  const LoadingService({super.key});

  @override
  State<LoadingService> createState() => _LoadingServiceState();
}

class _LoadingServiceState extends State<LoadingService> {
  @override
  Widget build(BuildContext context) {
    return _buildShimmerStreaming();
  }
}
Widget _buildShimmerStreaming() {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(6, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: Column(
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  height: 10,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    ),
  );
}
