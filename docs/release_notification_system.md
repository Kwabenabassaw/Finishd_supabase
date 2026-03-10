# Smart Release Notification System

## 1. System Architecture
The Smart Release Notification System is designed to keep users informed about new episodes of the shows they are watching, as well as trending shows and movies, while strictly preserving battery and memory.
The system integrates:
- **SIMKL API Service:** A networking layer using `dio` that fetches TV calendars and trending lists.
- **Hive Caching Layer:** An offline-first repository (`ReleaseScheduleRepository`) that caches the release schedule.
- **Background Worker:** A daily job executed via `workmanager` that runs in a background isolate.
- **Notification Manager:** A wrapper around `flutter_local_notifications` that ensures non-duplicative, rate-limited local notifications.
- **Supabase Integration:** Connects to the `user_titles` table to extract the user's currently watched titles.

## 2. How the Schedule System Works
The `ReleaseScheduleRepository` manages schedule data:
- When queried, it checks Hive for `current_schedule`.
- If the schedule exists and is less than 3 days old, the cached version is immediately returned.
- If it is expired or missing, the system calls the SIMKL API (`/tv/calendar`, `/tv/trending`, `/movies/trending`).
- The fetched data is merged into a `ReleaseSchedule` object, stored in Hive using manually written TypeAdapters (to avoid ObjectBox dependency conflicts), and then returned.

## 3. Background Worker Behavior
The background worker (`lib/workers/schedule_worker.dart`) runs once every 24 hours. Because it runs in a separate Dart isolate:
- It unconditionally initializes Hive and registers the necessary adapters.
- It unconditionally initializes Supabase using environment variables (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) to prevent `LateInitializationError`s.
- It reads the user's active session. If a user is logged in, it retrieves today's releases from the cache.
- It queries Supabase for all `user_titles` where `status = 'watching'`.
- It cross-references the TMDB IDs from SIMKL against the `title_id` values from Supabase.
- If matches are found, it dispatches a Personalized Alert. Otherwise, it dispatches a Trending Alert.

## 4. Local Caching Strategy
The system uses **Hive** for aggressive local caching. The schedule can contain up to 30 days of data with hundreds of entries.
- Caching the schedule locally ensures that the background worker does not drain the battery by making daily network calls.
- The 3-day expiration strategy perfectly balances data freshness with API rate limit conservation.
- Separate lists (`shows`, `trendingShows`, `movies`) are maintained to prevent "New Episode" false positives on trending shows.

## 5. Notification Flow
`ScheduleNotificationService` handles all alert dispatching:
- **Deduplication:** Before dispatching, it checks `SharedPreferences` for the `last_schedule_notification_date`. If a notification was already sent on the current calendar day, the request is ignored.
- **Personalized Alerts:** Takes the first matched show, formats its Season and Episode numbers (e.g., "S06E05"), and mentions the remaining count if there are multiple matches.
- **Trending Alerts:** Collects up to 3 trending shows and 2 trending movies and formats them into a single string.
- Notifications are configured with high priority and importance for both Android and iOS.

## 6. Data Comparison Logic
The comparison algorithm is heavily optimized:
1. `ReleaseScheduleRepository.getTodaysReleases()` filters the cached schedule down to only shows matching today's ISO-8601 date string prefix.
2. The worker retrieves the list of `title_id` strings from Supabase (where `status == 'watching'`) and parses them into integers.
3. A simple $O(N)$ loop checks if each release's `tmdbId` exists in the `watchingIds` list.
4. Matches are collected into a `matches` list, which immediately feeds into the notification service.

## 7. Performance Optimizations
- **Isolate Safety & Memory:** The background worker does not load the entire application state. It only loads the minimum necessary services (Hive, Supabase, Notifications).
- **Chunked Processing:** The worker filters the 30-day schedule down to *today's* releases before comparing IDs, keeping the in-memory array extremely small.
- **Network Reduction:** API calls are strictly limited by the 3-day Hive cache.
- **Dependency Minimization:** Manually written Hive adapters avoided adding `hive_generator` to `dev_dependencies`, bypassing a massive conflict with ObjectBox.

## 8. API Integration
The `SimklService` (`lib/services/simkl_service.dart`) uses `dio` with a predefined `simkl-api-key` header (loaded via `String.fromEnvironment('simkl')`).
It correctly handles nested and flat JSON structures for `episode` and `season` data, ensuring backwards compatibility and parsing safety against unexpected `null` values.

---

## Future Limitations

### API Rate Limits
While the 3-day cache strategy significantly mitigates the risk, if the app user base scales dramatically, SIMKL API rate limits could become a bottleneck for users requesting fresh schedules simultaneously (e.g., right after cache expiration).

### Scaling Issues
Currently, the background worker queries the entire list of `watching` titles from Supabase. For power users with thousands of watched shows, this query could become slow and memory-intensive on low-end devices.

### Schedule Inconsistencies
SIMKL calendar data relies on external sources. Delays, unannounced hiatuses, or timezone differences might cause a notification to trigger a day early or a day late.

### Edge Cases
- If a user changes their device timezone, the background worker might fire twice or miss a day due to the way `SharedPreferences` stores the last notification date.
- Shows that lack a TMDB ID in the SIMKL API will silently fail to match against the user's Supabase library.

### Potential Need for Server-Side Processing
If the user base grows, relying on local device background execution for thousands of devices is inefficient. A better future architecture would be to offload the TMDB ID matching to a **Supabase Edge Function** triggered via a daily CRON job. The server would compare schedules against users' libraries and send Push Notifications directly via Firebase Cloud Messaging (FCM) or Apple Push Notification service (APNs). This would entirely remove the need for local caching and heavy background isolate work.