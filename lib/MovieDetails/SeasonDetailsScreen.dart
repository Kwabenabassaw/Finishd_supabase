import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Model/season_detail_model.dart';
import 'package:finishd/Widget/TrailerPlayer.dart';
import 'package:finishd/tmbd/fetch_trialler.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:flutter/material.dart';

class SeasonDetailsScreen extends StatefulWidget {
  final int tvId;
  final int seasonNumber;
  final String showName;
  final String? posterPath;

  const SeasonDetailsScreen({
    super.key,
    required this.tvId,
    required this.seasonNumber,
    required this.showName,
    this.posterPath,
  });

  @override
  State<SeasonDetailsScreen> createState() => _SeasonDetailsScreenState();
}

class _SeasonDetailsScreenState extends State<SeasonDetailsScreen> {
  final Trending _api = Trending();
  final TvService _tvService = TvService();
  late Future<SeasonDetail?> _seasonDetailFuture;
  late Future<String?> _trailerFuture;

  @override
  void initState() {
    super.initState();
    _seasonDetailFuture = _api.fetchSeasonDetails(
      widget.tvId,
      widget.seasonNumber,
    );
    // Fetch trailer for the specific season if possible, or fallback to show trailer
    // Note: TMDB API for season videos is tv/{tv_id}/season/{season_number}/videos
    // For now, we'll try to fetch the show trailer as a placeholder or implement specific season trailer fetching if available in TvService
    _trailerFuture = _tvService.getTVShowTrailerKey(widget.tvId.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: FutureBuilder<SeasonDetail?>(
        future: _seasonDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LogoLoadingScreen();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text('Error loading season details: ${snapshot.error}'),
            );
          }

          final season = snapshot.data!;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, season),
              SliverList(
                
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          season.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (season.airDate.isNotEmpty)
                          Text(
                            'Aired: ${season.airDate}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                        const SizedBox(height: 16),
                        if (season.overview.isNotEmpty) ...[
                          const Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            season.overview,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Text(
                          'Episodes (${season.episodes.length})',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildEpisodesList(season.episodes),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, SeasonDetail season) {
    return SliverAppBar(
      
      expandedHeight: 250.0,
      pinned: true,
      backgroundColor: Colors.white,
    centerTitle: true,
    title: Text(widget.showName),
      flexibleSpace: FlexibleSpaceBar(
        
        
        background: FutureBuilder<String?>(
          future: _trailerFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Container(
                margin: const EdgeInsets.only(top: 40.0),
                child: AnimatedTrailerCover(
                  poster: season.posterPath.isNotEmpty
                      ? season.posterPath
                      : widget.posterPath ?? '',
                  youtubeKey: snapshot.data!,
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: CachedNetworkImage(
                imageUrl: season.posterPath.isNotEmpty
                    ? 'https://image.tmdb.org/t/p/w500${season.posterPath}'
                    : widget.posterPath != null
                    ? 'https://image.tmdb.org/t/p/w500${widget.posterPath}'
                    : 'https://via.placeholder.com/500x281',
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const Center(child: Icon(Icons.error)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEpisodesList(List<Episode> episodes) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final episode = episodes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Episode Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: CachedNetworkImage(
                    imageUrl: episode.stillPath.isNotEmpty
                        ? 'https://image.tmdb.org/t/p/w300${episode.stillPath}'
                        : 'https://via.placeholder.com/300x169',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.movie, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Episode Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${episode.episodeNumber}. ${episode.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (episode.airDate.isNotEmpty)
                      Text(
                        episode.airDate,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      episode.overview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
