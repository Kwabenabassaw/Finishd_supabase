# Architectural Analysis: Creators & Trailers Split

## 1. Current State of the Codebase

### Database Layer
- **Implemented:** The `creator_videos` table is fully provisioned in Supabase via migration `20250215000005_creator_videos.sql`. It includes columns for metadata, TMDB linking, counters (views, likes, comments), scoring, and moderation status.
- **Implemented:** Tables for `video_engagement_events`, `video_reactions`, and `video_comments` exist and are tied to `creator_videos`.

### Flutter UI & Navigation
- **Current Architecture:** Both TMDB trailers (YouTube) and Creator Content (MP4) are mixed in a single vertical scrolling feed (`HomeScreenV2`).
- **Current Navigation:** `FeedTabsWrapper.dart` provides top-level tabs: `Following`, `For You`, `Trending`.
- **Current Playback:** `FeedVideoPlayerV2` attempts to handle both `youtube_player_flutter` (for Trailers/BTS) and `video_player` (for Creator Videos) dynamically based on the `FeedItem` type.

### Backend Feed Strategy
- **Current State:** The backend (`getPersonalizedFeedV2` / `getGlobalFeed`) returns a mix of TMDB/YouTube content and (presumably) Creator Content in a single stream.

---

## 2. What Needs to be Implemented

### A. Navigation Restructuring
- **Action:** Replace the `Following | For You | Trending` tabs in `FeedTabsWrapper` with `Trailers | Creators`.
- **Action:** Route the `Creators` tab to a dedicated `CreatorsFeedScreen`.
- **Action:** Route the `Trailers` tab to a dedicated `TrailersDiscoveryScreen`.

### B. Creators Tab (Full TikTok Mode)
- **UI:** A vertical `PageView.builder` exclusively for `creator_videos`.
- **Video Player:** Extract the MP4 logic from `FeedVideoPlayerV2`. Consider migrating from `video_player` to `better_player` for advanced caching, buffering control, and better performance out-of-the-box.
- **Data Source:** Connect to a backend endpoint that exclusively serves `creator_videos` sorted by the machine learning algorithmic ranking.
- **Interactions:** ❤️, 💬, 🔁 buttons on the right side.
- **Performance:** Ensure preloading of the next video and disposal of previous controllers to keep memory usage low (Max 2 active controllers).

### C. Trailers Tab (Discovery Mode)
- **UI (Discovery):** Implement a `GridView.builder` showing poster thumbnails in a scrollable, categorized layout (Trending, New, Popular).
- **Navigation Intent:** Tapping a poster pushes a new `TrailerDetailScreen`.
- **UI (Detail Screen):** 
  - Top: Landscape YouTube Player (`youtube_player_flutter`).
  - Middle: 👍 👎 💬 Share & Description.
  - Bottom: Comments List.
- **Data Source:** Connect to a backend endpoint that exclusively serves TMDB metadata and YouTube keys.
- **Compliance:** Remove YouTube videos from the vertical infinite scroll to respect YouTube API policies (no caching, no background manipulation).

### D. Backend Adjustments
- **Endpoints:** Ensure APIs cleanly separate `Creators` feed (algorithmic ranking of MP4s) and `Trailers` feed (TMDB trending/popular endpoints).
- **Recommendation Engine:** The ML service should focus its feed generation algorithm purely on `creator_videos` for the Creators tab.

---

## 3. Recommended Next Steps (Implementation Order)
1. **Refactor Navigation:** Update `feed_tabs_wrapper.dart` to support the new `Trailers | Creators` structure.
2. **Build Trailers Discovery UI:** Create `trailers_discovery_screen.dart` (Grid) and `trailer_detail_screen.dart` (YouTube Player).
3. **Build Creators Feed UI:** Create `creators_feed_screen.dart` (Vertical PageView) and a dedicated `CreatorVideoPlayer` widget.
4. **Backend Feed Integration:** Update the API client calls to fetch the correctly segregated data streams.
5. **Cleanup:** Remove the unified `FeedVideoPlayerV2` and `HomeScreenV2` if no longer needed, reducing code complexity.
