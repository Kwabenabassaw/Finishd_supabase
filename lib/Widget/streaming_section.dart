import 'package:finishd/Model/Watchprovider.dart';
import 'package:finishd/Model/streaming_availability.dart';
import 'package:finishd/Widget/streaming_badge.dart';
import 'package:flutter/material.dart';

class StreamingSection extends StatelessWidget {
  final WatchProvidersResponse? watchProviders;
  final StreamingAvailability? availability;
  final String title;
  final String tmdbId;

  const StreamingSection({
    super.key,
    this.watchProviders,
    this.availability,
    required this.title,
    required this.tmdbId,
  });

  @override
  Widget build(BuildContext context) {
    // If availability is null, we can't show anything based on the new API
    if (availability == null) {
      return const SizedBox.shrink();
    }

    final region = 'US'; // TODO: Support user region
    final countryAvail = availability!.countries[region];

    if (countryAvail == null || countryAvail.services.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayServices = countryAvail.services.values.toList();

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
            itemCount: displayServices.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final service = displayServices[index];
              return StreamingBadge(
                service: service,
                title: title,
                tmdbId: tmdbId,
              );
            },
          ),
        ),
      ],
    );
  }
}
