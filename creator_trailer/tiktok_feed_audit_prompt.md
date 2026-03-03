# 🎯 TikTok-Style Feed — Audit, Refactor & Full Implementation Prompt
**Role:** You are a Senior Flutter Engineer who previously worked on TikTok's Core Feed Infrastructure team (responsible for the scroll engine, video preloader, and memory subsystem that serves 1B+ daily active users). You are now auditing and upgrading an existing Flutter + Supabase feed implementation.

**Your mission:** Do NOT start coding immediately. Follow the exact phase sequence below. Each phase gates the next. Skipping phases will cause bugs. Read this entire prompt before writing a single line of code.

---

## 📋 PHASE 0 — READ BEFORE ANYTHING ELSE

Internalize these non-negotiables before touching code:

1. **Only one video plays at a time.** Ever. No exceptions.
2. **Memory ceiling is 3 active player instances** (current, previous, next). All others must be disposed.
3. **Scroll must feel like butter.** 60fps on mid-range Android (Snapdragon 665), 120fps on ProMotion iOS. No jank.
4. **Preloading is silent and ahead of the user.** Buffer 2 videos ahead, 1 behind.
5. **No network call blocks the scroll.** Pagination is triggered 3 videos before the end, never at the end.
6. **Supabase is the source of truth. Local cache is the speed layer.** Never show stale UI state (likes, views) from cache longer than 30 seconds.
7. **Every controller, listener, stream, and timer MUST be disposed.** Memory leaks are bugs, not warnings.
8. **Test on a real device, not just the emulator.** Android emulator lies about frame performance.

---

## 🔍 PHASE 1 — AUDIT THE EXISTING IMPLEMENTATION

Before writing any new code, examine the existing codebase thoroughly. For each file you open, produce an audit report in this exact format:

```
FILE: [path/to/file.dart]
PURPOSE: [what this file is supposed to do]
ISSUES FOUND:
  - [CRITICAL] Description of critical bug or memory leak
  - [PERFORMANCE] Description of performance problem  
  - [ARCHITECTURE] Description of architectural issue
  - [MINOR] Small issue
VERDICT: KEEP / REFACTOR / REPLACE
```

### Audit Checklist — Check EVERY item:

**Scroll Mechanics**
- [ ] What widget controls vertical scrolling? (PageView, ListView, CustomScrollView, other?)
- [ ] Is `PageView.builder` used with `itemCount`? If not, why?
- [ ] Is `PageController` being properly created and disposed?
- [ ] Is scroll physics set to `NeverScrollableScrollPhysics` on child items to prevent nested scroll conflicts?
- [ ] Are page-change callbacks debounced? Rapid swipes must not trigger multiple video plays.
- [ ] Is `addPostFrameCallback` used to defer heavy work off the build cycle?

**Video Player Management**
- [ ] How many `VideoPlayerController` instances exist at peak? Count them.
- [ ] Is there a controller pool or are controllers created per-widget? Per-widget = memory bomb.
- [ ] Is `controller.dispose()` called in `State.dispose()`? Check every StatefulWidget.
- [ ] Is `controller.initialize()` awaited properly with error handling?
- [ ] Are `VideoPlayerController.networkUrl` vs `VideoPlayerController.asset` used correctly?
- [ ] Is `controller.setLooping(true)` set for feed videos?
- [ ] Is `controller.play()` called only after `controller.value.isInitialized`?
- [ ] Are there any `setState` calls inside async gaps that could hit disposed widgets?

**Memory Management**
- [ ] Is there a sliding window of active controllers (max 3)?
- [ ] Are controllers outside the window disposed immediately on page change?
- [ ] Are `ImageCache` limits set? Default Flutter cache is unlimited. Thumbnails will OOM.
- [ ] Is `PaintingBinding.instance.imageCache.maximumSizeBytes` configured?
- [ ] Are any `StreamSubscription`s stored and cancelled in `dispose()`?
- [ ] Are `AnimationController`s disposed?
- [ ] Is `WidgetsBindingObserver` removed in `dispose()` if used for app lifecycle?

**Preloading**
- [ ] Is there any preloading logic at all?
- [ ] Is preloading triggered proactively (N videos ahead) or reactively (on scroll)?
- [ ] Is preload priority managed? (current > next > next+1 > prefetch thumbnails)
- [ ] Does preloading pause when the app goes to background?

