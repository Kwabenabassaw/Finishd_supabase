import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/services/seen_repository.dart';

/// Background sync service for seen items between ObjectBox and Supabase.
class SeenSyncService {
  static SeenSyncService? _instance;
  Timer? _syncTimer;

  static const Duration syncInterval = Duration(hours: 1);
  static const int batchThreshold = 50;

  final SupabaseClient _supabase = Supabase.instance.client;
  final SeenRepository _seenRepo = SeenRepository.instance;

  SeenSyncService._internal();

  static SeenSyncService get instance {
    _instance ??= SeenSyncService._internal();
    return _instance!;
  }

  // ===========================================================================
  // Periodic Sync
  // ===========================================================================

  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) => _runSync());
    print(
      '[SeenSync] Started periodic sync (every ${syncInterval.inMinutes} min)',
    );
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('[SeenSync] Stopped periodic sync');
  }

  Future<void> _runSync() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('[SeenSync] Skipping sync - no user logged in');
      return;
    }
    await uploadPending(userId);
  }

  void checkBatchThreshold() {
    final pending = _seenRepo.pendingSync;
    if (pending.length >= batchThreshold) {
      print('[SeenSync] Batch threshold reached, syncing now...');
      _runSync();
    }
  }

  // ===========================================================================
  // Upload to Supabase
  // ===========================================================================

  Future<void> uploadPending(String userId) async {
    final pending = _seenRepo.pendingSync;

    if (pending.isEmpty) {
      print('[SeenSync] No pending items to upload');
      return;
    }

    print('[SeenSync] Uploading ${pending.length} items to Supabase...');

    try {
      final items = _seenRepo.getItemsForSync(pending);

      // Batch upsert in Supabase
      final List<Map<String, dynamic>> upsertData = items.map((item) {
        return {
          'user_id': userId,
          'video_id': item['videoId'],
          'seen_at': (item['seenAt'] as DateTime).toIso8601String(),
          'last_seen_at': (item['lastSeenAt'] as DateTime).toIso8601String(),
          'view_duration_ms': item['viewDurationMs'],
          'liked': item['liked'],
          'suppressed': item['suppressed'],
          'updated_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _supabase.from('seen_history').upsert(upsertData);

      // Clear pending on success
      _seenRepo.clearPendingSync();

      print('[SeenSync] ✅ Uploaded ${items.length} items to Supabase');
    } catch (e) {
      print('[SeenSync] ❌ Upload failed: $e');
    }
  }

  // ===========================================================================
  // Download from Supabase
  // ===========================================================================

  Future<void> downloadFullHistory(String userId) async {
    print('[SeenSync] Downloading seen history from Supabase...');

    try {
      final response = await _supabase
          .from('seen_history')
          .select()
          .eq('user_id', userId)
          .limit(5000); // Cap at 5000 for performance

      if (response.isEmpty) {
        print('[SeenSync] No history found in Supabase');
        return;
      }

      final items = (response as List).map((data) {
        return {
          'videoId': data['video_id'] as String?,
          'seenAt': DateTime.tryParse(data['seen_at'] ?? ''),
          'lastSeenAt': DateTime.tryParse(data['last_seen_at'] ?? ''),
          'viewDurationMs': data['view_duration_ms'] as int?,
          'liked': data['liked'] as bool?,
          'suppressed': data['suppressed'] as bool?,
        };
      }).toList();

      await _seenRepo.addFromFirestore(
        items,
      ); // Re-use method (renaming would be better but keeping signature)

      print('[SeenSync] ✅ Downloaded ${items.length} items from Supabase');
    } catch (e) {
      print('[SeenSync] ❌ Download failed: $e');
    }
  }

  Future<void> syncOnLogin() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // If local is empty, download from Supabase first
    if (_seenRepo.isEmpty) {
      await downloadFullHistory(userId);
    }

    // Upload any pending items
    await uploadPending(userId);

    // Start periodic sync
    startPeriodicSync();
  }
}
