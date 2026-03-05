---
name: building-creator-content-feed
description: Designs and implements a high-performance TikTok-style vertical content feed in Flutter with Supabase backend. Use when building creator video feeds, vertical scroll feeds, short-form video systems, feed ranking, video preloading, or memory-safe video playback.
---

# Creator Content Feed — Staff-Level Engineering Skill

## When to use this skill
- Building a TikTok-style vertical video feed
- Implementing video preloading / caching / memory management
- Designing a feed ranking algorithm with Supabase Edge Functions
- Optimizing scroll performance for 60fps on low-end Android
- Setting up a creator video upload pipeline
- Tracking feed engagement analytics

## Product Context — Finishd
Finishd is a social entertainment platform. The homepage is a vertical swipe feed mixing:
- Creator video reviews (uploaded to Supabase Storage)
- YouTube trailers (embedded player)
- Clips & trending content
- Personalized recommendations

Feed algorithm mix target: **50% trending · 30% personalized · 20% friend activity**.

---

## Section 1 — Feed Architecture

### Core Concepts
| Concept | Description |
|---|---|
| Feed Session | A single user scroll session; new session on cold open or pull-to-refresh |
| Batch | A page of 10–15 items fetched per request |
| Cursor | Opaque token (timestamp + score) for keyset pagination — never use OFFSET |
| Client Queue | A local list of upcoming items the user hasn't seen yet; refill when < 5 remain |
| Server Rank | All scoring happens server-side; client never re-sorts |

### Request Flow
```
Client                         Supabase Edge Function
  │── GET /feed?cursor=X ────▶  │
  │                              ├─ fetch candidates (trending + personalized + friends)
  │                              ├─ score & rank
  │                              ├─ deduplicate
  │                              ├─ mix categories (50/30/20)
  │                              ├─ serialize batch + next_cursor
  │◀── JSON [{item}, …] ──────  │
```

### Infinite Scroll Contract
- Trigger next fetch when client queue drops below **5 items**.
- Show shimmer placeholder only on first load; subsequent batches are invisible.
- On error, retry 2× with exponential backoff, then show inline retry button.

---

## Section 2 — Video Preloading System

### Preload Strategy
- Preload **next 2 videos** ahead of the current viewport.
- Cancel preload immediately when a video is skipped past.
- Maintain a `PreloadQueue` (max size 3) managed by `PreloadManager`.

### Flutter Implementation Pattern
```dart
class PreloadManager {
  final _queue = Queue<String>(); // video URLs
  final _activeLoads = <String, CancelableOperation>{};
  static const maxConcurrent = 2;

  void enqueue(String url) {
    _queue.add(url);
    _processQueue();
  }

  void cancel(String url) {
    _activeLoads[url]?.cancel();
    _activeLoads.remove(url);
    _queue.remove(url);
  }

  void _processQueue() {
    while (_activeLoads.length < maxConcurrent && _queue.isNotEmpty) {
      final url = _queue.removeFirst();
      _activeLoads[url] = CancelableOperation.fromFuture(
        _preloadVideo(url),
      )..value.whenComplete(() => _activeLoads.remove(url));
    }
  }
}
```

### Buffering Thresholds
- Start playback when **first 500 KB** or **2 seconds** of video is buffered.
- Show a lightweight spinner (not full shimmer) while buffering mid-play.

---

## Section 3 — Memory Management (Critical)

> This is the #1 cause of crashes on low-end Android. Over-allocating video controllers will kill the app.

### Hard Limits
| Resource | Max Active |
|---|---|
| VideoPlayerController instances | **3** (current ± 1) |
| Decoded textures in GPU memory | **3** |
| Simultaneous network decoders | **2** |

### Controller Lifecycle
```
 Page enters viewport-1  →  INITIALIZE controller
 Page is current          →  PLAY
 Page leaves viewport     →  PAUSE
 Page is viewport+2 away  →  DISPOSE controller
```

### `VideoControllerManager`
```dart
class VideoControllerManager {
  final _controllers = LinkedHashMap<int, VideoPlayerController>();
  static const maxControllers = 3;

  VideoPlayerController acquire(int index, String url) {
    // Evict oldest if at capacity
    while (_controllers.length >= maxControllers) {
      final oldest = _controllers.keys.first;
      _controllers.remove(oldest)?.dispose();
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[index] = c;
    return c;
  }

  void release(int index) {
    _controllers.remove(index)?.dispose();
  }

  void pauseAll({int? except}) {
    for (final entry in _controllers.entries) {
      if (entry.key != except) entry.value.pause();
    }
  }
}
```

