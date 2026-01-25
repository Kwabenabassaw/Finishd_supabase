import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/services/cache/following_cache_service.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';
  final String _followersCollection = 'followers';
  final String _followingCollection = 'following';

  // Fetch user data
  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  // Stream user data
  Stream<UserModel?> getUserStream(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots().map((
      doc,
    ) {
      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    });
  }

  // Update user profile
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update(user.toJson());
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // Follow a user
  Future<void> followUser(String currentUid, String targetUid) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Add to current user's following subcollection
      DocumentReference followingRef = _firestore
          .collection(_usersCollection)
          .doc(currentUid)
          .collection(_followingCollection)
          .doc(targetUid);

      // Add to target user's followers subcollection
      DocumentReference followerRef = _firestore
          .collection(_usersCollection)
          .doc(targetUid)
          .collection(_followersCollection)
          .doc(currentUid);

      // References to user documents for count updates
      DocumentReference currentUserRef = _firestore
          .collection(_usersCollection)
          .doc(currentUid);
      DocumentReference targetUserRef = _firestore
          .collection(_usersCollection)
          .doc(targetUid);

      batch.set(followingRef, {'followedAt': FieldValue.serverTimestamp()});
      batch.set(followerRef, {'followedAt': FieldValue.serverTimestamp()});

      // Atomic count updates
      batch.update(currentUserRef, {'followingCount': FieldValue.increment(1)});
      batch.update(targetUserRef, {'followersCount': FieldValue.increment(1)});

      await batch.commit();

      // Invalidate caches
      await FollowingCacheService.invalidateFollowing(currentUid);
      await FollowingCacheService.invalidateFollowers(targetUid);
    } catch (e) {
      print('Error following user: $e');
      rethrow;
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String currentUid, String targetUid) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Remove from current user's following subcollection
      DocumentReference followingRef = _firestore
          .collection(_usersCollection)
          .doc(currentUid)
          .collection(_followingCollection)
          .doc(targetUid);

      // Remove from target user's followers subcollection
      DocumentReference followerRef = _firestore
          .collection(_usersCollection)
          .doc(targetUid)
          .collection(_followersCollection)
          .doc(currentUid);

      // References to user documents for count updates
      DocumentReference currentUserRef = _firestore
          .collection(_usersCollection)
          .doc(currentUid);
      DocumentReference targetUserRef = _firestore
          .collection(_usersCollection)
          .doc(targetUid);

      batch.delete(followingRef);
      batch.delete(followerRef);

      // Atomic count updates
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });
      batch.update(targetUserRef, {'followersCount': FieldValue.increment(-1)});

      await batch.commit();

      // Invalidate caches
      await FollowingCacheService.invalidateFollowing(currentUid);
      await FollowingCacheService.invalidateFollowers(targetUid);
    } catch (e) {
      print('Error unfollowing user: $e');
      rethrow;
    }
  }

  // Check if following
  Future<bool> isFollowing(String currentUid, String targetUid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_usersCollection)
          .doc(currentUid)
          .collection(_followingCollection)
          .doc(targetUid)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Get followers list
  Future<List<String>> getFollowers(String uid) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_followersCollection)
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error fetching followers: $e');
      return [];
    }
  }

  // Get following list
  Future<List<String>> getFollowing(String uid) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_followingCollection)
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error fetching following: $e');
      return [];
    }
  }

  // Get all users with pagination (for Find Friends)
  // limit: number of users to fetch per page
  // lastDocument: the last document from previous page for pagination
  Future<List<UserModel>> getAllUsers({
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_usersCollection)
          .orderBy('username')
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList();
    } catch (e) {
      print('Error fetching all users: $e');
      return [];
    }
  }

  // Search users by username (for Find Friends search)
  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    try {
      // Firestore doesn't support full-text search, so we use prefix matching
      final String searchEnd =
          query.substring(0, query.length - 1) +
          String.fromCharCode(query.codeUnitAt(query.length - 1) + 1);

      QuerySnapshot snapshot = await _firestore
          .collection(_usersCollection)
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThan: searchEnd.toLowerCase())
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get users by list of IDs - OPTIMIZED with parallel fetching
  Future<List<UserModel>> getUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    try {
      // Fetch all users in parallel instead of sequentially
      final futures = uids.map(
        (uid) => _firestore.collection(_usersCollection).doc(uid).get(),
      );

      final docs = await Future.wait(futures);

      return docs
          .where((doc) => doc.exists)
          .map((doc) => UserModel.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error fetching users by IDs: $e');
      return [];
    }
  }

  // Get followers count
  Future<int> getFollowersCount(String uid) async {
    try {
      AggregateQuerySnapshot snapshot = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_followersCollection)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error fetching followers count: $e');
      return 0;
    }
  }

  // Get following count
  Future<int> getFollowingCount(String uid) async {
    try {
      AggregateQuerySnapshot snapshot = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_followingCollection)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error fetching following count: $e');
      return 0;
    }
  }

  // ==========================================================================
  // CACHED & PAGINATED METHODS (Social Graph Optimization)
  // ==========================================================================

  /// Get following with SQLite cache (24h TTL)
  /// Significantly reduces Firestore reads on app startup and feed generation
  Future<List<String>> getFollowingCached(String uid) async {
    try {
      // 1. Try cache first
      final cached = await FollowingCacheService.getFollowingIds(uid);
      if (cached != null) {
        print('✅ Using cached following for $uid (${cached.length} users)');
        return cached;
      }

      // 2. Fetch from Firestore
      print('📡 Fetching following from Firestore for $uid');
      final ids = await getFollowing(uid);

      // 3. Save to cache
      await FollowingCacheService.saveFollowingIds(uid, ids);

      return ids;
    } catch (e) {
      print('Error in getFollowingCached: $e');
      // Fallback to direct Firestore on cache error
      return await getFollowing(uid);
    }
  }

  /// Get followers with SQLite cache (24h TTL)
  Future<List<String>> getFollowersCached(String uid) async {
    try {
      // 1. Try cache first
      final cached = await FollowingCacheService.getFollowersIds(uid);
      if (cached != null) {
        print('✅ Using cached followers for $uid (${cached.length} users)');
        return cached;
      }

      // 2. Fetch from Firestore
      print('📡 Fetching followers from Firestore for $uid');
      final ids = await getFollowers(uid);

      // 3. Save to cache
      await FollowingCacheService.saveFollowersIds(uid, ids);

      return ids;
    } catch (e) {
      print('Error in getFollowersCached: $e');
      // Fallback to direct Firestore on cache error
      return await getFollowers(uid);
    }
  }

  /// Get followers with pagination (50 per page)
  /// Reduces read costs for users with many followers
  Future<List<String>> getFollowersPaginated(
    String uid, {
    int limit = 50,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query query = _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_followersCollection)
          .orderBy(FieldPath.documentId)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error in getFollowersPaginated: $e');
      return [];
    }
  }

  /// Get following with pagination (50 per page)
  Future<List<String>> getFollowingPaginated(
    String uid, {
    int limit = 50,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query query = _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_followingCollection)
          .orderBy(FieldPath.documentId)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error in getFollowingPaginated: $e');
      return [];
    }
  }

  /// Get users with profile cache (7-day TTL)
  /// Checks SQLite first, only fetches missing profiles from Firestore
  Future<List<UserModel>> getUsersCached(List<String> uids) async {
    if (uids.isEmpty) return [];

    try {
      final List<UserModel> users = [];
      final List<String> missingUids = [];

      // 1. Check cache for each user
      for (final uid in uids) {
        final cached = await FollowingCacheService.getUserProfile(uid);
        if (cached != null) {
          users.add(UserModel.fromJson(cached));
        } else {
          missingUids.add(uid);
        }
      }

      print(
        '✅ Cache hit: ${users.length}/${uids.length} profiles, fetching ${missingUids.length} from Firestore',
      );

      // 2. Fetch missing from Firestore
      if (missingUids.isNotEmpty) {
        final fetched = await getUsers(missingUids);
        users.addAll(fetched);

        // 3. Cache the fetched users
        await FollowingCacheService.saveUserProfiles(fetched);
      }

      return users;
    } catch (e) {
      print('Error in getUsersCached: $e');
      // Fallback to direct Firestore on cache error
      return await getUsers(uids);
    }
  }
}