**Caching**
- [ ] Is there a local disk cache for feed JSON responses?
- [ ] Is `cached_network_image` or equivalent used for thumbnails?
- [ ] Is video URL caching handled? (HLS manifests should be cached)
- [ ] Is there a cache invalidation strategy?
- [ ] Is Hive, SharedPreferences, or SQLite used for offline feed data?

**Supabase Integration**
- [ ] Is the Supabase client initialized once as a singleton?
- [ ] Are feed queries paginated with cursor-based pagination? (Offset pagination breaks feeds)
- [ ] Is Realtime used for like/comment count updates? Is the subscription cleaned up?
- [ ] Are API errors handled with retry logic and user-facing fallbacks?
- [ ] Are Supabase Storage URLs using the CDN endpoint, not the raw storage endpoint?
- [ ] Is auth token refresh handled automatically?

**Performance**
- [ ] Are `RepaintBoundary` widgets wrapping heavy subtrees (video overlay UI)?
- [ ] Is `const` used everywhere possible?
- [ ] Are expensive computations done off the main isolate?
- [ ] Is `AutomaticKeepAliveClientMixin` used correctly — or abused (causes memory leaks)?
- [ ] Are list item widgets stateless where possible?
- [ ] Is `wantKeepAlive` set to false for off-screen items?

**Platform-Specific**
- [ ] Is `VideoPlayerOptions(mixWithOthers: false)` set on iOS to respect audio session?
- [ ] Is `AVAudioSession` category set to `playback` on iOS?
- [ ] Is Android hardware acceleration enabled in `AndroidManifest.xml`?
- [ ] Is `android:hardwareAccelerated="true"` on the Activity?
- [ ] Is `io.flutter.embedding.android.SplashScreenDrawable` removed (causes black frame flicker)?

---

## 🏗️ PHASE 2 — DESIGN THE TARGET ARCHITECTURE

After completing the audit, design the new/refactored architecture. Document your design decisions before implementing.

### 2.1 — State Management Decision

Use **Riverpod** (preferred) or **BLoC** for the feed. Do NOT use `setState` for feed state — it causes unnecessary rebuilds of the entire feed. Justify your choice in a comment at the top of your state file.

### 2.2 — Component Map

Implement exactly these components (refactoring existing ones where the audit verdict is KEEP or REFACTOR):

```
FeedPage
  └── PageView.builder (vertical, physics: CustomPageScrollPhysics)
        └── FeedItem (index: n)
              ├── VideoPlayerWidget       ← plays video
              ├── ThumbnailPlaceholder    ← shown before video is ready
              └── OverlayUI              ← likes, comments, user info
                    ├── RepaintBoundary
                    └── [All overlay widgets are const where possible]

FeedController (StateNotifier / Cubit)
  ├── feedItems: List<FeedItem>
  ├── currentIndex: int
  ├── isLoading: bool
  └── error: FeedError?

VideoControllerPool
  ├── _controllers: Map<int, VideoPlayerController>  ← keyed by feed index
  ├── getController(index) → VideoPlayerController
  ├── disposeOutOfWindow(currentIndex)
  └── preload(indices: List<int>)

FeedRepository
  ├── getFeed(cursor, limit) → Future<FeedPage>
  └── prefetchThumbnails(urls: List<String>)

CacheManager
  ├── feedCache: HiveBox<FeedItemDto>
  ├── imageCache: CachedNetworkImageProvider
  └── invalidateIfStale(key, maxAge)
```

### 2.3 — Scroll Physics

Implement `CustomPageScrollPhysics` to replicate TikTok's feel exactly:

```dart
class TikTokScrollPhysics extends PageScrollPhysics {
  const TikTokScrollPhysics({super.parent});

  @override
  TikTokScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TikTokScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 80,       // heavier feel = less bounce
    stiffness: 100,
    damping: 1.0,   // critically damped = no overshoot
  );
}
```

### 2.4 — Memory Window Strategy

```
WINDOW RULE:
  Active controllers = [currentIndex - 1, currentIndex, currentIndex + 1]
  Preload queue     = [currentIndex + 2, currentIndex + 3]
  Dispose all controllers with index < currentIndex - 1 or > currentIndex + 3

ON PAGE CHANGE (index → newIndex):
  1. Pause controller at index
  2. Play controller at newIndex  
  3. Dispose controller at (newIndex - 2) if it exists
  4. Start preloading controller at (newIndex + 2)
  5. Trigger pagination if newIndex >= feedItems.length - 3
```

