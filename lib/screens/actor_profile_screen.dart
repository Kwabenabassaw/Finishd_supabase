import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/actor_model.dart';
import 'package:finishd/provider/actor_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class ActorProfileScreen extends StatefulWidget {
  final int personId;
  final String personName;

  const ActorProfileScreen({
    super.key,
    required this.personId,
    required this.personName,
  });

  @override
  State<ActorProfileScreen> createState() => _ActorProfileScreenState();
}

class _ActorProfileScreenState extends State<ActorProfileScreen> {
  bool _isBioExpanded = false;
  int _selectedFilmographyIndex = 0; // 0 = Movies, 1 = TV Shows

  @override
  void initState() {
    super.initState();
    // Fetch data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActorProvider>().fetchActorDetails(widget.personId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<ActorProvider>(
        builder: (context, provider, child) {
          if (provider.state == ActorState.loading) {
            return _buildLoadingState(theme.scaffoldBackgroundColor);
          } else if (provider.state == ActorState.error) {
            return _buildErrorState(provider.errorMessage);
          } else if (provider.actor != null) {
            return _buildContent(context, provider.actor!);
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ActorModel actor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryGreen = const Color(0xFF4ADE80);

    // Determine which list to show based on selection
    final filmographyList = _selectedFilmographyIndex == 0
        ? actor.movies
        : actor.tvShows;

    return CustomScrollView(
      physics: Platform.isIOS
          ? const BouncingScrollPhysics()
          : const ClampingScrollPhysics(),
      slivers: [
        // 1. Parallax Header
        SliverAppBar(
          expandedHeight: 400.0,
          pinned: true,
          stretch: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          leading: IconButton(
            icon: Icon(
              Platform.isIOS ? CupertinoIcons.back : Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Platform.isIOS ? CupertinoIcons.share : Icons.share,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () {
                if (Platform.isIOS) HapticFeedback.lightImpact();
              },
            ),
            if (actor.externalIds['imdb_id'] != null)
              IconButton(
                icon: FaIcon(
                  FontAwesomeIcons.imdb,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  _launchUrl(
                    'https://www.imdb.com/name/${actor.externalIds['imdb_id']}',
                  );
                },
              ),
            IconButton(
              icon: Icon(
                Platform.isIOS
                    ? CupertinoIcons.ellipsis_circle
                    : Icons.more_vert,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () {
                if (Platform.isIOS) HapticFeedback.lightImpact();
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [
              StretchMode.zoomBackground,
              StretchMode.blurBackground,
            ],
            background: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'actor_${actor.id}',
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://image.tmdb.org/t/p/w780${actor.profilePath}',
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: theme.cardColor),
                    errorWidget: (context, url, error) => Container(
                      color: theme.cardColor,
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: theme.iconTheme.color?.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
                // Gradient Overlay
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        theme.scaffoldBackgroundColor.withOpacity(0.2),
                        theme.scaffoldBackgroundColor.withOpacity(0.8),
                        theme.scaffoldBackgroundColor,
                      ],
                      stops: const [0.0, 0.4, 0.8, 1.0],
                    ),
                  ),
                ),
                // Name & Info overlay
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actor.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: Platform.isIOS ? 'Inter' : 'Roboto',
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: theme.textTheme.titleLarge?.color,
                          letterSpacing: 1.2,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            actor.knownForDepartment,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (actor.birthday.isNotEmpty) ...[
                            Text(
                              '  •  ',
                              style: TextStyle(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Born ${actor.birthday.split('-').first}',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Biography
                Text(
                  'Biography',
                  style: TextStyle(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isBioExpanded = !_isBioExpanded;
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actor.biography.isEmpty
                            ? 'No biography available.'
                            : actor.biography,
                        maxLines: _isBioExpanded ? null : 4,
                        overflow: _isBioExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.8,
                          ),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      if (actor.biography.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            _isBioExpanded ? 'Read Less' : 'Read More',
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Known For
                if (actor.knownFor.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Known For'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: actor.knownFor.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 20),
                      itemBuilder: (context, index) {
                        final credit = actor.knownFor[index];
                        return SizedBox(
                          width: 80,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: credit.posterPath.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        'https://image.tmdb.org/t/p/w500${credit.posterPath}',
                                      )
                                    : null,
                                backgroundColor: theme.cardColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                credit.title,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                // Filmography
                _buildSectionHeader(context, 'Filmography'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildFilterChip('Movies', 0),
                    const SizedBox(width: 10),
                    _buildFilterChip('TV Shows', 1),
                  ],
                ),
                const SizedBox(height: 16),

                // Filmography List
                if (filmographyList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      "No credits found.",
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                  )
                else
                  SizedBox(
                    height: 240,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filmographyList.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final item = filmographyList[index];
                        return Container(
                          width: 140,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.05),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (item.posterPath.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl:
                                      'https://image.tmdb.org/t/p/w500${item.posterPath}',
                                  fit: BoxFit.cover,
                                ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 8,
                                right: 8,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (item.releaseDate.isNotEmpty)
                                      Text(
                                        item.releaseDate.split('-').first,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (item.voteAverage > 0)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF064E3B,
                                      ).withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFF10B981),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          size: 10,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.voteAverage.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 30),

                // Awards Card
                _buildSectionHeader(context, 'Awards & Nominations'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.trophy,
                            color: primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Awards & Nominations',
                            style: TextStyle(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(
                        color: theme.dividerColor.withOpacity(0.1),
                        height: 1,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAwardStat(context, '1', 'OSCAR NOMINATIONS'),
                          _buildAwardStat(context, '3', 'BAFTA NOMINATIONS'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAwardStat(context, '2', 'GOLDEN GLOBES'),
                          _buildAwardStat(context, '35', 'WINS TOTAL'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(Color bg) {
    return Center(
      child: CircularProgressIndicator(color: const Color(0xFF4ADE80)),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Text(error, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        color: theme.textTheme.titleLarge?.color,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedFilmographyIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilmographyIndex = index;
        });
        if (Platform.isIOS) HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.dividerColor.withOpacity(0.2)
                : theme.dividerColor.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.textTheme.bodyLarge?.color
                : theme.textTheme.bodySmall?.color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAwardStat(BuildContext context, String count, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: TextStyle(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
