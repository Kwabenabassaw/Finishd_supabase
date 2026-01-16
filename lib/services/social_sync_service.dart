import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import './user_service.dart';
import './social_database_helper.dart';
import '../models/friend_activity.dart';
import '../Model/movie_list_item.dart';

class SocialSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  final SocialDatabaseHelper _dbHelper = SocialDatabaseHelper();

  // StreamController for notifying UI of updates for specific items
  final _itemUpdateController = StreamController<String>.broadcast();
  Stream<String> get onItemUpdated => _itemUpdateController.stream;

  bool _isSyncing = false;

  /// Starts the synchronization process
  Future<void> startSync() async {
    if (_isSyncing) {
      debugPrint('SocialSyncService: Sync already in progress, skipping.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('SocialSyncService: No user logged in, cannot start sync.');
      return;
    }

    _isSyncing = true;
    debugPrint('SocialSyncService: Starting social sync for user $uid');

    try {
      // 1. Get following list with cache
      final followingUids = await _userService.getFollowingCached(uid);
      if (followingUids.isEmpty) {
        debugPrint(
          'SocialSyncService: user $uid is not following anyone. Nothing to sync.',
        );
        _isSyncing = false;
        return;
      }

      // Limit to 50 for performance
      final limitedUids = followingUids.take(50).toList();

      // 2. Fetch friend details with cache
      final friends = await _userService.getUsersCached(limitedUids);
      final Map<String, dynamic> friendMap = {
        for (var f in friends)
          f.uid: {'name': f.username, 'avatar': f.profileImage},
      };

      // 3. Batch fetch activities
      for (var friendUid in limitedUids) {
        _syncFriend(friendUid, friendMap[friendUid]);
      }
      debugPrint(
        'SocialSyncService: Listeners established for ${limitedUids.length} friends.',
      );
    } catch (e) {
      _isSyncing = false;
      debugPrint('Error starting social sync: $e');
    }
  }

  void _syncFriend(String friendUid, Map<String, dynamic>? details) async {
    final lists = ['watching', 'finished', 'favorites'];
    final name = details?['name'] ?? 'Friend';
    final avatar = details?['avatar'] ?? '';

    for (var listName in lists) {
      // Use snapshots for real-time reactivity
      _firestore
          .collection('users')
          .doc(friendUid)
          .collection(listName)
          .snapshots()
          .listen((snapshot) async {
            final List<FriendActivity> activities = [];
            final updatedItemIds = <String>{};

            for (var doc in snapshot.docs) {
              final item = MovieListItem.fromDocument(doc);
              final activity = FriendActivity(
                itemId: item.id,
                friendUid: friendUid,
                friendName: name,
                avatarUrl: avatar,
                status: _getStatusFromList(listName, item),
                timestamp: DateTime.now().millisecondsSinceEpoch,
              );
              activities.add(activity);
              updatedItemIds.add(item.id);
            }

            if (activities.isNotEmpty) {
              await _dbHelper.batchInsertActivities(activities);
              for (var id in updatedItemIds) {
                _itemUpdateController.add(id);
              }
            }
          });
    }
  }

  String _getStatusFromList(String listName, MovieListItem item) {
    if (listName == 'watching') return 'watching';
    if (listName == 'finished') return 'finished';
    if (listName == 'favorites') return 'liked';
    return 'active';
  }

  /// Provides a stream of activities for a specific item from SQLite
  Stream<List<FriendActivity>> getActivitiesStream(String itemId) async* {
    // Initial fetch
    yield await _dbHelper.getActivitiesForItem(itemId);

    // Listen for updates related to this itemId
    await for (final updatedId in onItemUpdated) {
      if (updatedId == itemId) {
        yield await _dbHelper.getActivitiesForItem(itemId);
      }
    }
  }
}
