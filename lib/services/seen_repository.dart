import 'package:finishd/db/objectbox/objectbox_store.dart';
import 'package:finishd/db/objectbox/feed_entities.dart';
import 'package:finishd/objectbox.g.dart';

/// Repository for managing seen video items.
///
/// Provides fast local lookups via ObjectBox for feed deduplication.
/// Works offline and syncs to Firestore in the background.
class SeenRepository {
  static SeenRepository? _instance;
  late final Box<SeenItem> _box;

  /// Pending items to sync to Firestore
  final Set<String> _pendingSync = {};

  SeenRepository._internal() {
    _box = ObjectBoxStore.instance.store.box<SeenItem>();
  }

  /// Get singleton instance
  static SeenRepository get instance {
    _instance ??= SeenRepository._internal();
    return _instance!;
  }

  // ===========================================================================
  // Core Operations
  // ===========================================================================

  /// Mark a video as seen (instant local insert + queue for sync)
  Future<void> markSeen(String videoId, {int viewDurationMs = 0}) async {
    final now = DateTime.now();

    // Check if already exists
    final query = _box.query(SeenItem_.itemId.equals(videoId)).build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      // Update existing
      existing.lastSeenAt = now;
      existing.viewDurationMs += viewDurationMs;
      _box.put(existing);
    } else {
      // Create new
      final item = SeenItem(
        itemId: videoId,
        seenAt: now,
        lastSeenAt: now,
        viewDurationMs: viewDurationMs,
      );
      _box.put(item);
    }

    // Add to pending sync queue
    _pendingSync.add(videoId);

    print(
      '[SeenRepo] Marked seen: $videoId (pending sync: ${_pendingSync.length})',
    );
  }

  /// Get all seen video IDs (for filtering)
  Set<String> getSeenIds() {
    final items = _box.getAll();
    return items.map((item) => item.itemId).toSet();
  }

  /// Check if a specific video has been seen
  bool isSeen(String videoId) {
    final query = _box.query(SeenItem_.itemId.equals(videoId)).build();
    final count = query.count();
    query.close();
    return count > 0;
  }

  /// Get count of seen items
  int get seenCount => _box.count();

  /// Check if local database is empty (for initial sync)
  bool get isEmpty => _box.count() == 0;

  /// Get pending sync items
  Set<String> get pendingSync => Set.from(_pendingSync);

  /// Clear pending sync (after successful Firestore upload)
  void clearPendingSync() {
    _pendingSync.clear();
  }

  // ===========================================================================
  // Suppress / Like Operations
  // ===========================================================================

  /// Suppress a video (never show again)
  Future<void> suppress(String videoId) async {
    final query = _box.query(SeenItem_.itemId.equals(videoId)).build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      existing.suppressed = true;
      _box.put(existing);
    } else {
      final item = SeenItem(
        itemId: videoId,
        seenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        suppressed: true,
      );
      _box.put(item);
    }

    _pendingSync.add(videoId);
  }

  /// Like a video
  Future<void> like(String videoId) async {
    final query = _box.query(SeenItem_.itemId.equals(videoId)).build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      existing.liked = true;
      _box.put(existing);
    } else {
      final item = SeenItem(
        itemId: videoId,
        seenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        liked: true,
      );
      _box.put(item);
    }

    _pendingSync.add(videoId);
  }

  /// Get suppressed video IDs (to always filter)
  Set<String> getSuppressedIds() {
    final query = _box.query(SeenItem_.suppressed.equals(true)).build();
    final items = query.find();
    query.close();
    return items.map((item) => item.itemId).toSet();
  }

  // ===========================================================================
  // Bulk Operations (for Firestore sync)
  // ===========================================================================

  /// Add multiple seen items from Firestore (for initial sync)
  Future<void> addFromFirestore(List<Map<String, dynamic>> items) async {
    for (final data in items) {
      final videoId = data['videoId'] as String?;
      if (videoId == null) continue;

      // Skip if already exists locally
      if (isSeen(videoId)) continue;

      final item = SeenItem(
        itemId: videoId,
        seenAt: (data['seenAt'] as DateTime?) ?? DateTime.now(),
        lastSeenAt: (data['lastSeenAt'] as DateTime?) ?? DateTime.now(),
        viewDurationMs: data['viewDurationMs'] as int? ?? 0,
        liked: data['liked'] as bool? ?? false,
        suppressed: data['suppressed'] as bool? ?? false,
      );
      _box.put(item);
    }

    print('[SeenRepo] Imported ${items.length} items from Firestore');
  }

  /// Get items to upload to Firestore
  List<Map<String, dynamic>> getItemsForSync(Set<String> videoIds) {
    final result = <Map<String, dynamic>>[];

    for (final videoId in videoIds) {
      final query = _box.query(SeenItem_.itemId.equals(videoId)).build();
      final item = query.findFirst();
      query.close();
      if (item != null) {
        result.add({
          'videoId': item.itemId,
          'seenAt': item.seenAt,
          'lastSeenAt': item.lastSeenAt,
          'viewDurationMs': item.viewDurationMs,
          'liked': item.liked,
          'suppressed': item.suppressed,
        });
      }
    }

    return result;
  }
}
