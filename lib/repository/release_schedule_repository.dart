import 'package:hive_flutter/hive_flutter.dart';
import 'package:finishd/models/simkl/simkl_models.dart';
import 'package:finishd/services/simkl_service.dart';

class ReleaseScheduleRepository {
  static const String _boxName = 'release_schedule_box';
  final SimklService _simklService;

  ReleaseScheduleRepository({SimklService? simklService})
      : _simklService = simklService ?? SimklService();

  Future<void> init() async {
    // Make sure adapters are registered before calling init
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(ShowReleaseAdapter());
    }
    if (!Hive.isAdapterRegistered(101)) {
      Hive.registerAdapter(ReleaseScheduleAdapter());
    }
    await Hive.openBox<ReleaseSchedule>(_boxName);
  }

  /// Get the current schedule. If it's expired (older than 3 days) or empty,
  /// fetch a new one from SIMKL API and cache it.
  Future<ReleaseSchedule> getSchedule() async {
    final box = Hive.box<ReleaseSchedule>(_boxName);
    final ReleaseSchedule? cached = box.get('current_schedule');

    if (cached != null) {
      final difference = DateTime.now().difference(cached.lastFetched).inDays;
      if (difference < 3) {
        return cached; // Cache is still fresh
      }
    }

    // Cache expired or missing, fetch new data
    return await _fetchAndCacheSchedule();
  }

  Future<ReleaseSchedule> _fetchAndCacheSchedule() async {
    final box = Hive.box<ReleaseSchedule>(_boxName);

    // Fetch calendar and trending
    final shows = await _simklService.fetchTvCalendar();
    final trendingMovies = await _simklService.fetchTrendingMovies();
    final trendingShows = await _simklService.fetchTrendingTv();

    // DO NOT merge trending shows with the calendar schedule.
    // This avoids triggering fake "new episode" alerts for trending shows
    // when a user is "watching" a trending show (since trending shows lack season/episode data).
    final newSchedule = ReleaseSchedule(
      lastFetched: DateTime.now(),
      shows: shows,
      trendingShows: trendingShows,
      movies: trendingMovies,
    );

    // Save to Hive
    await box.put('current_schedule', newSchedule);

    return newSchedule;
  }

  /// Get today's releases from the cached schedule
  Future<List<ShowRelease>> getTodaysReleases() async {
    final schedule = await getSchedule();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    // Filter calendar shows for today's date
    return schedule.shows.where((s) => s.date.startsWith(todayStr)).toList();
  }
}