### Low-Memory Response
- Listen to `WidgetsBindingObserver.didHaveMemoryPressure`.
- On trigger: dispose all controllers except current, clear image cache, cancel preloads.

---

## Section 4 — Video Caching Strategy

### Recommended Package
`flutter_cache_manager` with a custom `CacheManager` instance scoped to feed videos.

### Cache Rules
| Rule | Value |
|---|---|
| Max cache size | 200 MB |
| Max file age | 7 days |
| Eviction | LRU — least recently used first |
| Partial cache | Cache first 2 MB for quick replay; full file on second watch |

### When to Reuse Cache
- Same video appears in feed again (dedup by `video_id`).
- User revisits creator profile.
- Offline mode — serve cached videos only, hide uncached items.

---

## Section 5 — Feed Scrolling Performance

### Widget Choice
Use `PageView.builder` with `ScrollPhysics` set to `BouncingScrollPhysics` + snap.

**Do not** use `ListView` or `CustomScrollView` — they don't guarantee one-item-per-viewport snap.

### 60fps Checklist
- [ ] Only the **current page** has `RepaintBoundary`.
- [ ] Overlay text (title, likes) uses `const` widgets.
- [ ] Heavy work (blur, filter) runs on `Isolate`.
- [ ] Precache thumbnail images via `precacheImage()` 2 pages ahead.
- [ ] Debounce `onPageChanged` — fire analytics only after 300ms dwell.
- [ ] Never call `setState` on the feed list widget; use `ValueNotifier` per tile.

---

## Section 6 — Backend Feed Generation (Supabase Edge Function)

### Ranking Pipeline
```
1. FETCH CANDIDATES
   - trending:    SELECT ... ORDER BY trending_score DESC LIMIT 30
   - personalized: SELECT ... WHERE genre IN (user_prefs) ORDER BY score DESC LIMIT 20
   - friends:     SELECT ... WHERE creator_id IN (friend_ids) ORDER BY created_at DESC LIMIT 10

2. SCORE
   score = (0.4 × recency) + (0.3 × engagement_rate) + (0.2 × relevance) + (0.1 × creator_trust)

3. DEDUPLICATE
   Remove items the user has seen (check video_views table).

4. MIX
   Interleave: trending[0], personalized[0], trending[1], personalized[1], friend[0], ...
   Target ratio: 50/30/20.

5. RETURN BATCH
   Serialize top 15 items + next_cursor.
```

### Cold Start (New Users)
- No personalization signals → use **100% trending** for the first 3 sessions.
- After ≥ 10 interactions, blend in personalized content.

### Response Caching
- Cache full feed response per user for **60 seconds** in Supabase Edge Function (in-memory or KV).
- Invalidate on explicit refresh.

---

## Section 7 — Supabase Data Model

```sql
-- Creator profiles (extends auth.users)
CREATE TABLE creator_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  follower_count INT DEFAULT 0,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Videos
CREATE TABLE creator_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id UUID NOT NULL REFERENCES creator_profiles(id),
  storage_path TEXT NOT NULL,        -- Supabase Storage key
  thumbnail_path TEXT,
  title TEXT NOT NULL,
  description TEXT,
  duration_seconds SMALLINT NOT NULL,
  width SMALLINT,
  height SMALLINT,
  tmdb_id INT,                       -- linked movie/show
  status TEXT DEFAULT 'processing',  -- processing | active | removed
  trending_score FLOAT DEFAULT 0,
  engagement_rate FLOAT DEFAULT 0,
  view_count INT DEFAULT 0,
  like_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_cv_trending ON creator_videos(trending_score DESC) WHERE status = 'active';
CREATE INDEX idx_cv_creator ON creator_videos(creator_id, created_at DESC);

-- Views (for dedup + watch time analytics)
CREATE TABLE video_views (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  video_id UUID NOT NULL REFERENCES creator_videos(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  watch_duration_seconds SMALLINT,
  completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_vv_user ON video_views(user_id, video_id);

-- Likes
CREATE TABLE video_likes (
  video_id UUID NOT NULL REFERENCES creator_videos(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (video_id, user_id)
);

-- Comments
CREATE TABLE video_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES creator_videos(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_vc_video ON video_comments(video_id, created_at DESC);
```

### RLS Essentials
- `video_views` INSERT: `auth.uid() = user_id`.
- `creator_videos` SELECT: `status = 'active'`.
- `creator_videos` INSERT/UPDATE: `auth.uid() = creator_id`.

---

## Section 8 — Video Upload Pipeline

