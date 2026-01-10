import 'dart:async';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/tmbd/fetchDiscover.dart';
import 'package:finishd/Discover/widgets/netflix_hero.dart';
import 'package:finishd/Discover/widgets/ranking_section.dart';
import 'package:finishd/Widget/movie_section.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/services/social_discovery_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderContentScreen extends StatefulWidget {
  final int providerId;
  final String providerName;

  const ProviderContentScreen({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<ProviderContentScreen> createState() => _ProviderContentScreenState();
}

enum _ProviderTab { home, tvShows, movies }

class _ProviderContentScreenState extends State<ProviderContentScreen> {
  final Fetchdiscover _fetchDiscover = Fetchdiscover();
  final Trending _trendingApi = Trending();
  final SocialDiscoveryService _socialService = SocialDiscoveryService();

  _ProviderTab _selectedTab = _ProviderTab.home;

  // Hero rotation
  Timer? _heroRotationTimer;
  int _currentHeroIndex = 0;

  MediaItem? _heroItem;
  List<MediaItem> _top10 = [];
  List<MediaItem> _newArrivals = [];
  List<MediaItem> _trending = [];
  List<MediaItem> _awardWinning = [];
  List<MediaItem> _highSchool = [];
  List<MediaItem> _sciFi = [];
  List<MediaItem> _drama = [];
  List<MediaItem> _comedy = [];
  List<MediaItem> _action = [];
  List<MediaItem> _horror = [];
  List<MediaItem> _romance = [];
  List<MediaItem> _friendsWatching = [];

  bool _isLoading = true;
  String? _error;

  // TMDB Genre IDs
  static const int _genreSciFi = 878;
  static const int _genreDrama = 18;
  static const int _genreComedy = 35;
  static const int _genreAction = 28;
  static const int _genreHorror = 27;
  static const int _genreRomance = 10749;

  @override
  void initState() {
    super.initState();
    _trendingApi.loadGenres(); // Load genres for MovieSection displays
    _loadAllContent();
    _startHeroRotation();
  }

  @override
  void dispose() {
    _heroRotationTimer?.cancel();
    super.dispose();
  }

  void _startHeroRotation() {
    _heroRotationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        debugPrint(
          'Hero rotation: index $_currentHeroIndex -> ${_currentHeroIndex + 1}',
        );
        setState(() {
          _currentHeroIndex++;
        });
      }
    });
  }

  MediaItem? _getCurrentHeroItem() {
    List<MediaItem> heroPool;

    switch (_selectedTab) {
      case _ProviderTab.home:
        heroPool = _top10.isNotEmpty ? _top10 : _newArrivals;
        break;
      case _ProviderTab.tvShows:
        final filtered = _top10.where((i) => i.mediaType == 'tv').toList();
        heroPool = filtered.isNotEmpty
            ? filtered
            : _newArrivals.where((i) => i.mediaType == 'tv').toList();
        break;
      case _ProviderTab.movies:
        final filtered = _top10.where((i) => i.mediaType == 'movie').toList();
        heroPool = filtered.isNotEmpty
            ? filtered
            : _newArrivals.where((i) => i.mediaType == 'movie').toList();
        break;
    }

    if (heroPool.isEmpty) return null;

    // Cycle through the hero pool (max 5 items for variety)
    final limitedPool = heroPool.take(5).toList();
    final index = _currentHeroIndex % limitedPool.length;
    final item = limitedPool[index];
    debugPrint(
      'Hero rotation: Showing item ${index + 1}/${limitedPool.length}: "${item.title}"',
    );
    return item;
  }

  Future<void> _loadAllContent() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        _fetchDiscover.fetchHeroContent(widget.providerId),
        _fetchDiscover.fetchTop10(widget.providerId),
        _fetchDiscover.fetchNewArrivals(widget.providerId),
        _fetchDiscover.fetchTrending(widget.providerId),
        _fetchDiscover.fetchAwardWinning(widget.providerId),
        _fetchDiscover.fetchHighSchool(widget.providerId),
        _fetchDiscover.fetchByGenre(widget.providerId, _genreSciFi),
        _fetchDiscover.fetchByGenre(widget.providerId, _genreDrama),
        _fetchDiscover.fetchByGenre(widget.providerId, _genreComedy),
        _fetchDiscover.fetchByGenre(widget.providerId, _genreAction),
        _fetchDiscover.fetchByGenre(widget.providerId, _genreHorror),
        _fetchDiscover.fetchByGenre(widget.providerId, _genreRomance),
        _fetchSocialContent(),
      ]);

      if (mounted) {
        setState(() {
          _heroItem = results[0] as MediaItem?;
          _top10 = results[1] as List<MediaItem>;
          _newArrivals = results[2] as List<MediaItem>;
          _trending = results[3] as List<MediaItem>;
          _awardWinning = results[4] as List<MediaItem>;
          _highSchool = results[5] as List<MediaItem>;
          _sciFi = results[6] as List<MediaItem>;
          _drama = results[7] as List<MediaItem>;
          _comedy = results[8] as List<MediaItem>;
          _action = results[9] as List<MediaItem>;
          _horror = results[10] as List<MediaItem>;
          _romance = results[11] as List<MediaItem>;
          _friendsWatching = results[12] as List<MediaItem>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<List<MediaItem>> _fetchSocialContent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      await _socialService.fetchSocialSignals(user.uid);
      return [];
    } catch (e) {
      return [];
    }
  }

  List<MediaItem> _filterContent(List<MediaItem> items) {
    if (_selectedTab == _ProviderTab.home) return items;
    if (_selectedTab == _ProviderTab.movies) {
      return items.where((i) => i.mediaType == 'movie').toList();
    }
    if (_selectedTab == _ProviderTab.tvShows) {
      return items.where((i) => i.mediaType == 'tv').toList();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final filteredTop10 = _filterContent(_top10);
    final filteredNewArrivals = _filterContent(_newArrivals);
    final filteredTrending = _filterContent(_trending);
    final filteredAwardWinning = _filterContent(_awardWinning);
    final filteredHighSchool = _filterContent(_highSchool);
    final filteredSciFi = _filterContent(_sciFi);
    final filteredDrama = _filterContent(_drama);
    final filteredComedy = _filterContent(_comedy);
    final filteredAction = _filterContent(_action);
    final filteredHorror = _filterContent(_horror);
    final filteredRomance = _filterContent(_romance);

    final currentHero = _getCurrentHeroItem();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: LogoLoadingScreen())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Error loading content: $_error',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadAllContent,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: colorScheme.primary,
              onRefresh: _loadAllContent,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(theme, colorScheme),
                  if (currentHero != null)
                    SliverToBoxAdapter(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: NetflixHero(
                          key: ValueKey(currentHero.id),
                          item: currentHero,
                        ),
                      ),
                    ),
                  _buildCategoryTabs(theme, colorScheme, isDark),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Top 10
                        if (filteredTop10.isNotEmpty) ...[
                          RankingSection(
                            title: 'Top 10 Today',
                            items: filteredTop10,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Trending
                        if (filteredTrending.isNotEmpty) ...[
                          MovieSection(
                            title: '🔥 Trending Now',
                            items: filteredTrending,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // New Arrivals
                        if (filteredNewArrivals.isNotEmpty) ...[
                          MovieSection(
                            title: 'New Arrivals',
                            items: filteredNewArrivals,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Award Winning
                        if (filteredAwardWinning.isNotEmpty) ...[
                          MovieSection(
                            title: '🏆 Award Winning',
                            items: filteredAwardWinning,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // High School
                        if (filteredHighSchool.isNotEmpty) ...[
                          MovieSection(
                            title: '🎒 High School',
                            items: filteredHighSchool,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Genre: Sci-Fi
                        if (filteredSciFi.isNotEmpty) ...[
                          MovieSection(
                            title: '🚀 Sci-Fi',
                            items: filteredSciFi,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Genre: Action
                        if (filteredAction.isNotEmpty) ...[
                          MovieSection(
                            title: '💥 Action',
                            items: filteredAction,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Genre: Drama
                        if (filteredDrama.isNotEmpty) ...[
                          MovieSection(
                            title: '🎭 Drama',
                            items: filteredDrama,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Genre: Comedy
                        if (filteredComedy.isNotEmpty) ...[
                          MovieSection(
                            title: '😂 Comedy',
                            items: filteredComedy,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Genre: Horror
                        if (filteredHorror.isNotEmpty) ...[
                          MovieSection(
                            title: '👻 Horror',
                            items: filteredHorror,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Genre: Romance
                        if (filteredRomance.isNotEmpty) ...[
                          MovieSection(
                            title: '💕 Romance',
                            items: filteredRomance,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Friends are Watching
                        if (_friendsWatching.isNotEmpty &&
                            _selectedTab == _ProviderTab.home) ...[
                          MovieSection(
                            title: 'Friends are Watching',
                            items: _friendsWatching,
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Popular on Provider
                        if (filteredNewArrivals.isNotEmpty) ...[
                          MovieSection(
                            title: 'Popular on ${widget.providerName}',
                            items: filteredNewArrivals.reversed
                                .take(10)
                                .toList(),
                            movieApi: _trendingApi,
                          ),
                          const SizedBox(height: 50),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      snap: true,
      backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.9),
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(widget.providerName, style: theme.textTheme.titleLarge),
      
    );
  }

  Widget _buildCategoryTabs(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return SliverAppBar(
      pinned: false,
      backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.9),
      toolbarHeight: 50,
      automaticallyImplyLeading: false,
      elevation: 0,
      titleSpacing: 0,
      title: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _tabItem('HOME', _ProviderTab.home, colorScheme, isDark),
            const SizedBox(width: 10),
            _tabItem('TV SHOWS', _ProviderTab.tvShows, colorScheme, isDark),
            const SizedBox(width: 10),
            _tabItem('MOVIES', _ProviderTab.movies, colorScheme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(
    String title,
    _ProviderTab tab,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final bool active = _selectedTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tab;
          _currentHeroIndex = 0; // Reset hero index when switching tabs
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: active
              ? null
              : Border.all(color: isDark ? Colors.white30 : Colors.black26),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
