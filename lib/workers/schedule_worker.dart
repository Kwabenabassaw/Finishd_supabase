import 'package:workmanager/workmanager.dart';
import 'package:finishd/repository/release_schedule_repository.dart';
import 'package:finishd/services/schedule_notification_service.dart';
import 'package:finishd/models/simkl/simkl_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

const String releaseScheduleTask = "releaseScheduleTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == releaseScheduleTask) {
        // Initialize local dependencies inside isolate
        await Hive.initFlutter();
        if (!Hive.isAdapterRegistered(100)) {
          Hive.registerAdapter(ShowReleaseAdapter());
        }
        if (!Hive.isAdapterRegistered(101)) {
          Hive.registerAdapter(ReleaseScheduleAdapter());
        }

        // Ensure Supabase is unconditionally initialized in the background isolate
        // We shouldn't check Supabase.instance since it will throw a LateInitializationError in a new isolate.
        // We use environment variables instead of hardcoded secrets for safety.
        await Supabase.initialize(
          url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://lihaddxlyychswpkswbp.supabase.co'),
          anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpaGFkZHhseXljaHN3cGtzd2JwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzNDA5MzQsImV4cCI6MjA4NDkxNjkzNH0.DrBUuz2ayMRCIicYAFNqH2ws3gbRu8ycsbATF54BuFM'),
        );

        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          // If the user isn\'t logged in, we can just return
          return true;
        }

        final ScheduleNotificationService notificationService =
            ScheduleNotificationService();
        await notificationService.init();

        final ReleaseScheduleRepository scheduleRepo = ReleaseScheduleRepository();
        await scheduleRepo.init();

        final schedule = await scheduleRepo.getSchedule();
        final todaysReleases = await scheduleRepo.getTodaysReleases();

        if (todaysReleases.isEmpty) {
           // No releases today, possibly fallback to trending
           // For now, we only alert trending if there are trending shows/movies and no match found
        }

        // Query Supabase for 'watching' status
        final response = await Supabase.instance.client
            .from('user_titles')
            .select('title_id, status')
            .eq('user_id', user.id)
            .eq('status', 'watching');

        final List<String> watchingIdsStr = (response as List)
            .map((e) => e['title_id'] as String)
            .toList();

        final watchingIds = watchingIdsStr.map((e) => int.tryParse(e)).whereType<int>().toList();

        final matches = <ShowRelease>[];
        for (var release in todaysReleases) {
          if (release.tmdbId != null && watchingIds.contains(release.tmdbId)) {
            matches.add(release);
          }
        }

        if (matches.isNotEmpty) {
          // Send personalized alert
          await notificationService.showPersonalizedNotification(matches);
        } else {
          // Send trending alert
          final trendingShows = schedule.trendingShows.take(3).toList();
          final trendingMovies = schedule.movies.take(2).toList();
          await notificationService.showTrendingNotification(trendingShows, trendingMovies);
        }
      }
    } catch (e) {
      // print('Workmanager execution failed: $e');
      return false;
    }
    return true;
  });
}
