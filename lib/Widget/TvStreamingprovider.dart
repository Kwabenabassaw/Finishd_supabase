import 'package:finishd/services/streaming_availability_service.dart';
import 'package:finishd/Model/streaming_availability.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Widget/streaming_badge.dart';
import 'package:finishd/LoadingWidget/StreamingLoading.dart';

class Streamingprovider extends StatefulWidget {
  final String showId;
  final String title;

  const Streamingprovider({
    super.key,
    required this.showId,
    required this.title,
  });

  @override
  State<Streamingprovider> createState() => _StreamingproviderState();
}

class _StreamingproviderState extends State<Streamingprovider> {
  late Future<StreamingAvailability?> _availabilityFuture;
  final StreamingAvailabilityService _availabilityService =
      StreamingAvailabilityService();

  @override
  void initState() {
    super.initState();
    _availabilityFuture = _availabilityService.fetchAvailability(
      widget.showId,
      'tv',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: FutureBuilder<StreamingAvailability?>(
        future: _availabilityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingService();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (snapshot.hasData && snapshot.data != null) {
            final availability = snapshot.data!;
            final region = 'US';
            final countryAvail = availability.countries[region];

            if (countryAvail == null || countryAvail.services.isEmpty) {
              return const Text('No streaming providers available.');
            }

            final displayServices = countryAvail.services.values.toList();

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: displayServices.map((service) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: StreamingBadge(
                      service: service,
                      title: widget.title,
                      tmdbId: widget.showId,
                    ),
                  );
                }).toList(),
              ),
            );
          } else {
            return const Text('No data available.');
          }
        },
      ),
    );
  }
}
