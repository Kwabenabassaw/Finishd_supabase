import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finishd/models/simkl/simkl_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';

class ScheduleSeeAllScreen extends StatefulWidget {
  final List<ShowRelease> scheduleItems;

  const ScheduleSeeAllScreen({super.key, required this.scheduleItems});

  @override
  State<ScheduleSeeAllScreen> createState() => _ScheduleSeeAllScreenState();
}

class _ScheduleSeeAllScreenState extends State<ScheduleSeeAllScreen> {
  final List<dynamic> _flattenedSchedule = [];
  final List<String> _sortedDates = [];
  final Map<String, int> _itemCounts = {};
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = "";

  // Track the currently visible date for sticky header effect
  String _currentHeader = "";

  @override
  void initState() {
    super.initState();
    _groupAndSortSchedule();

    if (_sortedDates.isNotEmpty) {
      _currentHeader = _sortedDates.first;
    }

    _searchController.addListener(_onSearchChanged);
    // Add listener for scroll-based header changes
    _scrollController.addListener(_onScroll);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _groupAndSortSchedule();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _groupAndSortSchedule() {
    _flattenedSchedule.clear();
    _sortedDates.clear();
    _itemCounts.clear();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final Map<String, List<ShowRelease>> groupedSchedule = {};
    for (var item in widget.scheduleItems) {
      // Skip shows with air dates in the past
      try {
        final airDate = DateTime.parse(item.date);
        final airDay = DateTime(airDate.year, airDate.month, airDate.day);
        if (airDay.isBefore(today)) continue;
      } catch (_) {
        // Keep items with unparseable dates
      }

      if (_searchQuery.isNotEmpty &&
          !item.title.toLowerCase().contains(_searchQuery)) {
        continue;
      }

      final dateKey = _formatDateKey(item.date);
      if (!groupedSchedule.containsKey(dateKey)) {
        groupedSchedule[dateKey] = [];
      }
      groupedSchedule[dateKey]!.add(item);
    }

    _sortedDates.addAll(groupedSchedule.keys);
    _sortedDates.sort((a, b) {
      final originalA = groupedSchedule[a]!.first.date;
      final originalB = groupedSchedule[b]!.first.date;
      return originalA.compareTo(originalB);
    });

    for (var dateKey in _sortedDates) {
      _flattenedSchedule.add(dateKey);
      _flattenedSchedule.addAll(groupedSchedule[dateKey]!);
      _itemCounts[dateKey] = groupedSchedule[dateKey]!.length;
    }

    if (_sortedDates.isNotEmpty) {
      if (!_sortedDates.contains(_currentHeader)) {
        _currentHeader = _sortedDates.first;
      }
    } else {
      _currentHeader = "";
    }
  }

  String _formatDateKey(String rawDate) {
    try {
      final itemDate = DateTime.parse(rawDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final targetDate = DateTime(itemDate.year, itemDate.month, itemDate.day);

      if (targetDate == today) {
        return "Today";
      } else if (targetDate == tomorrow) {
        return "Tomorrow";
      } else {
        return DateFormat('EEE, MMM d').format(targetDate);
      }
    } catch (e) {
      return rawDate;
    }
  }

  // Simple scroll listener to calculate which section is roughly at the top
  void _onScroll() {
    // Estimating positions based on average item height (approx 80px)
    // plus header heights (approx 50px).
    // For a more precise sticky header, plugins like flutter_sticky_header are better,
    // but custom scroll tracking avoids extra dependencies.
    if (!_scrollController.hasClients) return;

    double offset = _scrollController.offset;
    double currentPos = 0.0;

    for (int i = 0; i < _sortedDates.length; i++) {
      String dateKey = _sortedDates[i];
      int itemCount = _itemCounts[dateKey]!;

      // Rough height of this group: header(48) + padding(16) + (itemCount * 84)
      double sectionHeight = 48.0 + 16.0 + (itemCount * 84.0);

      if (offset >= currentPos && offset < currentPos + sectionHeight) {
        if (_currentHeader != dateKey) {
          setState(() {
            _currentHeader = dateKey;
          });
        }
        break;
      }
      currentPos += sectionHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: "Search shows...",
                  border: InputBorder.none,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.5),
                  ),
                ),
              )
            : const Text(
                "TV Release Schedule",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _flattenedSchedule.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        "No shows found",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    top: 60,
                    bottom: 40,
                  ), // Space for floating header
                  itemCount: _flattenedSchedule.length,
                  itemBuilder: (context, index) {
                    final item = _flattenedSchedule[index];

                    if (item is String) {
                      return _buildSectionHeader(item);
                    } else if (item is ShowRelease) {
                      return _buildScheduleRowItem(item);
                    }
                    return const SizedBox.shrink();
                  },
                ),

          // Floating Sticky Header with Animation
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, -0.5),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Container(
                key: ValueKey<String>(_currentHeader),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(width: 1)),
                ),
                child: Text(
                  _currentHeader,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,

                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildScheduleRowItem(ShowRelease item) {
    String episodeText = '';
    if (item.season != null && item.episode != null) {
      episodeText =
          "S${item.season.toString().padLeft(2, '0')}E${item.episode.toString().padLeft(2, '0')}";
    } else {
      episodeText = "Series Premiere / TBA";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        onTap: () {
          if (item.tmdbId != null) {
            final shallowShow = TvShowDetails(
              id: item.tmdbId!,
              name: item.title,
              originalName: item.title,
              overview: '',
              posterPath: null,
              backdropPath: null,
              firstAirDate: item.date,
              inProduction: false,
              genres: [],
              languages: [],
              networks: [],
              numberOfEpisodes: 0,
              numberOfSeasons: 0,
              seasons: [],
              status: 'Loading...',
              type: 'tv',
              voteAverage: 0.0,
              voteCount: 0,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShowDetailsScreen(movie: shallowShow),
              ),
            );
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.tmdbId != null
                ? CachedNetworkImage(
                    imageUrl:
                        "https://image.tmdb.org/t/p/w200/${item.tmdbId}", // Small resolution avatar
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: Icon(
                        Icons.tv_rounded,
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.5),
                        size: 24,
                      ),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(
                        Icons.play_circle_filled_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.play_circle_filled_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                  ),
          ),
        ),
        title: Text(
          item.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                Icons.tv_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                episodeText,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
