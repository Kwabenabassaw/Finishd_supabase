import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/user_model.dart';

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
      throw e;
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

      batch.set(followingRef, {'followedAt': FieldValue.serverTimestamp()});
      batch.set(followerRef, {'followedAt': FieldValue.serverTimestamp()});

      await batch.commit();
    } catch (e) {
      print('Error following user: $e');
      throw e;
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

      batch.delete(followingRef);
      batch.delete(followerRef);

      await batch.commit();
    } catch (e) {
      print('Error unfollowing user: $e');
      throw e;
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
}
