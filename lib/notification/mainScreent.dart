import 'package:flutter/material.dart';
import 'package:finishd/models/simkl/simkl_models.dart';
import 'package:finishd/repository/release_schedule_repository.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ReleaseScheduleRepository _scheduleRepo = ReleaseScheduleRepository();

  List<ShowRelease> _todaysReleases = [];
  List<ShowRelease> _trendingShows = [];
  List<ShowRelease> _trendingMovies = [];
  List<ShowRelease> _watchingMatches = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _scheduleRepo.init();
      final schedule = await _scheduleRepo.getSchedule();
      final todays = await _scheduleRepo.getTodaysReleases();

      // Get user's watching list to highlight their shows
      final user = Supabase.instance.client.auth.currentUser;
      List<ShowRelease> matches = [];

      if (user != null) {
        final response = await Supabase.instance.client
            .from('user_titles')
            .select('title_id, status')
            .eq('user_id', user.id)
            .eq('status', 'watching');

        final List<String> watchingIdsStr = (response as List)
            .map((e) => e['title_id'] as String)
            .toList();

        final watchingIds = watchingIdsStr
            .map((e) => int.tryParse(e))
            .whereType<int>()
            .toList();

        for (var release in todays) {
          if (release.tmdbId != null && watchingIds.contains(release.tmdbId)) {
            matches.add(release);
          }
        }
      }

      if (mounted) {
        setState(() {
          _todaysReleases = todays;
          _watchingMatches = matches;
          _trendingShows = schedule.trendingShows;
          _trendingMovies = schedule.movies;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Releases & Alerts'),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey,
                    width: 0.5,
                  ),
                ),
              ),
              child: TabBar(
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                indicatorColor: Colors.green,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Your Shows'),
                  Tab(text: 'Today'),
                  Tab(text: 'Trending'),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildWatchingTab(),
                  _buildTodayTab(),
                  _buildTrendingTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildWatchingTab() {
    if (_watchingMatches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No new episodes for your shows today',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _buildList(_watchingMatches, isHighlight: true);
  }

  Widget _buildTodayTab() {
    if (_todaysReleases.isEmpty) {
      return const Center(
        child: Text('No releases today', style: TextStyle(color: Colors.grey)),
      );
    }
    return _buildList(_todaysReleases);
  }

  Widget _buildTrendingTab() {
    final combined = [..._trendingShows, ..._trendingMovies];
    if (combined.isEmpty) {
      return const Center(
        child: Text('No trending data', style: TextStyle(color: Colors.grey)),
      );
    }
    return _buildList(combined, isTrending: true);
  }

  Widget _buildList(
    List<ShowRelease> items, {
    bool isHighlight = false,
    bool isTrending = false,
  }) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _ShowReleaseTile(
            release: item,
            isHighlight: isHighlight,
            isTrending: isTrending,
          );
        },
      ),
    );
  }
}

class _ShowReleaseTile extends StatelessWidget {
  final ShowRelease release;
  final bool isHighlight;
  final bool isTrending;

  const _ShowReleaseTile({
    required this.release,
    this.isHighlight = false,
    this.isTrending = false,
  });

  Future<void> _navigateToDetails(BuildContext context) async {
    if (release.tmdbId == null || release.tmdbId! <= 0) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: LogoLoadingScreen()),
    );

    try {
      final trendingApi = Trending();
      if (release.isMovie) {
        final details = await trendingApi.fetchMovieDetails(release.tmdbId!);
        if (context.mounted) Navigator.pop(context);

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movie: details),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load movie details')),
          );
        }
      } else {
        final details = await trendingApi.fetchDetailsTvShow(release.tmdbId!);
        if (context.mounted) Navigator.pop(context);

        if (details != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShowDetailsScreen(movie: details),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load show details')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String seasonStr = release.season != null
        ? "S${release.season.toString().padLeft(2, '0')}"
        : "";
    final String episodeStr = release.episode != null
        ? "E${release.episode.toString().padLeft(2, '0')}"
        : "";
    final String label = "$seasonStr$episodeStr";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isHighlight
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  release.isMovie ? Icons.movie : Icons.tv,
                  color: isHighlight
                      ? Colors.green
                      : (isTrending ? Colors.orange : Colors.grey[600]),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      release.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (label.isNotEmpty)
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      release.date,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (isHighlight)
                const Icon(Icons.fiber_new, color: Colors.green, size: 28)
              else if (isTrending)
                const Icon(Icons.trending_up, color: Colors.orange, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
