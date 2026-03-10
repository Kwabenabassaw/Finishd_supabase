import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finishd/models/simkl/simkl_models.dart';

class ScheduleSeeAllScreen extends StatefulWidget {
  final List<ShowRelease> scheduleItems;

  const ScheduleSeeAllScreen({
    super.key,
    required this.scheduleItems,
  });

  @override
  State<ScheduleSeeAllScreen> createState() => _ScheduleSeeAllScreenState();
}

class _ScheduleSeeAllScreenState extends State<ScheduleSeeAllScreen> {
  final Map<String, List<ShowRelease>> _groupedSchedule = {};
  final List<String> _sortedDates = [];
  final ScrollController _scrollController = ScrollController();

  // Track the currently visible date for sticky header effect
  String _currentHeader = "";

  @override
  void initState() {
    super.initState();
    _groupAndSortSchedule();

    if (_sortedDates.isNotEmpty) {
      _currentHeader = _sortedDates.first;
    }

    // Add listener for scroll-based header changes
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _groupAndSortSchedule() {
    for (var item in widget.scheduleItems) {
      final dateKey = _formatDateKey(item.date);
      if (!_groupedSchedule.containsKey(dateKey)) {
        _groupedSchedule[dateKey] = [];
      }
      _groupedSchedule[dateKey]!.add(item);
    }

    _sortedDates.addAll(_groupedSchedule.keys);
    _sortedDates.sort((a, b) {
      // Parse the 'yyyy-MM-dd' formatted date key back to DateTime for proper sorting
      // But we just formatted them beautifully (e.g., 'Today', 'Tomorrow', 'Mar 12')
      // Let's re-extract the real dates to sort
      final originalA = _groupedSchedule[a]!.first.date;
      final originalB = _groupedSchedule[b]!.first.date;
      return originalA.compareTo(originalB);
    });
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
      int itemCount = _groupedSchedule[dateKey]!.length;

      // Rough height of this group: header(50) + padding(16) + (itemCount * 80)
      double sectionHeight = 50.0 + 16.0 + (itemCount * 80.0);

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
    return Scaffold(
      backgroundColor: Colors.black, // Dark theme as per project
      appBar: AppBar(
        title: const Text(
          "TV Release Schedule",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 60, bottom: 40), // Space for floating header
            itemCount: _sortedDates.length,
            itemBuilder: (context, index) {
              final dateKey = _sortedDates[index];
              final items = _groupedSchedule[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(dateKey),
                  ...items.map((item) => _buildScheduleRowItem(item)),
                  const SizedBox(height: 16),
                ],
              );
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
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey<String>(_currentHeader),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.95), // Slight transparency for floating effect
                  border: const Border(
                    bottom: BorderSide(color: Colors.white12, width: 1),
                  ),
                ),
                child: Text(
                  _currentHeader,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.green, // Highlight color
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildScheduleRowItem(ShowRelease item) {
    String episodeText = '';
    if (item.season != null && item.episode != null) {
      episodeText = "S${item.season.toString().padLeft(2, '0')}E${item.episode.toString().padLeft(2, '0')}";
    } else {
      episodeText = "Series Premiere / TBA";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_filled_rounded, color: Colors.green, size: 28),
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.tv_rounded, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                episodeText,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
