import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../provider/trailers_feed_provider.dart';
import '../models/trailer_item.dart';
import 'trailer_detail_screen.dart';

class TrailersDiscoveryScreen extends StatefulWidget {
  const TrailersDiscoveryScreen({Key? key}) : super(key: key);

  @override
  _TrailersDiscoveryScreenState createState() =>
      _TrailersDiscoveryScreenState();
}

class _TrailersDiscoveryScreenState extends State<TrailersDiscoveryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrailersFeedProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrailersFeedProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.trending.isEmpty) {
          return const Center(
            child: LogoLoadingScreen(),
          );
        }

        if (provider.error != null && provider.trending.isEmpty) {
          return Center(
            child: Text(
              'Error: ${provider.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refresh(),
          child: ListView(
            padding: EdgeInsets.only(
              top:
                  MediaQuery.of(context).padding.top +
                  80, // Space for top tab bar
              bottom: 100, // Space for bottom nav
            ),
            children: [
              _buildHorizontalSection(
                context,
                'Trending Trailers',
                provider.trending,
                isHero: true,
              ),
              _buildHorizontalSection(context, 'Discover', provider.discover),
              _buildHorizontalSection(
                context,
                'New Movies',
                provider.newMovies,
              ),
              _buildHorizontalSection(
                context,
                'New TV Shows',
                provider.newTvShows,
              ),
              _buildHorizontalSection(context, 'Lastest', provider.lastest)
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontalSection(
    BuildContext context,
    String title,
    List<TrailerItem> items, {
    bool isHero = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: isHero ? 280 : 200,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final trailer = items[index];
              return _buildTrailerCard(context, trailer, isHero: isHero);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTrailerCard(
    BuildContext context,
    TrailerItem trailer, {
    bool isHero = false,
  }) {
    final double width = isHero ? 180 : 130;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrailerDetailScreen(trailer: trailer),
          ),
        );
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: trailer.posterUrl.isNotEmpty
                          ? trailer.posterUrl
                          : trailer.backdropUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    ),
                    // Gradient overlay to make text pop
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              trailer.title,
              style: const TextStyle(

                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