---

## 💻 PHASE 3 — FULL IMPLEMENTATION

Implement the following in order. Do NOT skip any step.

### Step 1 — Supabase Backend

#### 1a. Database Schema
```sql
-- Run in Supabase SQL Editor

create table if not exists videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  video_url text not null,
  thumbnail_url text not null,
  duration_seconds int not null,
  width int not null default 1080,
  height int not null default 1920,
  like_count bigint default 0,
  comment_count bigint default 0,
  share_count bigint default 0,
  view_count bigint default 0,
  description text,
  tags text[] default '{}',
  is_active boolean default true,
  created_at timestamptz default now()
);

-- Engagement score index for fast feed ranking
create index if not exists idx_videos_feed 
on videos (is_active, created_at desc, like_count desc)
where is_active = true;

-- Seen videos tracking per session (prevents duplicates)
create table if not exists feed_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  seen_video_ids uuid[] default '{}',
  last_cursor uuid,
  updated_at timestamptz default now()
);

-- Enable RLS
alter table videos enable row level security;
alter table feed_sessions enable row level security;

create policy "Anyone can view active videos" 
  on videos for select using (is_active = true);

create policy "Users manage own sessions" 
  on feed_sessions for all using (auth.uid() = user_id);

-- Atomic like increment (prevents race conditions)
create or replace function increment_likes(video_id uuid)
returns void as $$
  update videos set like_count = like_count + 1 where id = video_id;
$$ language sql;

-- Atomic view increment
create or replace function increment_views(video_id uuid)
returns void as $$
  update videos set view_count = view_count + 1 where id = video_id;
$$ language sql;

-- Feed ranking function
create or replace function get_ranked_feed(
  p_session_id uuid,
  p_limit int default 10,
  p_cursor_created_at timestamptz default null
) returns table (
  id uuid, user_id uuid, video_url text, thumbnail_url text,
  duration_seconds int, like_count bigint, comment_count bigint,
  view_count bigint, description text, tags text[], created_at timestamptz
) as $$
declare
  v_seen_ids uuid[] := '{}';
begin
  if p_session_id is not null then
    select coalesce(seen_video_ids, '{}') into v_seen_ids
    from feed_sessions where id = p_session_id;
  end if;

  return query
  select 
    v.id, v.user_id, v.video_url, v.thumbnail_url,
    v.duration_seconds, v.like_count, v.comment_count,
    v.view_count, v.description, v.tags, v.created_at
  from videos v
  where v.is_active = true
    and not (v.id = any(v_seen_ids))
    and (p_cursor_created_at is null or v.created_at < p_cursor_created_at)
  order by 
    (v.like_count * 0.4 + v.view_count * 0.3 + v.comment_count * 0.3) desc,
    v.created_at desc
  limit p_limit;
end;
$$ language plpgsql stable;
```

#### 1b. Storage Setup
```
Bucket: "videos"      → Public, CDN enabled, max file size 100MB
Bucket: "thumbnails"  → Public, CDN enabled, max file size 2MB

Storage policy (videos bucket):
  SELECT: true (public)
  INSERT: auth.role() = 'authenticated'
```

---

### Step 2 — Flutter pubspec.yaml

```yaml
name: your_app
description: TikTok-style feed

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.16.0'

dependencies:
  flutter:
    sdk: flutter
  
  # Supabase
  supabase_flutter: ^2.3.0
  
  # Video
  video_player: ^2.8.3
  
  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  
  # Caching
  cached_network_image: ^3.3.1
  flutter_cache_manager: ^3.3.1
  hive_flutter: ^1.1.0
  
  # Utils
  connectivity_plus: ^6.0.2
  path_provider: ^2.1.2
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  uuid: ^4.3.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.8
  freezed: ^2.4.7
  json_serializable: ^6.7.1
  riverpod_generator: ^2.3.11
```

---

### Step 3 — Models

