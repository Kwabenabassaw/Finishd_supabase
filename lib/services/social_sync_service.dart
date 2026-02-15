import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import './user_service.dart';
import './social_database_helper.dart';
import '../models/friend_activity.dart';
import '../Model/movie_list_item.dart';

class SocialSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
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

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('SocialSyncService: No user logged in, cannot start sync.');
      return;
    }

    _isSyncing = true;
    debugPrint('SocialSyncService: Starting social sync for user $uid');

    try {
      // 1. Get following list
      final followingUids = await _userService.getFollowingCached(uid);
      if (followingUids.isEmpty) {
        debugPrint('SocialSyncService: user $uid is not following anyone.');
        _isSyncing = false;
        return;
      }

      // Limit to 50
      final limitedUids = followingUids.take(50).toList();

      // 2. Fetch friend details
      final friends = await _userService.getUsersCached(limitedUids);
      final Map<String, dynamic> friendMap = {
        for (var f in friends)
          f.uid: {'name': f.displayName, 'avatar': f.profileImage},
      };

      // 3. Sync all friends via Supabase Realtime channel?
      // Or just periodic fetch for now since Realtime on many users is expensive.
      // Let's do a one-time fetch to populate DB, then maybe subscribe to *own* timeline if implementing feed.
      // For now, mirroring the logic: fetch their lists.

      // Batch fetch from user_titles
      final response = await _supabase
          .from('user_titles')
          .select()
          .filter('user_id', 'in', limitedUids)
          .limit(500); // safety cap

      final List<FriendActivity> activities = [];

      for (final row in response) {
        final friendUid = row['user_id'] as String;
        final details = friendMap[friendUid];
        final name = details?['name'] ?? 'Friend';
        final avatar = details?['avatar'] ?? '';

        final item = MovieListItem.fromSupabase(row);
        final status = row['status'] as String?;
        final isFav = row['is_favorite'] as bool? ?? false;

        String activityStatus = 'active';
        if (status == 'watching')
          activityStatus = 'watching';
        else if (status == 'finished')
          activityStatus = 'finished';
        else if (isFav)
          activityStatus = 'liked';

        if (activityStatus != 'active') {
          // Only sync meaningful activities
          final activity = FriendActivity(
            itemId: item.id,
            friendUid: friendUid,
            friendName: name,
            avatarUrl: avatar,
            status: activityStatus,
            timestamp: item.addedAt.millisecondsSinceEpoch,
          );
          activities.add(activity);
        }
      }

      if (activities.isNotEmpty) {
        await _dbHelper.batchInsertActivities(activities);
        //Notify
        for (var act in activities) {
          _itemUpdateController.add(act.itemId);
        }
      }

      debugPrint('SocialSyncService: Synced ${activities.length} activities.');
    } catch (e) {
      _isSyncing = false;
      debugPrint('Error starting social sync: $e');
    }
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
