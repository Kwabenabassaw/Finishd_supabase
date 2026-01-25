import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Model/season_detail_model.dart';
import 'package:finishd/Model/tmdb_extras.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EpisodeDetailsScreen extends StatefulWidget {
  final int tvId;
  final int seasonNumber;
  final int episodeNumber;
  final String showName;

  const EpisodeDetailsScreen({
    super.key,
    required this.tvId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.showName,
  });

  @override
  State<EpisodeDetailsScreen> createState() => _EpisodeDetailsScreenState();
}

class _EpisodeDetailsScreenState extends State<EpisodeDetailsScreen> {
  final Trending _api = Trending();
  late Future<Episode?> _episodeFuture;
  late int _currentEpisodeNumber;

  @override
  void initState() {
    super.initState();
    _currentEpisodeNumber = widget.episodeNumber;
    _loadEpisode();
  }

  void _loadEpisode() {
    _episodeFuture = _api.fetchEpisodeDetails(
      widget.tvId,
      widget.seasonNumber,
      _currentEpisodeNumber,
    );
  }

  void _navigateToEpisode(int newEpisodeNumber) {
    setState(() {
      _currentEpisodeNumber = newEpisodeNumber;
      _loadEpisode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeBackground = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: themeBackground,
      body: FutureBuilder<Episode?>(
        future: _episodeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LogoLoadingScreen();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorState(snapshot.error?.toString());
          }

          final episode = snapshot.data!;

          return CustomScrollView(
            physics: Platform.isIOS
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, episode),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEpisodeHeader(context, episode),
                      const SizedBox(height: 24),
                      _buildOverview(context, episode),
                      const SizedBox(height: 32),
                      if (episode.guestStars.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Guest Stars'),
                        const SizedBox(height: 16),
                        _buildGuestStarsList(context, episode.guestStars),
                        const SizedBox(height: 32),
                      ],
                      if (episode.crew.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Key Crew'),
                        const SizedBox(height: 16),
                        _buildCrewList(context, episode.crew),
                        const SizedBox(height: 32),
                      ],
                      _buildEpisodeNavigation(context, episode),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Episode episode) {
    final themeBackground = Theme.of(context).scaffoldBackgroundColor;

    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      stretch: true,
      backgroundColor: themeBackground,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Platform.isIOS ? Icons.arrow_back_ios_new : Icons.arrow_back,
            color: Colors.white,
            size: 20,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: episode.stillPath.isNotEmpty
                  ? 'https://image.tmdb.org/t/p/original${episode.stillPath}'
                  : 'https://via.placeholder.com/1000x562',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.black26),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.movie, color: Colors.white, size: 50),
              ),
            ),
            // Gradient Overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                    themeBackground,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeHeader(BuildContext context, Episode episode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'S${episode.seasonNumber} • E${episode.episodeNumber}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          episode.name.isNotEmpty
              ? episode.name
              : 'Episode ${episode.episodeNumber}',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (episode.airDate.isNotEmpty)
              _buildInfoBadge(
                context,
                Icons.calendar_today_rounded,
                episode.airDate,
                isDark,
              ),
            const SizedBox(width: 16),
            if (episode.runtime > 0)
              _buildInfoBadge(
                context,
                Icons.timer_outlined,
                '${episode.runtime} min',
                isDark,
              ),
            const SizedBox(width: 16),
            if (episode.voteAverage > 0)
              _buildInfoBadge(
                context,
                Icons.star_rounded,
                episode.voteAverage.toStringAsFixed(1),
                isDark,
                iconColor: Colors.amber,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoBadge(
    BuildContext context,
    IconData icon,
    String text,
    bool isDark, {
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor ?? Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(BuildContext context, Episode episode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Overview'),
        const SizedBox(height: 12),
        Text(
          episode.overview.isNotEmpty
              ? episode.overview
              : 'No overview available for this episode.',
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }

  Widget _buildGuestStarsList(BuildContext context, List<Cast> guestStars) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: guestStars.length,
        itemBuilder: (context, index) {
          final actor = guestStars[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _GuestStarAvatar(
              name: actor.name,
              character: actor.character,
              profilePath: actor.profilePath ?? '',
            ),
          );
        },
      ),
    );
  }

  Widget _buildCrewList(BuildContext context, List<Crew> crew) {
    // Filter key crew (Director, Writer)
    final keyCrew = crew
        .where(
          (c) =>
              c.job == 'Director' ||
              c.job == 'Writer' ||
              c.job == 'Teleplay' ||
              c.job == 'Screenplay',
        )
        .toList();

    if (keyCrew.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: keyCrew.map((c) => _buildCrewItem(context, c)).toList(),
    );
  }

  Widget _buildCrewItem(BuildContext context, Crew crew) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            crew.job,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            crew.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeNavigation(BuildContext context, Episode episode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentEpisodeNumber > 1)
          _buildNavButton(
            context,
            'Previous',
            Icons.arrow_back_rounded,
            () => _navigateToEpisode(_currentEpisodeNumber - 1),
            isDark,
          )
        else
          const SizedBox.shrink(),
        _buildNavButton(
          context,
          'Next',
          Icons.arrow_forward_rounded,
          () => _navigateToEpisode(_currentEpisodeNumber + 1),
          isDark,
          isForward: true,
        ),
      ],
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
    bool isDark, {
    bool isForward = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            if (!isForward) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isForward) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to load episode details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(error ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _loadEpisode()),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestStarAvatar extends StatelessWidget {
  final String name;
  final String character;
  final String profilePath;

  const _GuestStarAvatar({
    required this.name,
    required this.character,
    required this.profilePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: profilePath.isNotEmpty
              ? NetworkImage('https://image.tmdb.org/t/p/w185$profilePath')
              : null,
          child: profilePath.isEmpty
              ? const Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          character,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