```dart
// lib/data/models/feed_item.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_item.freezed.dart';
part 'feed_item.g.dart';

@freezed
class FeedItem with _$FeedItem {
  const factory FeedItem({
    required String id,
    required String userId,
    required String videoUrl,
    required String thumbnailUrl,
    required int durationSeconds,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @Default(0) int viewCount,
    String? description,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    // Local state — NOT stored in Supabase
    @Default(false) bool isLiked,
  }) = _FeedItem;

  factory FeedItem.fromJson(Map<String, dynamic> json) =>
      _$FeedItemFromJson(json);
}
```

---

### Step 4 — Supabase Data Source

```dart
// lib/data/datasources/supabase_feed_datasource.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed_item.dart';

class SupabaseFeedDataSource {
  SupabaseFeedDataSource(this._client);
  final SupabaseClient _client;

  String? _sessionId;

  /// Initialize or restore a feed session
  Future<void> initSession() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final existing = await _client
        .from('feed_sessions')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      _sessionId = existing['id'] as String;
    } else {
      final created = await _client
          .from('feed_sessions')
          .insert({'user_id': userId})
          .select('id')
          .single();
      _sessionId = created['id'] as String;
    }
  }

  /// Cursor-based feed fetch. Never use offset pagination.
  Future<List<FeedItem>> getFeed({
    int limit = 10,
    DateTime? cursorCreatedAt,
  }) async {
    final response = await _client.rpc('get_ranked_feed', params: {
      'p_session_id': _sessionId,
      'p_limit': limit,
      'p_cursor_created_at': cursorCreatedAt?.toIso8601String(),
    });

    // Mark as seen
    if (response.isNotEmpty && _sessionId != null) {
      final newIds = (response as List).map((v) => v['id']).toList();
      await _client.rpc('append_seen_videos', params: {
        'p_session_id': _sessionId,
        'p_new_ids': newIds,
      });
    }

    return (response as List)
        .map((json) => FeedItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> recordView(String videoId) async {
    await _client.rpc('increment_views', params: {'video_id': videoId});
  }

  Future<void> toggleLike(String videoId, bool isLiked) async {
    await _client.rpc(
      isLiked ? 'increment_likes' : 'decrement_likes',
      params: {'video_id': videoId},
    );
  }

  /// Realtime subscription for live like counts on current video
  RealtimeChannel subscribeLiveStats(
    String videoId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    return _client
        .channel('video-stats-$videoId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'videos',
          filter: PostgresChangeFilter(
            type: FilterType.eq,
            column: 'id',
            value: videoId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }
}
```

---

### Step 5 — Video Controller Pool (CRITICAL — The Heart of Memory Management)

