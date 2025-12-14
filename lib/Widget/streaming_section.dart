import 'package:finishd/Model/Watchprovider.dart';
import 'package:finishd/Widget/streaming_badge.dart';
import 'package:flutter/material.dart';

class StreamingSection extends StatelessWidget {
  final WatchProvidersResponse? watchProviders;
  final String title;
  final String tmdbId;

  const StreamingSection({
    super.key,
    required this.watchProviders,
    required this.title,
    required this.tmdbId,
  });

  @override
  Widget build(BuildContext context) {
    if (watchProviders == null) {
      return const SizedBox.shrink();
    }

    // Default to US or try to find a region with data
    // Ideally we should use the user's region
    final region = 'US';
    final info = watchProviders!.results[region];

    if (info == null || (info.flatrate.isEmpty && info.ads.isEmpty)) {
      // Fallback: Check if there's *any* info (e.g. GH) or just return empty
      // Simplification: just return empty if US missing.
      return const SizedBox.shrink();
    }

    // Combine flatrate and ads
    final providers = [...info.flatrate, ...info.ads];
    // unique by ID
    final uniqueProviders = <int, WatchProvider>{};
    for (var p in providers) {
      uniqueProviders[p.providerId] = p;
    }
    final displayProviders = uniqueProviders.values.toList();

    if (displayProviders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Stream On",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayProviders.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return StreamingBadge(
                provider: displayProviders[index],
                title: title,
                tmdbId: tmdbId,
                webUrl: info.link,
              );
            },
          ),
        ),
      ],
    );
  }
}
