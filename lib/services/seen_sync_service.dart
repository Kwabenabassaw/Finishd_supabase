import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/services/seen_repository.dart';

/// Background sync service for seen items between ObjectBox and Firestore.
///
/// - Uploads pending items every 1 hour (or when threshold reached)
/// - Downloads full history on new device/reinstall
class SeenSyncService {
  static SeenSyncService? _instance;
  Timer? _syncTimer;

  /// Sync interval (1 hour as per user request)
  static const Duration syncInterval = Duration(hours: 1);

  /// Batch upload threshold (upload earlier if this many items pending)
  static const int batchThreshold = 50;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SeenRepository _seenRepo = SeenRepository.instance;

  SeenSyncService._internal();

  /// Get singleton instance
  static SeenSyncService get instance {
    _instance ??= SeenSyncService._internal();
    return _instance!;
  }

  // ===========================================================================
  // Periodic Sync
  // ===========================================================================

  /// Start background sync timer
  void startPeriodicSync() {
    // Cancel existing timer if any
    _syncTimer?.cancel();

    // Start new periodic timer
    _syncTimer = Timer.periodic(syncInterval, (_) => _runSync());

    print(
      '[SeenSync] Started periodic sync (every ${syncInterval.inMinutes} min)',
    );
  }

  /// Stop background sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('[SeenSync] Stopped periodic sync');
  }

  /// Run sync (called by timer or manually)
  Future<void> _runSync() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('[SeenSync] Skipping sync - no user logged in');
      return;
    }

    await uploadPending(userId);
  }

  /// Check if should sync early (threshold reached)
  void checkBatchThreshold() {
    final pending = _seenRepo.pendingSync;
    if (pending.length >= batchThreshold) {
      print('[SeenSync] Batch threshold reached, syncing now...');
      _runSync();
    }
  }

  // ===========================================================================
  // Upload to Firestore
  // ===========================================================================

  /// Upload pending seen items to Firestore
  Future<void> uploadPending(String userId) async {
    final pending = _seenRepo.pendingSync;

    if (pending.isEmpty) {
      print('[SeenSync] No pending items to upload');
      return;
    }

    print('[SeenSync] Uploading ${pending.length} items to Firestore...');

    try {
      final items = _seenRepo.getItemsForSync(pending);
      final batch = _firestore.batch();

      final collection = _firestore
          .collection('users')
          .doc(userId)
          .collection('seenVideos');

      for (final item in items) {
        final docRef = collection.doc(item['videoId']);
        batch.set(docRef, {
          'videoId': item['videoId'],
          'seenAt': Timestamp.fromDate(item['seenAt']),
          'lastSeenAt': Timestamp.fromDate(item['lastSeenAt']),
          'viewDurationMs': item['viewDurationMs'],
          'liked': item['liked'],
          'suppressed': item['suppressed'],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      // Clear pending on success
      _seenRepo.clearPendingSync();

      print('[SeenSync] ✅ Uploaded ${items.length} items to Firestore');
    } catch (e) {
      print('[SeenSync] ❌ Upload failed: $e');
    }
  }

  // ===========================================================================
  // Download from Firestore
  // ===========================================================================

  /// Download full history from Firestore (for new device/reinstall)
  Future<void> downloadFullHistory(String userId) async {
    print('[SeenSync] Downloading seen history from Firestore...');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('seenVideos')
          .limit(5000) // Cap at 5000 for performance
          .get();

      if (snapshot.docs.isEmpty) {
        print('[SeenSync] No history found in Firestore');
        return;
      }

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'videoId': data['videoId'] as String?,
          'seenAt': (data['seenAt'] as Timestamp?)?.toDate(),
          'lastSeenAt': (data['lastSeenAt'] as Timestamp?)?.toDate(),
          'viewDurationMs': data['viewDurationMs'] as int?,
          'liked': data['liked'] as bool?,
          'suppressed': data['suppressed'] as bool?,
        };
      }).toList();

      await _seenRepo.addFromFirestore(items);

      print('[SeenSync] ✅ Downloaded ${items.length} items from Firestore');
    } catch (e) {
      print('[SeenSync] ❌ Download failed: $e');
    }
  }

  /// Sync on login (upload pending + download if empty)
  Future<void> syncOnLogin() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // If local is empty, download from Firestore first
    if (_seenRepo.isEmpty) {
      await downloadFullHistory(userId);
    }

    // Upload any pending items
    await uploadPending(userId);

    // Start periodic sync
    startPeriodicSync();
  }
}