```dart
// lib/core/video_controller_pool.dart
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Manages a sliding window of VideoPlayerControllers.
/// At any time, maximum [windowSize] controllers are alive.
/// All others are disposed immediately and removed from memory.
class VideoControllerPool {
  VideoControllerPool({this.windowSize = 5, this.preloadAhead = 2});

  final int windowSize;
  final int preloadAhead;

  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<void>> _initFutures = {};
  final Set<int> _disposing = {};

  List<String> _videoUrls = [];
  int _currentIndex = 0;

  void setUrls(List<String> urls) {
    _videoUrls = urls;
  }

  /// Called every time the user lands on a new feed item
  Future<void> onPageChanged(int newIndex) async {
    _currentIndex = newIndex;

    // 1. Play current
    await _ensureInitialized(newIndex);
    _playOnly(newIndex);

    // 2. Preload ahead
    for (int i = 1; i <= preloadAhead; i++) {
      final preloadIndex = newIndex + i;
      if (preloadIndex < _videoUrls.length) {
        _ensureInitialized(preloadIndex); // fire and forget
      }
    }

    // 3. Dispose out-of-window controllers
    final keepIndices = Set<int>.from(
      List.generate(windowSize, (i) => newIndex - 1 + i)
    );

    final toDispose = _controllers.keys
        .where((i) => !keepIndices.contains(i))
        .toList();

    for (final index in toDispose) {
      _disposeController(index);
    }
  }

  Future<VideoPlayerController> _ensureInitialized(int index) async {
    if (_controllers.containsKey(index)) {
      await _initFutures[index];
      return _controllers[index]!;
    }

    if (index >= _videoUrls.length) {
      throw RangeError('Index $index out of range');
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_videoUrls[index]),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,    // iOS: take over audio session
        allowBackgroundPlayback: false,
      ),
    );

    _controllers[index] = controller;

    final future = controller.initialize().then((_) {
      controller.setLooping(true);
      controller.setVolume(1.0);
    }).catchError((error) {
      debugPrint('[VideoPool] Failed to initialize index $index: $error');
      _controllers.remove(index);
      _initFutures.remove(index);
    });

    _initFutures[index] = future;
    await future;
    return controller;
  }

  void _playOnly(int index) {
    // Pause all other controllers first
    for (final entry in _controllers.entries) {
      if (entry.key != index) {
        entry.value.pause();
      }
    }
    // Play current
    _controllers[index]?.play();
  }

  void _disposeController(int index) {
    if (_disposing.contains(index)) return;
    _disposing.add(index);

    final controller = _controllers.remove(index);
    _initFutures.remove(index);

    controller?.pause().then((_) => controller.dispose()).then((_) {
      _disposing.remove(index);
    }).catchError((e) {
      debugPrint('[VideoPool] Dispose error at $index: $e');
      _disposing.remove(index);
    });
  }

  VideoPlayerController? getController(int index) => _controllers[index];

  bool isReady(int index) =>
      _controllers[index]?.value.isInitialized ?? false;

  /// Call when feed loads more items
  void appendUrls(List<String> newUrls) {
    _videoUrls.addAll(newUrls);
    // Preload next batch
    for (int i = 1; i <= preloadAhead; i++) {
      final preloadIndex = _currentIndex + i;
      if (preloadIndex < _videoUrls.length) {
        _ensureInitialized(preloadIndex);
      }
    }
  }

  /// Call when app goes to background
  void pauseAll() {
    for (final controller in _controllers.values) {
      controller.pause();
    }
  }

  /// Call when app returns to foreground
  void resumeCurrent() {
    _controllers[_currentIndex]?.play();
  }

  /// Full teardown
  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.pause();
      controller.dispose();
    }
    _controllers.clear();
    _initFutures.clear();
    _disposing.clear();
  }
}
```

---

### Step 6 — Cache Manager

```dart
// lib/core/cache/feed_cache_manager.dart
import 'package:flutter/painting.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/feed_item.dart';

class FeedCacheManager {
  static const _boxName = 'feed_cache';
  static const _maxAge = Duration(minutes: 30);
  static const _maxEntries = 100;

  late Box<String> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _configureImageCache();
  }

  void _configureImageCache() {
    // CRITICAL: Flutter's default image cache is unlimited.
    // Set explicit limits to prevent OOM on low-end Android devices.
    PaintingBinding.instance.imageCache.maximumSize = 50;        // max 50 images
    PaintingBinding.instance.imageCache.maximumSizeBytes = 
        50 * 1024 * 1024; // max 50MB
  }

  Future<void> cacheFeed(String key, List<FeedItem> items) async {
    final json = items.map((i) => i.toJson().toString()).join('||');
    await _box.put('${key}_data', json);
    await _box.put('${key}_ts', DateTime.now().millisecondsSinceEpoch.toString());

    // Enforce max entries
    if (_box.length > _maxEntries * 2) {
      final keysToDelete = _box.keys.take(_box.length - _maxEntries * 2).toList();
      await _box.deleteAll(keysToDelete);
    }
  }

  List<FeedItem>? getCachedFeed(String key) {
    final tsStr = _box.get('${key}_ts');
    if (tsStr == null) return null;

    final ts = DateTime.fromMillisecondsSinceEpoch(int.parse(tsStr));
    if (DateTime.now().difference(ts) > _maxAge) {
      _box.delete('${key}_data');
      _box.delete('${key}_ts');
      return null;
    }

    // Return cached data (implement proper JSON deserialization here)
    return null; // placeholder: implement with proper JSON parsing
  }

  Future<void> clearAll() async {
    await _box.clear();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
```

---

### Step 7 — Feed Controller (State Management)