### Upload Flow
```
Creator picks video
  → Client: validate (≤ 60s, ≤ 100 MB, vertical aspect)
  → Client: generate thumbnail (first frame)
  → Client: compress to 720p H.264 if > 720p
  → Upload to Supabase Storage bucket `creator-videos/`
  → Insert row in creator_videos (status = 'processing')
  → Edge Function (trigger or cron):
       - verify codec / duration
       - generate poster thumbnail
       - set status = 'active'
```

### Constraints
| Param | Limit |
|---|---|
| Max duration | 60 seconds |
| Max file size | 100 MB |
| Resolution | 720p minimum, 1080p max stored |
| Codec | H.264 / AAC |
| Aspect ratio | 9:16 (vertical) |

---

## Section 9 — Feed Analytics

### Tracked Signals
| Signal | When Recorded |
|---|---|
| `impression` | Video enters viewport (debounce 300ms) |
| `watch_time` | On page leave, record seconds watched |
| `completion` | `watch_time >= 0.9 × duration` |
| `like` | User taps like |
| `share` | User taps share |
| `skip` | `watch_time < 2s` and user swiped away |

### Feedback Loop
- Nightly cron Edge Function recalculates `trending_score` and `engagement_rate` on `creator_videos`.
- Formula: `engagement_rate = (likes + completions × 2 + shares × 3) / impressions`.
- `trending_score` decays by **0.95× per day** to keep feed fresh.

---

## Section 10 — Safety & Edge Cases

| Scenario | Response |
|---|---|
| Network drop mid-play | Pause, show retry chip, resume from byte offset |
| Corrupted video file | Skip item, log error, remove from client queue |
| Playback error (codec) | Show fallback thumbnail + "Can't play" label |
| Fast scroll (< 200ms/page) | Do NOT initialize controllers; only init on dwell > 300ms |
| App backgrounded | Pause all controllers, cancel preloads |
| `didHaveMemoryPressure` | Dispose all except current, flush image cache |
| Empty feed response | Show "Explore trending" CTA linking to browse page |

---

## Section 11 — Flutter Architecture Outline

```
┌─────────────────────────────────────────┐
│              FeedScreen                 │
│  PageView.builder → FeedItemWidget[]    │
└──────────────┬──────────────────────────┘
               │ owns
┌──────────────▼──────────────────────────┐
│           FeedController                │
│  - currentIndex                         │
│  - feedItems (local queue)              │
│  - fetchNextBatch()                     │
│  - reportAnalytics()                    │
└──────────────┬──────────────────────────┘
               │ delegates to
  ┌────────────┼────────────┬─────────────┐
  ▼            ▼            ▼             ▼
FeedRepo   VCManager   PreloadMgr   RankingService
(Supabase) (controllers) (preload)   (Edge Function)
```

### Responsibilities
| Component | Job |
|---|---|
| `FeedController` | Owns feed state, pagination cursor, triggers fetches and analytics |
| `VideoControllerManager` | Creates / disposes / recycles `VideoPlayerController` instances (max 3) |
| `PreloadManager` | Downloads next 2 videos asynchronously, cancels on skip |
| `FeedRepository` | Calls Supabase Edge Function, deserializes response |
| `FeedRankingService` | Server-side only — Edge Function that scores and mixes content |

---

## Section 12 — Common Engineering Mistakes

| Mistake | Why It Kills You | Fix |
|---|---|---|
| Creating a controller per feed item | OOM crash on 20+ items | Use `VideoControllerManager` with max 3 |
| Not disposing controllers | GPU memory leak → ANR | Dispose on viewport+2 exit |
| Loading full video on preload | Bandwidth waste | Preload first 2 MB only |
| Using OFFSET pagination | Slow at page 50+ | Keyset cursor pagination |
| `setState` on feed list | Full list rebuild, jank | `ValueNotifier` per tile |
| Blocking UI with analytics | Frame drops | Fire analytics in `Isolate` or microtask |
| No debounce on fast scroll | Wasted controller init | Only init after 300ms dwell |

---

## Implementation Checklist

- [ ] Supabase tables created (Section 7)
- [ ] Edge Function for feed ranking deployed (Section 6)
- [ ] `FeedRepository` calls Edge Function with cursor
- [ ] `FeedController` manages queue and pagination
- [ ] `VideoControllerManager` limits to 3 active controllers
- [ ] `PreloadManager` preloads next 2 videos
- [ ] Scroll performance validated at 60fps on low-end device
- [ ] Analytics signals tracked (Section 9)
- [ ] Upload pipeline validates and compresses video (Section 8)
- [ ] Edge cases handled (Section 10)
- [ ] Memory pressure listener wired up

## Resources
- [See ADVANCED.md](ADVANCED.md) for extended code examples and benchmark targets.
