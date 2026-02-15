import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/cache/following_cache_service.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================================================================
  // CORE USER DATA
  // ==========================================================================

  /// Fetch user data from public.profiles
  Future<UserModel?> getUser(String uid) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (response != null) {
        // Map keys manually since our UserModel likely expects Firestore field names
        final data = Map<String, dynamic>.from(response);
        data['uid'] = data['id'];
        data['profileImage'] = data['avatar_url'];
        data['firstName'] = data['first_name'];
        data['lastName'] = data['last_name'];

        // Add counts if needed
        data['followersCount'] = await getFollowersCount(uid);
        data['followingCount'] = await getFollowingCount(uid);

        return UserModel.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  Stream<UserModel?> getUserStream(String uid) {
    // Supabase Realtime for a single row
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((List<Map<String, dynamic>> data) {
          if (data.isEmpty) return null;
          final row = data.first;
          // Adapter
          final map = Map<String, dynamic>.from(row);
          map['uid'] = map['id'];
          map['profileImage'] = map['avatar_url'];
          map['firstName'] = map['first_name'];
          map['lastName'] = map['last_name'];
          // Ensure these are passed through to fromJson
          map['role'] = map['role'];
          map['creator_status'] = map['creator_status'];
          map['creator_verified_at'] = map['creator_verified_at'];
          return UserModel.fromJson(map);
        });
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'username': user.username,
            'first_name': user.firstName,
            'last_name': user.lastName,
            'bio': user.bio,
            'description': user.description,
            'avatar_url': user.profileImage, // Corrected field
          })
          .eq('id', user.uid);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // SOCIAL GRAPH (Using 'follows' table)
  // ==========================================================================

  Future<void> followUser(String currentUid, String targetUid) async {
    try {
      await _supabase.from('follows').insert({
        'follower_id': currentUid,
        'following_id': targetUid,
      });

      // Invalidate caches
      await FollowingCacheService.invalidateFollowing(currentUid);
      await FollowingCacheService.invalidateFollowers(targetUid);
    } catch (e) {
      print('Error following user: $e');
      // Ignore duplicate key error
    }
  }

  Future<void> unfollowUser(String currentUid, String targetUid) async {
    try {
      await _supabase.from('follows').delete().match({
        'follower_id': currentUid,
        'following_id': targetUid,
      });

      await FollowingCacheService.invalidateFollowing(currentUid);
      await FollowingCacheService.invalidateFollowers(targetUid);
    } catch (e) {
      print('Error unfollowing user: $e');
    }
  }

  Future<void> blockUser(String currentUid, String targetUid) async {
    try {
      await _supabase.from('user_blocks').insert({
        'blocker_id': currentUid,
        'blocked_id': targetUid,
      });
      // Also unfollow
      await unfollowUser(currentUid, targetUid);
    } catch (e) {
      print('Error blocking user: $e');
    }
  }

  Future<void> unblockUser(String currentUid, String targetUid) async {
    try {
      await _supabase.from('user_blocks').delete().match({
        'blocker_id': currentUid,
        'blocked_id': targetUid,
      });
    } catch (e) {
      print('Error unblocking user: $e');
    }
  }

  Future<List<String>> getBlockedUsers(String uid) async {
    try {
      final response = await _supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', uid);
      return (response as List).map((e) => e['blocked_id'] as String).toList();
    } catch (e) {
      print('Error fetching blocked users: $e');
      return [];
    }
  }

  Future<bool> isFollowing(String currentUid, String targetUid) async {
    try {
      final response = await _supabase.from('follows').select().match({
        'follower_id': currentUid,
        'following_id': targetUid,
      }).maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getFollowers(String uid) async {
    final response = await _supabase
        .from('follows')
        .select('follower_id')
        .eq('following_id', uid);
    return (response as List).map((e) => e['follower_id'] as String).toList();
  }

  Future<List<String>> getFollowing(String uid) async {
    final response = await _supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', uid);
    return (response as List).map((e) => e['following_id'] as String).toList();
  }

  Future<int> getFollowersCount(String uid) async {
    final response = await _supabase
        .from('follows')
        .count()
        .eq('following_id', uid);
    return response;
  }

  Future<int> getFollowingCount(String uid) async {
    final response = await _supabase
        .from('follows')
        .count()
        .eq('follower_id', uid);
    return response;
  }

  // ==========================================================================
  // SEARCH & DISCOVERY
  // ==========================================================================

  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    final response = await _supabase
        .from('profiles')
        .select()
        .ilike('username', '%$query%') // Case-insensitive partial match
        .limit(limit);

    return (response as List).map((row) {
      final map = Map<String, dynamic>.from(row);
      map['uid'] = map['id'];
      map['profileImage'] = map['avatar_url'];
      map['firstName'] = map['first_name'];
      map['lastName'] = map['last_name'];
      return UserModel.fromJson(map);
    }).toList();
  }

  Future<List<UserModel>> getAllUsers({int limit = 50}) async {
    final response = await _supabase.from('profiles').select().limit(limit);
    return (response as List).map((row) {
      final map = Map<String, dynamic>.from(row);
      map['uid'] = map['id'];
      map['profileImage'] = map['avatar_url'];
      map['firstName'] = map['first_name'];
      map['lastName'] = map['last_name'];
      return UserModel.fromJson(map);
    }).toList();
  }

  // ==========================================================================
  // CACHED & PAGINATED (Keep implementation but switch to Supabase backend)
  // ==========================================================================

  // Re-use existing cache logic but call new getFollowing/getFollowers
  Future<List<String>> getFollowingCached(String uid) async {
    final cached = await FollowingCacheService.getFollowingIds(uid);
    if (cached != null) return cached;
    final ids = await getFollowing(uid);
    await FollowingCacheService.saveFollowingIds(uid, ids);
    return ids;
  }

  Future<List<String>> getFollowersCached(String uid) async {
    final cached = await FollowingCacheService.getFollowersIds(uid);
    if (cached != null) return cached;
    final ids = await getFollowers(uid);
    await FollowingCacheService.saveFollowersIds(uid, ids);
    return ids;
  }

  Future<List<UserModel>> getUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    // Correct filter syntax
    final response = await _supabase
        .from('profiles')
        .select()
        .filter('id', 'in', uids);

    return (response as List).map((row) {
      final map = Map<String, dynamic>.from(row);
      map['uid'] = map['id'];
      map['profileImage'] = map['avatar_url'];
      map['firstName'] = map['first_name'];
      map['lastName'] = map['last_name'];
      return UserModel.fromJson(map);
    }).toList();
  }

  Future<List<UserModel>> getUsersCached(List<String> uids) async {
    return getUsers(uids);
  }

  Future<List<String>> getFollowersPaginated(
    String uid, {
    int limit = 50,
  }) async {
    return getFollowers(uid);
  }

  Future<List<String>> getFollowingPaginated(
    String uid, {
    int limit = 50,
  }) async {
    return getFollowing(uid);
  }
}