```dart
// lib/presentation/feed/feed_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/feed_item.dart';
import '../../data/repositories/feed_repository.dart';
import '../../core/video_controller_pool.dart';

enum FeedStatus { initial, loading, loaded, loadingMore, error }

class FeedState {
  const FeedState({
    this.items = const [],
    this.status = FeedStatus.initial,
    this.currentIndex = 0,
    this.hasMore = true,
    this.error,
  });

  final List<FeedItem> items;
  final FeedStatus status;
  final int currentIndex;
  final bool hasMore;
  final String? error;

  FeedState copyWith({
    List<FeedItem>? items,
    FeedStatus? status,
    int? currentIndex,
    bool? hasMore,
    String? error,
  }) => FeedState(
    items: items ?? this.items,
    status: status ?? this.status,
    currentIndex: currentIndex ?? this.currentIndex,
    hasMore: hasMore ?? this.hasMore,
    error: error ?? this.error,
  );
}

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._repository, this._pool) : super(const FeedState()) {
    loadInitial();
  }

  final FeedRepository _repository;
  final VideoControllerPool _pool;
  bool _isPaginating = false;

  Future<void> loadInitial() async {
    state = state.copyWith(status: FeedStatus.loading);
    try {
      final items = await _repository.getFeed();
      _pool.setUrls(items.map((i) => i.videoUrl).toList());
      state = state.copyWith(items: items, status: FeedStatus.loaded);
      // Start playing first video
      await _pool.onPageChanged(0);
    } catch (e) {
      state = state.copyWith(
        status: FeedStatus.error,
        error: 'Failed to load feed. Pull to refresh.',
      );
    }
  }

  Future<void> onPageChanged(int index) async {
    state = state.copyWith(currentIndex: index);
    await _pool.onPageChanged(index);

    // Record view
    _repository.recordView(state.items[index].id);

    // Paginate when 3 items from end
    if (!_isPaginating && state.hasMore) {
      final distanceFromEnd = state.items.length - 1 - index;
      if (distanceFromEnd <= 3) {
        await _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isPaginating || !state.hasMore) return;
    _isPaginating = true;
    state = state.copyWith(status: FeedStatus.loadingMore);

    try {
      final lastItem = state.items.last;
      final newItems = await _repository.getFeed(
        cursorCreatedAt: lastItem.createdAt,
      );

      if (newItems.isEmpty) {
        state = state.copyWith(hasMore: false, status: FeedStatus.loaded);
      } else {
        final combined = [...state.items, ...newItems];
        _pool.appendUrls(newItems.map((i) => i.videoUrl).toList());
        state = state.copyWith(items: combined, status: FeedStatus.loaded);
      }
    } catch (e) {
      state = state.copyWith(status: FeedStatus.loaded); // silent fail, keep scroll
    } finally {
      _isPaginating = false;
    }
  }

  Future<void> toggleLike(String videoId) async {
    final index = state.items.indexWhere((i) => i.id == videoId);
    if (index == -1) return;

    final item = state.items[index];
    final newLiked = !item.isLiked;
    final delta = newLiked ? 1 : -1;

    // Optimistic update
    final updated = List<FeedItem>.from(state.items)
      ..[index] = item.copyWith(
        isLiked: newLiked,
        likeCount: item.likeCount + delta,
      );
    state = state.copyWith(items: updated);

    try {
      await _repository.toggleLike(videoId, newLiked);
    } catch (_) {
      // Rollback on failure
      final rolledBack = List<FeedItem>.from(state.items)
        ..[index] = item;
      state = state.copyWith(items: rolledBack);
    }
  }

  void onAppBackground() => _pool.pauseAll();
  void onAppForeground() => _pool.resumeCurrent();

  @override
  void dispose() {
    _pool.disposeAll();
    super.dispose();
  }
}

// Providers
final videoPoolProvider = Provider<VideoControllerPool>((ref) {
  final pool = VideoControllerPool();
  ref.onDispose(pool.disposeAll);
  return pool;
});

final feedControllerProvider =
    StateNotifierProvider<FeedController, FeedState>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  final pool = ref.watch(videoPoolProvider);
  return FeedController(repo, pool);
});
```

---

### Step 8 — Feed Page UI

