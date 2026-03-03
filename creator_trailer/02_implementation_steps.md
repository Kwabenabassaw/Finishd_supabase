# Implementation Steps: Creators & Trailers Split

## Phase 1: Preparation & Dependency Updates
1. **Analyze Dependencies:**
   - Add `better_player` to `pubspec.yaml` (or ensure it's there instead of `video_player` if preferred for caching).
   - Ensure `youtube_player_flutter` is up to date for strict SDK compliance.

## Phase 2: Navigation Restructuring
1. **Remove Old Tabs:**
   - In `lib/Feed/feed_tabs_wrapper.dart`, rename the tabs from `['Following', 'For You', 'Trending']` to `['Trailers', 'Creators']`.
   - Update `_onTabTapped` logic to switch between `FeedType.trailers` and `FeedType.creators` (this enum needs updating in `provider/youtube_feed_provider.dart` or a new provider).
2. **Tab Routing:**
   - Update `feedWidget` injection or use a `TabBarView` to render `TrailersDiscoveryScreen` when Trailers is selected, and `CreatorsFeedScreen` when Creators is selected.

## Phase 3: Creators Tab (TikTok Mode)
1. **Dedicated Provider:**
   - Create `lib/provider/creators_feed_provider.dart` to fetch only `creator_videos` endpoints from Supabase.
2. **Creators Feed Screen (`lib/Feed/creators_feed_screen.dart`):**
   - Implement `PageView.builder(scrollDirection: Axis.vertical)`.
   - Instantiate `CreatorVideoPlayer` for each item.
3. **Creator Video Player (`lib/Feed/creator_video_player.dart`):**
   - Extract the `video_player` / `better_player` logic from the existing `FeedVideoPlayerV2`.
   - Implement strict controller management: preload index + 1, dispose index - 1, keeping only 2 controllers active.
   - UI structure: Full video, bottom-left creator info/caption, bottom-right interaction column (❤️ 💬 🔁).

## Phase 4: Trailers Tab (Discovery Mode)
1. **Dedicated Provider:**
   - Create `lib/provider/trailers_feed_provider.dart` to source TMDB/YouTube trending metadata (grid view items).
2. **Trailers Discovery Screen (`lib/Feed/trailers_discovery_screen.dart`):**
   - Implement a `GridView.builder` with `SliverGridDelegateWithFixedCrossAxisCount` (e.g., 2 or 3 columns).
   - Display video poster/thumbnail and title.
   - On tap, navigate to `TrailerDetailScreen`.
3. **Trailer Detail Screen (`lib/Feed/trailer_detail_screen.dart`):**
   - Implement `youtube_player_flutter` pinned at the top in landscape ratio (16:9).
   - Below video: Actions row (👍 👎 💬 Share).
   - Below actions: Description / Metadata.
   - Bottom: Scrollable comments list.
   - No preloading, standard YouTube iframe compliance.

## Phase 5: Backend & Data Sourcing
1. **Update API Client (`lib/services/api_client.dart`):**
   - Add/Update `getCreatorsFeed()` to query Supabase `creator_videos` merged with the ML ranking algorithm.
   - Add/Update `getTrailersFeed()` to query TMDB / `titles` and YouTube keys for the trailers grid.
2. **ML Microservice Focus:**
   - Ensure the backend machine learning ranking exclusively models `creator_videos` engagement (watch time, likes) for the Creators tab.

## Phase 6: Refactoring & Cleanup
1. **Remove Mixed Feed Tech:**
   - Deprecate/Remove `FeedVideoPlayerV2` and `HomeScreenV2` (or heavily strip them down) once the two new screens replace them.
2. **Performance Audit:**
   - Verify Creators tab scrolling is 60fps and memory is stable with `mp4` caching.
   - Verify Trailers tab `GridView` loads thumbnails efficiently without stutter, and `youtube_player_flutter` only initializes on the Detail screen.
