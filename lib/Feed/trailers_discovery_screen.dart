import 'dart:async';
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
  late ScrollController _heroScrollController;
  late ScrollController _mainScrollController;
  Timer? _autoScrollTimer;
  int _currentHeroIndex = 0;
  double _scrollAccumulator = 0;
  int _currentSectionIndex = 0;

  @override
  void initState() {
    super.initState();
    _heroScrollController = ScrollController();
    _mainScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrailersFeedProvider>().initialize();
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_heroScrollController.hasClients && _heroScrollController.positions.isNotEmpty) {
        final provider = context.read<TrailersFeedProvider>();
        if (provider.trending.isNotEmpty) {
           _currentHeroIndex = (_currentHeroIndex + 1) % provider.trending.length;
           _heroScrollController.animateTo(
             _currentHeroIndex * 192.0, // 180 (card width) + 12 (total horizontal margin)
             duration: const Duration(milliseconds: 800),
             curve: Curves.easeInOutCubic,
           );
        }
      }
    });
  }

  void _onHeroInteraction() {
     _autoScrollTimer?.cancel();
     // Resume after 3 seconds of no interaction
     Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _startAutoScroll();
     });
  }

  void _scrollToNextSection(bool downwards) {
    final provider = context.read<TrailersFeedProvider>();
    final totalSections = 1 + provider.genreSections.length + 4; // Hero + Genres + 4 static
    
    if (downwards) {
      if (_currentSectionIndex < totalSections - 1) {
        _currentSectionIndex++;
      }
    } else {
      if (_currentSectionIndex > 0) {
        _currentSectionIndex--;
      }
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top + 80;
    
    // Approximate offsets
    double targetOffset = topPadding;
    if (_currentSectionIndex > 0) {
      targetOffset += 341.0; // Hero height
      targetOffset += (_currentSectionIndex - 1) * 261.0; // Other sections height
    }

    _mainScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _heroScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
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
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification && notification.dragDetails != null) {
                final delta = notification.scrollDelta ?? 0;
                _scrollAccumulator += delta;
                
                final triggerThreshold = MediaQuery.of(context).size.height * 0.2;
                if (_scrollAccumulator.abs() > triggerThreshold) {
                  _scrollToNextSection(delta > 0);
                  _scrollAccumulator = 0;
                }
              }
              if (notification is ScrollEndNotification) {
                _scrollAccumulator = 0;
              }
              return false;
            },
            child: ListView(
              controller: _mainScrollController,
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

              // Personalized Genre Sections
              ...provider.genreSections.entries.map((entry) => 
                _buildHorizontalSection(
                  context, 
                  'Top ${entry.key} Trailers', 
                  entry.value
                )
              ).toList(),

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
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: isHero ? 280 : 200,
          child: Listener(
            onPointerDown: (_) => isHero ? _onHeroInteraction() : null,
            child: ListView.builder(
              controller: isHero ? _heroScrollController : null,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final trailer = items[index];
                return _buildTrailerCard(context, trailer, isHero: isHero);
              },
            ),
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