```dart
// lib/presentation/feed/feed_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feed_controller.dart';
import '../player/video_player_widget.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage>
    with WidgetsBindingObserver {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // CRITICAL: keepPage: false prevents Flutter from keeping all pages alive
    _pageController = PageController(
      keepPage: false,
      viewportFraction: 1.0,
    );

    // Force full-screen, immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(feedControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        controller.onAppBackground();
        break;
      case AppLifecycleState.resumed:
        controller.onAppForeground();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);
    final feedNotifier = ref.read(feedControllerProvider.notifier);

    if (feedState.status == FeedStatus.loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (feedState.status == FeedStatus.error) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(feedState.error ?? 'Error', style: const TextStyle(color: Colors.white)),
              TextButton(
                onPressed: feedNotifier.loadInitial,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const TikTokScrollPhysics(),
        itemCount: feedState.items.length,
        onPageChanged: feedNotifier.onPageChanged,
        itemBuilder: (context, index) {
          final item = feedState.items[index];
          final pool = ref.read(videoPoolProvider);

          return RepaintBoundary(
            key: ValueKey(item.id),
            child: FeedItemWidget(
              item: item,
              pool: pool,
              index: index,
              isActive: index == feedState.currentIndex,
              onLike: () => feedNotifier.toggleLike(item.id),
            ),
          );
        },
      ),
    );
  }
}
```

---

### Step 9 — Video Player Widget

```dart
// lib/presentation/player/video_player_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/video_controller_pool.dart';
import '../../data/models/feed_item.dart';

class FeedItemWidget extends StatefulWidget {
  const FeedItemWidget({
    super.key,
    required this.item,
    required this.pool,
    required this.index,
    required this.isActive,
    required this.onLike,
  });

  final FeedItem item;
  final VideoControllerPool pool;
  final int index;
  final bool isActive;
  final VoidCallback onLike;

  @override
  State<FeedItemWidget> createState() => _FeedItemWidgetState();
}

class _FeedItemWidgetState extends State<FeedItemWidget> {
  VideoPlayerController? _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(FeedItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _attachController();
    }
  }

  void _attachController() {
    final controller = widget.pool.getController(widget.index);
    if (controller != null && controller.value.isInitialized) {
      setState(() {
        _controller = controller;
        _isReady = true;
      });
    } else {
      // Poll until ready (pool is initializing in background)
      _pollForController();
    }
  }

  void _pollForController() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      final controller = widget.pool.getController(widget.index);
      if (controller != null && controller.value.isInitialized) {
        setState(() {
          _controller = controller;
          _isReady = true;
        });
      } else {
        _pollForController(); // keep polling
      }
    });
  }

  @override
  void dispose() {
    // Do NOT dispose the controller here. Pool owns it.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail shown while video loads
        CachedNetworkImage(
          imageUrl: widget.item.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => const ColoredBox(color: Colors.black),
          errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black12),
        ),

        // Video layer
        if (_isReady && _controller != null)
          _VideoLayer(controller: _controller!),

        // Loading indicator
        if (!_isReady)
          const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ),

        // Overlay UI — wrapped in RepaintBoundary so video frames
        // don't trigger overlay repaints
        RepaintBoundary(
          child: _OverlayUI(item: widget.item, onLike: widget.onLike),
        ),
      ],
    );
  }
}

class _VideoLayer extends StatelessWidget {
  const _VideoLayer({required this.controller});
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _OverlayUI extends StatelessWidget {
  const _OverlayUI({required this.item, required this.onLike});
  final FeedItem item;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Like button
          _ActionButton(
            icon: item.isLiked ? Icons.favorite : Icons.favorite_border,
            color: item.isLiked ? Colors.red : Colors.white,
            label: _formatCount(item.likeCount),
            onTap: onLike,
          ),
          const SizedBox(height: 16),
          // Comment button
          _ActionButton(
            icon: Icons.comment_outlined,
            color: Colors.white,
            label: _formatCount(item.commentCount),
            onTap: () {},
          ),
          const SizedBox(height: 16),
          // Share button
          _ActionButton(
            icon: Icons.share_outlined,
            color: Colors.white,
            label: _formatCount(item.shareCount),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class TikTokScrollPhysics extends PageScrollPhysics {
  const TikTokScrollPhysics({super.parent});

  @override
  TikTokScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      TikTokScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 80,
    stiffness: 100,
    damping: 1.0,
  );
}
```

---

### Step 10 — Platform Configuration

**Android — `android/app/src/main/AndroidManifest.xml`**
```xml
<application
  android:hardwareAccelerated="true"   <!-- REQUIRED for smooth video -->
  android:label="your_app"
  android:icon="@mipmap/ic_launcher">
  
  <activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
  </activity>
</application>

<!-- Network permission -->
<uses-permission android:name="android.permission.INTERNET"/>
```

