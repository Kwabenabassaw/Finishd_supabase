import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShowDetailsShimmer extends StatelessWidget {
  const ShowDetailsShimmer({super.key});

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
              // ───────────── Poster / Trailer Area ─────────────
              Container(
                height: MediaQuery.of(context).size.height * 0.28,
                width: double.infinity,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ───────────── Title Shimmer ─────────────
                    Container(
                      height: 25,
                      width: 200,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),

                    // ───────────── Date Row Shimmer ─────────────
                    Row(
                      children: [
                        Container(height: 15, width: 120, color: Colors.grey.shade300),
                        const SizedBox(width: 10),
                        Container(height: 15, width: 120, color: Colors.grey.shade300),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // ───────────── Streaming Providers Row ─────────────
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 5,
                        itemBuilder: (_, __) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ───────────── Genres Shimmer ─────────────
                    Container(
                      height: 15,
                      width: 250,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 20),

                    // ───────────── Score Shimmer ─────────────
                    Row(
                      children: [
                        Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                            )),
                        const SizedBox(width: 10),
                        Container(
                          height: 15,
                          width: 60,
                          color: Colors.grey.shade300,
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ───────────── Overview Paragraph ─────────────
                    Container(height: 15, width: double.infinity, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Container(height: 15, width: double.infinity, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Container(height: 15, width: MediaQuery.of(context).size.width * 0.7, color: Colors.grey.shade300),

                    const SizedBox(height: 30),

                    // ───────────── Recommended Section ─────────────
                    Container(height: 20, width: 180, color: Colors.grey.shade300),
                    const SizedBox(height: 15),

                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        itemBuilder: (_, __) => Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Column(
                            children: [
                              Container(
                                height: 60,
                                width: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 10,
                                width: 50,
                                color: Colors.grey.shade300,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ───────────── Seasons Section ─────────────
                    Container(height: 20, width: 120, color: Colors.grey.shade300),
                    const SizedBox(height: 15),

                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 5,
                        itemBuilder: (_, __) => Padding(
                          padding: const EdgeInsets.only(right: 15.0),
                          child: Column(
                            children: [
                              Container(
                                height: 180,
                                width: 140,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 12,
                                width: 80,
                                color: Colors.grey.shade300,
                              ),
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
