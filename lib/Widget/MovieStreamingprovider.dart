import 'package:finishd/LoadingWidget/StreamingLoading.dart';
import 'package:finishd/services/deep_link_service.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:flutter/material.dart';

Trending trending = Trending();

class Moviestreamingprovider extends StatefulWidget {
  final int showId;
  final String title;
  const Moviestreamingprovider({
    super.key,
    required this.showId,
    required this.title,
  });

  @override
  State<Moviestreamingprovider> createState() => _StreamingproviderState();
}

class _StreamingproviderState extends State<Moviestreamingprovider> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: FutureBuilder(
        future: trending.fetchStreamingDetailsMovie(widget.showId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingService();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (snapshot.hasData) {
            final watchProvidersResponse = snapshot.data!;
            if (watchProvidersResponse.results.containsKey('US')) {
              final usInfo = watchProvidersResponse.results['US']!;
              if (usInfo.flatrate.isEmpty) {
                return const Text('No flatrate providers available.');
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: usInfo.flatrate.map((provider) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: GestureDetector(
                        onTap: () {
                          DeepLinkService.openStreamingProvider(
                            provider,
                            widget.title,
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8.0),

                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Image.network(
                                  "https://image.tmdb.org/t/p/w500${provider.logoPath}",
                                  fit: BoxFit.cover,
                                  height: 50,
                                  width: 50,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            } else {
              return const Text('No watch provider information for US.');
            }
          } else {
            return const Text('No data available.');
          }
        },
      ),
    );
  }
}
