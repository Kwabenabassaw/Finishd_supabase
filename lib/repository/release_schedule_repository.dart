import 'package:hive_flutter/hive_flutter.dart';
import 'package:finishd/models/simkl/simkl_models.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/services/trakt_service.dart';

class ReleaseScheduleRepository {
  static const String _boxName = 'release_schedule_box';

  ReleaseScheduleRepository();

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

    try {
      final trendingApi = Trending();

      // 1. Airing Today (for 'calendarData') - Now powered by Trakt
      final traktService = TraktService();
      final shows = await traktService.fetchTvCalendar();

      // 2. Trending Movies
      final tmdbMovies = await trendingApi.fetchTrendingMoviePaginated(1);
      final trendingMovies = tmdbMovies
          .map(
            (item) => ShowRelease(
              title: item.title,
              date: item.releaseDate.isNotEmpty
                  ? item.releaseDate
                  : DateTime.now().toIso8601String().split('T')[0],
              tmdbId: item.id,
              isMovie: true,
            ),
          )
          .toList();

      // 3. Trending TV
      final tmdbShows = await trendingApi.fetchTrendingShowPaginated(1);
      final trendingShows = tmdbShows
          .map(
            (item) => ShowRelease(
              title: item.title,
              date: item.releaseDate.isNotEmpty
                  ? item.releaseDate
                  : DateTime.now().toIso8601String().split('T')[0],
              tmdbId: item.id,
              isMovie: false,
            ),
          )
          .toList();

      final newSchedule = ReleaseSchedule(
        lastFetched: DateTime.now(),
        shows: shows,
        trendingShows: trendingShows,
        movies: trendingMovies,
      );

      // Save to Hive
      await box.put('current_schedule', newSchedule);
      return newSchedule;
    } catch (e) {
      print('Error fetching schedule from TMDB: $e');
      return ReleaseSchedule(
        lastFetched: DateTime.now(),
        shows: [],
        trendingShows: [],
        movies: [],
      );
    }
  }

  /// Get today's releases from the cached schedule
  Future<List<ShowRelease>> getTodaysReleases() async {
    final schedule = await getSchedule();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    // Filter calendar shows for today's date
    return schedule.shows.where((s) => s.date.startsWith(todayStr)).toList();
  }
}
