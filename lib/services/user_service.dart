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

      DocumentReference followingRef = _firestore
          .collection(_followingCollection)
          .doc(currentUid)
          .collection('list')
          .doc(targetUid);

      DocumentReference followerRef = _firestore
          .collection(_followersCollection)
          .doc(targetUid)
          .collection('list')
          .doc(currentUid);

      DocumentReference currentUserRef = _firestore
          .collection(_usersCollection)
          .doc(currentUid);
      DocumentReference targetUserRef = _firestore
          .collection(_usersCollection)
          .doc(targetUid);

      batch.set(followingRef, {'followedAt': FieldValue.serverTimestamp()});
      batch.set(followerRef, {'followedAt': FieldValue.serverTimestamp()});

      batch.update(currentUserRef, {'followingCount': FieldValue.increment(1)});
      batch.update(targetUserRef, {'followersCount': FieldValue.increment(1)});

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

      DocumentReference followingRef = _firestore
          .collection(_followingCollection)
          .doc(currentUid)
          .collection('list')
          .doc(targetUid);

      DocumentReference followerRef = _firestore
          .collection(_followersCollection)
          .doc(targetUid)
          .collection('list')
          .doc(currentUid);

      DocumentReference currentUserRef = _firestore
          .collection(_usersCollection)
          .doc(currentUid);
      DocumentReference targetUserRef = _firestore
          .collection(_usersCollection)
          .doc(targetUid);

      batch.delete(followingRef);
      batch.delete(followerRef);

      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });
      batch.update(targetUserRef, {'followersCount': FieldValue.increment(-1)});

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
          .collection(_followingCollection)
          .doc(currentUid)
          .collection('list')
          .doc(targetUid)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }
}
