import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShowDetailsShimmer extends StatelessWidget {
  const ShowDetailsShimmer({super.key});

  // A helper function to create a placeholder box with rounded corners
  Widget _buildPlaceholderBox({
    required double height,
    required double width,
    required BuildContext context,
    double radius = 8.0,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white, // Color set here is the base color for shimmer
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
        shape: shape,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───────────── 1. Poster / Trailer Area (Rounded) ─────────────
              Container(
                height: MediaQuery.of(context).size.height * 0.28,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 15),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ───────────── 2. Title Shimmer (Rounded) ─────────────
                    _buildPlaceholderBox(height: 25, width: 250, context: context),
                    const SizedBox(height: 10),

                    // ───────────── 3. Date Row Shimmer (Rounded) ─────────────
                    Row(
                      children: [
                        _buildPlaceholderBox(height: 15, width: 100, context: context),
                        const SizedBox(width: 20),
                        _buildPlaceholderBox(height: 15, width: 150, context: context),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // ───────────── 4. Action Button Bar (Full width, rounded) ─────────────
                    _buildPlaceholderBox(
                        height: 48, width: double.infinity, context: context, radius: 24.0),
                    const SizedBox(height: 25),

                    // ───────────── 5. Score Shimmer (Circle and text) ─────────────
                    Row(
                      children: [
                        _buildPlaceholderBox(height: 50, width: 50, context: context, shape: BoxShape.circle),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPlaceholderBox(height: 15, width: 60, context: context),
                            const SizedBox(height: 5),
                            _buildPlaceholderBox(height: 10, width: 40, context: context),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ───────────── 6. Overview Paragraph (Rounded lines) ─────────────
                    _buildPlaceholderBox(height: 15, width: double.infinity, context: context),
                    const SizedBox(height: 8),
                    _buildPlaceholderBox(height: 15, width: double.infinity, context: context),
                    const SizedBox(height: 8),
                    _buildPlaceholderBox(
                        height: 15, width: MediaQuery.of(context).size.width * 0.7, context: context),
                    const SizedBox(height: 30),

                    // ───────────── 7. Recommended Section Title (Rounded) ─────────────
                    _buildPlaceholderBox(height: 20, width: 180, context: context),
                    const SizedBox(height: 15),

                    // ───────────── 8. Recommended Item List (Posters & text) ─────────────
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        itemBuilder: (_, __) => Padding(
                          padding: const EdgeInsets.only(right: 15.0),
                          child: Column(
                            children: [
                              _buildPlaceholderBox(height: 150, width: 100, context: context, radius: 10),
                              const SizedBox(height: 8),
                              _buildPlaceholderBox(height: 10, width: 80, context: context),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ───────────── 9. Cast Section Title (Rounded) ─────────────
                    _buildPlaceholderBox(height: 20, width: 120, context: context),
                    const SizedBox(height: 15),

                    // ───────────── 10. Cast List (Circles & text) ─────────────
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 5,
                        itemBuilder: (_, __) => Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Column(
                            children: [
                              _buildPlaceholderBox(height: 60, width: 60, context: context, shape: BoxShape.circle),
                              const SizedBox(height: 8),
                              _buildPlaceholderBox(height: 10, width: 50, context: context),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}