**iOS — `ios/Runner/Info.plist`**
```xml
<!-- Allow HTTP video streams (remove if HTTPS only) -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>

<!-- Background audio (optional but recommended) -->
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

**iOS Audio Session — `ios/Runner/AppDelegate.swift`**
```swift
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Take over audio session for video playback
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .moviePlayback,
        options: []
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Audio session error: \(error)")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

## ✅ PHASE 4 — POST-IMPLEMENTATION VALIDATION CHECKLIST

Run through every item. Do not ship until all are ✅.

**Memory**
- [ ] Open Feed. Scroll 30 items. Check Flutter DevTools > Memory — heap must not grow unboundedly
- [ ] Controller count in pool must never exceed `windowSize` (default 5)
- [ ] Hot-restart and verify no controller leak warnings in console

**Performance**
- [ ] Enable Flutter Performance Overlay (`showPerformanceOverlay: true` in MaterialApp)
- [ ] Scroll through 20 items — both bars must stay green on a mid-range Android device
- [ ] Verify no "Skipped X frames" in Android Logcat
- [ ] Verify no dropped frames in Xcode Instruments on iOS

**Preloading**
- [ ] Disable WiFi, enable 4G. Scroll — next video must start within 500ms
- [ ] Enable airplane mode mid-scroll — graceful error UI must appear, no crash

**Scroll Feel**
- [ ] Swipe up slowly — snap to next video cleanly, no partial-page states
- [ ] Swipe very fast (3 swipes rapidly) — only the final landing video plays
- [ ] Swipe down from first item — no scroll past beginning

**Supabase**
- [ ] Open Network tab in Supabase dashboard — verify cursor-based queries, no offset queries
- [ ] Scroll to end of feed — next page loads automatically, no manual action needed
- [ ] Like a video — optimistic update is instant, Supabase row updates within 1s
- [ ] Kill the app and reopen — feed session is restored, no duplicate videos

**iOS Specific**
- [ ] Play video, then receive a phone call — video pauses
- [ ] Plug in headphones — volume works correctly
- [ ] Video plays in Silent mode (toggle switch) — audio respects silent mode correctly

**Android Specific**
- [ ] Test on Android 8 (API 26), 10 (API 29), 13 (API 33)
- [ ] Screen rotation locked to portrait — verify
- [ ] Back button behavior — exits gracefully, controllers disposed

---

## 🚫 COMMON BUGS — DO NOT INTRODUCE THESE

| Bug | Cause | Fix |
|-----|-------|-----|
| Black screen on video | `play()` called before `initialize()` | Always await `_initFutures[index]` |
| OOM crash after 50 videos | Controllers never disposed | Use pool's `disposeOutOfWindow()` |
| Scroll jank | `setState` in `onPageChanged` triggers full rebuild | Use Riverpod, only rebuild affected widgets |
| Double video audio | Two controllers playing simultaneously | `pauseAll()` before `play()` in pool |
| Feed loops / repeats | Using offset pagination | Use cursor-based pagination only |
| iOS audio session conflict | Missing `AVAudioSession` setup | Set `.playback` category in `AppDelegate` |
| Thumbnail OOM | Unlimited `ImageCache` | Set `maximumSizeBytes` to 50MB |
| Realtime subscription leak | Channel not unsubscribed | Track and remove in `dispose()` |
| Feed not loading on launch | `initSession()` not awaited | `await` session init before first fetch |

---

## 📊 PERFORMANCE TARGETS

| Metric | Target | Measurement |
|--------|--------|-------------|
| Time-to-first-video | < 800ms | From app open to first frame playing |
| Scroll-to-play latency | < 200ms | Time from page snap to video playing |
| Frame rate | 60fps Android / 120fps iOS ProMotion | Flutter Performance Overlay |
| Memory at 50 videos scrolled | < 200MB | Flutter DevTools Memory tab |
| Pagination trigger | index >= count - 3 | No feed gap ever visible |
| Preload window | 2 ahead, 1 behind | VideoControllerPool config |

---

*End of prompt. Implement every phase in sequence. Do not skip the audit phase — the existing implementation will have issues that these steps are specifically designed to catch and correct.*
