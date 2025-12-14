import 'package:flutter/material.dart';
import 'package:finishd/services/backend_notification_service.dart';
import 'package:finishd/services/episode_alert_service.dart';
import 'package:finishd/services/cache/notification_cache_service.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final BackendNotificationService _notificationService =
      BackendNotificationService();
  final EpisodeAlertService _episodeService = EpisodeAlertService();

  List<AppNotification> _allNotifications = [];
  List<EpisodeAlert> _newEpisodes = [];
  List<TVNotification> _tvNotifications = [];
  List<RecommendedShow> _recommendations = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadFromCacheThenNetwork();
  }

  /// Cache-first loading strategy for instant display
  Future<void> _loadFromCacheThenNetwork() async {
    setState(() => _isLoading = true);

    // 1. Try loading from cache first (instant display)
    try {
      final cachedAll = await NotificationCacheService.getNotifications('all');
      final cachedEpisodes = await NotificationCacheService.getNotifications(
        'new_episodes',
      );
      final cachedTV = await NotificationCacheService.getNotifications('tv');
      final cachedRecs = await NotificationCacheService.getNotifications(
        'recommendations',
      );

      bool hasCache = false;

      if (cachedAll != null && cachedAll.isNotEmpty) {
        _allNotifications = cachedAll
            .map((n) => AppNotification.fromJson(n))
            .toList();
        hasCache = true;
      }

      if (cachedEpisodes != null && cachedEpisodes.isNotEmpty) {
        _newEpisodes = cachedEpisodes
            .map((e) => EpisodeAlert.fromJson(e))
            .toList();
        hasCache = true;
      }

      if (cachedTV != null && cachedTV.isNotEmpty) {
        _tvNotifications = cachedTV
            .map((n) => TVNotification.fromJson(n))
            .toList();
        hasCache = true;
      }

      if (cachedRecs != null && cachedRecs.isNotEmpty) {
        _recommendations = cachedRecs
            .map((r) => RecommendedShow.fromJson(r))
            .toList();
        hasCache = true;
      }

      if (hasCache) {
        setState(() => _isLoading = false);
        print('📦 Loaded notifications from cache');

        // 2. Refresh from network in background
        _refreshInBackground();
        return;
      }
    } catch (e) {
      print('⚠️ Error loading from cache: $e');
    }

    // 3. No cache, load directly from network
    await _loadData();
  }

  /// Refresh from network in background (doesn't block UI)
  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await _fetchAndCacheFromNetwork();
      print('✅ Background refresh complete');
    } catch (e) {
      print('⚠️ Background refresh failed: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// Fetch from network and save to cache
  Future<void> _fetchAndCacheFromNetwork() async {
    final results = await Future.wait([
      _notificationService.getNotifications(),
      _episodeService.checkNewEpisodes(),
      _episodeService.getTVNotifications(),
      _episodeService.getRecommendations(),
    ]);

    // Cache the raw JSON data
    final allData = (results[0] as List<AppNotification>)
        .map((n) => n.toJson())
        .toList();
    final episodesData = (results[1] as List<EpisodeAlert>)
        .map((e) => e.toJson())
        .toList();
    final tvData = (results[2] as List<TVNotification>)
        .map((n) => n.toJson())
        .toList();
    final recsData = (results[3] as List<RecommendedShow>)
        .map((r) => r.toJson())
        .toList();

    await NotificationCacheService.saveNotifications('all', allData);
    await NotificationCacheService.saveNotifications(
      'new_episodes',
      episodesData,
    );
    await NotificationCacheService.saveNotifications('tv', tvData);
    await NotificationCacheService.saveNotifications(
      'recommendations',
      recsData,
    );

    if (mounted) {
      setState(() {
        _allNotifications = results[0] as List<AppNotification>;
        _newEpisodes = results[1] as List<EpisodeAlert>;
        _tvNotifications = results[2] as List<TVNotification>;
        _recommendations = results[3] as List<RecommendedShow>;
      });
    }
  }

  /// Load directly from network (fallback when no cache)
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _fetchAndCacheFromNetwork();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _notificationService.markAllAsRead();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllRead,
              tooltip: 'Mark all as read',
            ),
          ],
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
                  Tab(text: 'All'),
                  Tab(text: 'New Episodes'),
                  Tab(text: 'For You'),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAllNotificationsTab(),
                  _buildNewEpisodesTab(),
                  _buildRecommendationsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildAllNotificationsTab() {
    // Combine TV notifications with regular notifications
    final List<dynamic> allItems = [..._tvNotifications, ..._allNotifications];

    if (allItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allItems.length,
        itemBuilder: (context, index) {
          final item = allItems[index];
          if (item is TVNotification) {
            return _TVNotificationTile(notification: item);
          } else if (item is AppNotification) {
            return _NotificationTile(
              notification: item,
              onTap: () async {
                await _notificationService.markAsRead(item.id);
                if (item.isNewEpisode) {
                  // Navigate to show details
                } else if (item.isTrending) {
                  // Navigate to trending
                }
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildNewEpisodesTab() {
    // Combine new episodes from both sources
    final combinedEpisodes = [
      ..._tvNotifications.where((n) => n.isNewEpisode),
      ..._newEpisodes.map((e) => e),
    ];

    if (combinedEpisodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No new episodes',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'New episodes from shows you\'re watching will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: combinedEpisodes.length,
        itemBuilder: (context, index) {
          final item = combinedEpisodes[index];
          if (item is TVNotification) {
            return _TVNotificationTile(notification: item);
          } else if (item is EpisodeAlert) {
            return _EpisodeAlertTile(episode: item);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    // Show recommendations and recommended notifications
    final recommendedNotifications = _tvNotifications
        .where((n) => n.isRecommended)
        .toList();

    if (_recommendations.isEmpty && recommendedNotifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.recommend, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No recommendations yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Add shows to your watching list\nto get personalized recommendations',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Show recommended notifications first
          if (recommendedNotifications.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'New Episodes from Recommended Shows',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...recommendedNotifications.map(
              (n) => _TVNotificationTile(notification: n),
            ),
            const SizedBox(height: 16),
          ],
          // Show recommendations
          if (_recommendations.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Shows You Might Like',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ..._recommendations.map((r) => _RecommendedShowTile(show: r)),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const _NotificationTile({required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.read ? Colors.grey[300] : Colors.green,
          child: Icon(_getIcon(), color: Colors.white),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              notification.timeAgo,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _getIcon() {
    if (notification.isNewEpisode) return Icons.tv;
    if (notification.isTrending) return Icons.trending_up;
    if (notification.isChat) return Icons.chat;
    return Icons.notifications;
  }
}

class _TVNotificationTile extends StatelessWidget {
  final TVNotification notification;

  const _TVNotificationTile({required this.notification});

  Future<void> _navigateToDetails(BuildContext context) async {
    if (notification.tmdbId <= 0) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: LogoLoadingScreen()),
    );

    try {
      final movieApi = Trending();

      // Fetch TV show details (TV notifications are for shows)
      final tvDetails = await movieApi.fetchDetailsTvShow(notification.tmdbId);

      // Close loading
      if (context.mounted) Navigator.pop(context);

      if (tvDetails != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShowDetailsScreen(movie: tvDetails),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load show details')),
        );
      }
    } catch (e) {
      // Close loading
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: notification.posterUrl.isNotEmpty
                    ? Image.network(
                        notification.posterUrl,
                        width: 60,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 90,
                          color: Colors.grey[300],
                          child: const Icon(Icons.tv),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 90,
                        color: Colors.grey[300],
                        child: const Icon(Icons.tv),
                      ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (notification.episodeLabel.isNotEmpty)
                      Text(
                        notification.episodeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (notification.message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.message!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Icon based on type
              Icon(
                notification.isNewEpisode
                    ? Icons.fiber_new
                    : notification.isRecommended
                    ? Icons.recommend
                    : Icons.trending_up,
                color: notification.isRead ? Colors.grey : Colors.green,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeAlertTile extends StatelessWidget {
  final EpisodeAlert episode;

  const _EpisodeAlertTile({required this.episode});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to show details
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: episode.posterUrl.isNotEmpty
                    ? Image.network(
                        episode.posterUrl,
                        width: 60,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 90,
                          color: Colors.grey[300],
                          child: const Icon(Icons.tv),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 90,
                        color: Colors.grey[300],
                        child: const Icon(Icons.tv),
                      ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.showName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${episode.episodeLabel} - ${episode.episodeName}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    if (episode.airDate != null)
                      Text(
                        'Aired: ${episode.airDate}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              // Icon
              const Icon(Icons.fiber_new, color: Colors.green, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedShowTile extends StatelessWidget {
  final RecommendedShow show;

  const _RecommendedShowTile({required this.show});

  Future<void> _navigateToDetails(BuildContext context) async {
    if (show.id <= 0) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: LogoLoadingScreen()),
    );

    try {
      final movieApi = Trending();
      final tvDetails = await movieApi.fetchDetailsTvShow(show.id);

      // Close loading
      if (context.mounted) Navigator.pop(context);

      if (tvDetails != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShowDetailsScreen(movie: tvDetails),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load show details')),
        );
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: show.posterUrl.isNotEmpty
                    ? Image.network(
                        show.posterUrl,
                        width: 60,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 90,
                          color: Colors.grey[300],
                          child: const Icon(Icons.tv),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 90,
                        color: Colors.grey[300],
                        child: const Icon(Icons.tv),
                      ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      show.reason,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (show.hasNewEpisode)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'NEW EP',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (show.hasNewEpisode && show.isTrending)
                          const SizedBox(width: 8),
                        if (show.isTrending)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'TRENDING',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Recommend icon
              const Icon(Icons.recommend, color: Colors.blue, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
