import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing show-centric communities with lazy creation.
/// Communities are only created when user activity occurs (first post/comment).
class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _communities => _firestore.collection('communities');
  CollectionReference get _posts => _firestore.collection('community_posts');
  CollectionReference get _comments =>
      _firestore.collection('community_comments');

  String? get _currentUid => _auth.currentUser?.uid;

  // ==========================================================================
  // COMMUNITY CREATION (LAZY / ON-DEMAND)
  // ==========================================================================

  /// Ensures a community exists for the given show.
  /// Uses showId as document ID to prevent duplicates (idempotent).
  ///
  /// Returns the community data (existing or newly created).
  Future<Map<String, dynamic>> ensureCommunityExists({
    required int showId,
    required String title,
    required String? posterPath,
    required String mediaType, // "tv" or "movie"
  }) async {
    final docRef = _communities.doc(showId.toString());

    // Check if already exists (fast path)
    final doc = await docRef.get();
    if (doc.exists) {
      print('🏠 Community already exists for $title');
      return doc.data() as Map<String, dynamic>;
    }

    // Create new community
    final communityData = {
      'showId': showId,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mediaType,
      'memberCount': 0,
      'postCount': 0,
      'lastActivityAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _currentUid,
    };

    // Use set() with merge - idempotent, safe for concurrent creation
    await docRef.set(communityData, SetOptions(merge: true));

    print('✅ Created community for $title (id: $showId)');
    return communityData;
  }

  /// Check if a community exists for a show
  Future<bool> communityExists(int showId) async {
    final doc = await _communities.doc(showId.toString()).get();
    return doc.exists;
  }

  /// Get community data for a show
  Future<Map<String, dynamic>?> getCommunity(int showId) async {
    final doc = await _communities.doc(showId.toString()).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return data;
  }

  // ==========================================================================
  // POSTS
  // ==========================================================================

  /// Create a new post in a community.
  /// Automatically creates the community if it doesn't exist.
  Future<String?> createPost({
    required int showId,
    required String showTitle,
    required String? posterPath,
    required String mediaType,
    required String content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
    List<String> hashtags = const [],
    bool isSpoiler = false,
  }) async {
    if (_currentUid == null) return null;

    try {
      // Step 1: Ensure community exists (lazy creation trigger)
      await ensureCommunityExists(
        showId: showId,
        title: showTitle,
        posterPath: posterPath,
        mediaType: mediaType,
      );

      // Step 2: Get current user info
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUid)
          .get();
      final userData = userDoc.data() ?? {};

      // Step 3: Create the post
      final postData = {
        'showId': showId,
        'showTitle': showTitle,
        'communityId': showId.toString(),
        'authorId': _currentUid,
        'authorName': userData['username'] ?? 'Anonymous',
        'authorAvatar': userData['profileImage'],
        'content': content,
        'mediaUrls': mediaUrls,
        'mediaTypes': mediaTypes,
        'hashtags': hashtags,
        'isSpoiler': isSpoiler,
        'score': 0,
        'upvotes': 0,
        'downvotes': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
      };

      final postRef = await _posts.add(postData);

      // Step 4: Update community stats
      await _communities.doc(showId.toString()).update({
        'postCount': FieldValue.increment(1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      // Step 5: Add user as member if first interaction
      // We use the transactional join here to ensure consistency
      await joinCommunity(showId);

      print('📝 Created post in ${showTitle} community');
      return postRef.id;
    } catch (e) {
      print('❌ Error creating post: $e');
      return null;
    }
  }

  /// Delete a post and update community stats
  Future<bool> deletePost(String postId, int showId) async {
    if (_currentUid == null) return false;

    try {
      final postDoc = await _posts.doc(postId).get();
      if (!postDoc.exists) return false;

      // Check if user is author
      final data = postDoc.data() as Map<String, dynamic>?;
      if (data == null || data['authorId'] != _currentUid) {
        throw Exception('Unauthorized: You can only delete your own posts');
      }

      final batch = _firestore.batch();

      // Delete the post
      batch.delete(_posts.doc(postId));

      // Decrement post count in community
      batch.update(_communities.doc(showId.toString()), {
        'postCount': FieldValue.increment(-1),
      });

      // Note: In a production app, we would also delete all comments
      // and media associated with this post. For now, we'll keep it simple.

      await batch.commit();
      return true;
    } catch (e) {
      print('❌ Error deleting post: $e');
      return false;
    }
  }

  /// Get posts for a community, sorted by recent activity
  Future<List<Map<String, dynamic>>> getPosts({
    required int showId,
    int limit = 20,
    DocumentSnapshot? lastDoc,
    String sortBy = 'createdAt', // 'createdAt', 'upvotes', 'commentCount'
  }) async {
    try {
      Query query = _posts
          .where('showId', isEqualTo: showId)
          .orderBy(sortBy, descending: true)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['docSnapshot'] = doc; // For pagination
        print(
          '[CommunityService] Post ${doc.id} - upvotes: ${data['upvotes']}, downvotes: ${data['downvotes']}, score: ${data['score']}',
        );
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error fetching posts: $e');
      return [];
    }
  }

  /// Get a single post by ID
  Future<Map<String, dynamic>?> getPost(String postId) async {
    try {
      final doc = await _posts.doc(postId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      print('❌ Error fetching single post: $e');
      return null;
    }
  }

  /// Get a stream of posts for real-time updates
  Stream<List<Map<String, dynamic>>> getPostsStream({
    required int showId,
    int limit = 20,
  }) {
    return _posts
        .where('showId', isEqualTo: showId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  // ==========================================================================
  // COMMENTS
  // ==========================================================================

  /// Add a comment to a post
  Future<String?> addComment({
    required String postId,
    required int showId,
    required String content,
    String? parentId, // For replies
  }) async {
    if (_currentUid == null) return null;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUid)
          .get();
      final userData = userDoc.data() ?? {};

      final commentData = {
        'postId': postId,
        'showId': showId,
        'authorId': _currentUid,
        'authorName': userData['username'] ?? 'Anonymous',
        'authorAvatar': userData['profileImage'],
        'content': content,
        'parentId': parentId,
        'upvotes': 0,
        'downvotes': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final commentRef = await _comments.add(commentData);

      // Update post comment count
      await _posts.doc(postId).update({
        'commentCount': FieldValue.increment(1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      // Update community activity
      await _communities.doc(showId.toString()).update({
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      print('💬 Added comment to post $postId');
      return commentRef.id;
    } catch (e) {
      print('❌ Error adding comment: $e');
      return null;
    }
  }

  /// Get comments for a post
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _comments
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  // ==========================================================================
  // VOTING
  // ==========================================================================

  /// Vote on a post using a Transaction to ensure atomic updates and consistency.
  ///
  /// [vote]: 1 for upvote, -1 for downvote.
  /// Toggling (clicking same vote again) should be handled by the UI passing the *same* vote
  /// and this logic detecting it, OR the UI passing 0.
  ///
  /// Logic:
  /// - If user already has [vote], remove it (toggle off).
  /// - If user has different vote, switch it.
  /// - Is user has no vote, add it.
  Future<void> voteOnPost({
    required String postId,
    required int showId,
    required int
    vote, // 1 (Up) or -1 (Down). Use 0 to explicitly remove (optional).
  }) async {
    if (_currentUid == null) return;

    final voteRef = _firestore
        .collection('community_votes')
        .doc('${showId}_${postId}_$_currentUid');
    final postRef = _posts.doc(postId);

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Get post (to ensure existence and for locking)
        final postSnapshot = await transaction.get(postRef);
        if (!postSnapshot.exists) {
          throw Exception("Post does not exist!");
        }

        // 2. Get user's current vote
        final voteSnapshot = await transaction.get(voteRef);
        final int currentVote = voteSnapshot.exists
            ? (voteSnapshot.data()?['vote'] as int? ?? 0)
            : 0;

        // 3. Determine new vote state
        // If incoming vote matches current vote, treat as "toggle off" => 0
        // Unless incoming is explicitly 0, then just 0.
        int newVote = (vote == currentVote) ? 0 : vote;
        if (vote == 0) newVote = 0; // Explicit remove

        // If no change needed, exit
        if (newVote == currentVote) return;

        // 4. Calculate Deltas
        int upvoteDelta = 0;
        int downvoteDelta = 0;

        // Remove old impact
        if (currentVote == 1) upvoteDelta -= 1;
        if (currentVote == -1) downvoteDelta -= 1;

        // Add new impact
        if (newVote == 1) upvoteDelta += 1;
        if (newVote == -1) downvoteDelta += 1;

        // 5. Write User Vote
        if (newVote == 0) {
          transaction.delete(voteRef);
        } else {
          transaction.set(voteRef, {
            'type': 'post',
            'targetId': postId,
            'showId': showId,
            'uid': _currentUid,
            'vote': newVote,
            'createdAt': FieldValue.serverTimestamp(),
            // 'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // 6. Update Post Counters
        if (upvoteDelta != 0 || downvoteDelta != 0) {
          transaction.update(postRef, {
            'upvotes': FieldValue.increment(upvoteDelta),
            'downvotes': FieldValue.increment(downvoteDelta),
            'score': FieldValue.increment(upvoteDelta - downvoteDelta),
            'lastActivityAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Post-transaction actions (like creating community if needed) can go here
      // But creating community should ideally happen on POST creation, not VOTE.
      // Re-adding `ensureCommunityExists` just in case, but outside transaction.
      // await ensureCommunityExists(...) // Usually not needed for voting on existing post
    } catch (e) {
      print('❌ Error voting (Transaction failed): $e');
      rethrow; // Rethrow to let UI know to revert optimistic update
    }
  }

  /// Get user's vote on a post
  Future<int> getUserVote(String postId, int showId) async {
    if (_currentUid == null) return 0;

    final voteId = '${showId}_${postId}_$_currentUid';
    print('[CommunityService] Looking up vote: $voteId');

    final doc = await _firestore
        .collection('community_votes')
        .doc(voteId)
        .get();

    final vote = doc.exists ? (doc.data()?['vote'] as int? ?? 0) : 0;
    print(
      '[CommunityService] Vote document exists: ${doc.exists}, vote: $vote',
    );
    return vote;
  }

  /// Vote on a comment using a Transaction to ensure atomic updates.
  ///
  /// [vote]: 1 for upvote, -1 for downvote.
  /// Logic is identical to post voting - toggle off if same vote clicked again.
  Future<void> voteOnComment({
    required String commentId,
    required String postId,
    required int showId,
    required int vote,
  }) async {
    if (_currentUid == null) return;

    final voteRef = _firestore
        .collection('community_votes')
        .doc('comment_${commentId}_$_currentUid');
    final commentRef = _comments.doc(commentId);

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Get comment (to ensure existence)
        final commentSnapshot = await transaction.get(commentRef);
        if (!commentSnapshot.exists) {
          throw Exception("Comment does not exist!");
        }

        // 2. Get user's current vote
        final voteSnapshot = await transaction.get(voteRef);
        final int currentVote = voteSnapshot.exists
            ? (voteSnapshot.data()?['vote'] as int? ?? 0)
            : 0;

        // 3. Determine new vote state (toggle off if same vote)
        int newVote = (vote == currentVote) ? 0 : vote;
        if (vote == 0) newVote = 0;

        // If no change needed, exit
        if (newVote == currentVote) return;

        // 4. Calculate Deltas
        int upvoteDelta = 0;
        int downvoteDelta = 0;

        if (currentVote == 1) upvoteDelta -= 1;
        if (currentVote == -1) downvoteDelta -= 1;
        if (newVote == 1) upvoteDelta += 1;
        if (newVote == -1) downvoteDelta += 1;

        // 5. Write User Vote
        if (newVote == 0) {
          transaction.delete(voteRef);
        } else {
          transaction.set(voteRef, {
            'type': 'comment',
            'targetId': commentId,
            'postId': postId,
            'showId': showId,
            'uid': _currentUid,
            'vote': newVote,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // 6. Update Comment Counters
        if (upvoteDelta != 0 || downvoteDelta != 0) {
          transaction.update(commentRef, {
            'upvotes': FieldValue.increment(upvoteDelta),
            'downvotes': FieldValue.increment(downvoteDelta),
          });
        }
      });
    } catch (e) {
      print('❌ Error voting on comment: $e');
      rethrow;
    }
  }

  /// Get user's vote on a comment
  Future<int> getUserCommentVote(String commentId) async {
    if (_currentUid == null) return 0;

    final voteId = 'comment_${commentId}_$_currentUid';
    final doc = await _firestore
        .collection('community_votes')
        .doc(voteId)
        .get();

    if (!doc.exists) return 0;
    return doc.data()?['vote'] as int? ?? 0;
  }

  // ==========================================================================
  // DISCOVERY
  // ==========================================================================

  /// Get active communities (postCount > 0, recent activity)
  Future<List<Map<String, dynamic>>> discoverCommunities({
    int limit = 20,
    String? mediaTypeFilter, // "tv", "movie", or null for all
  }) async {
    try {
      Query query = _communities
          .where('postCount', isGreaterThan: 0)
          .orderBy('postCount', descending: true)
          .orderBy('lastActivityAt', descending: true)
          .limit(limit);

      if (mediaTypeFilter != null) {
        query = query.where('mediaType', isEqualTo: mediaTypeFilter);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error discovering communities: $e');
      return [];
    }
  }

  /// Get communities the user has participated in
  /// Uses user's my_communities subcollection (no collectionGroup needed)
  Future<List<Map<String, dynamic>>> getMyCommunities() async {
    if (_currentUid == null) return [];

    try {
      // Get community IDs from user's my_communities subcollection
      final myCommunitiesSnapshot = await _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('my_communities')
          .orderBy('joinedAt', descending: true)
          .get();

      final List<Map<String, dynamic>> communities = [];

      final futures = myCommunitiesSnapshot.docs.map((doc) async {
        final showId = doc.id;
        final communityDoc = await _communities.doc(showId).get();
        if (communityDoc.exists) {
          final data = communityDoc.data() as Map<String, dynamic>;
          data['id'] = communityDoc.id;

          // Fetch the most recent post for this community to display on the card
          if ((data['postCount'] ?? 0) > 0) {
            try {
              final postSnapshot = await _posts
                  .where('showId', isEqualTo: int.tryParse(showId) ?? 0)
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .get();

              if (postSnapshot.docs.isNotEmpty) {
                final postData =
                    postSnapshot.docs.first.data() as Map<String, dynamic>;
                data['recentPostContent'] = postData['content'];
                data['recentPostAuthor'] = postData['authorName'];
                data['recentPostTime'] = postData['createdAt'];
              }
            } catch (e) {
              // Fail silently on post fetch
              print('Warning: could not fetch recent post for $showId: $e');
            }
          }

          return data;
        }
        return null;
      });

      final results = await Future.wait(futures);

      return results
          .where((c) => c != null)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('❌ Error fetching my communities: $e');
      return [];
    }
  }

  // ==========================================================================
  // MEMBERSHIP
  // ==========================================================================

  /// Explicitly join a community using a Transaction.
  /// TODO: In the future, move the counter update or the dual-write logic to a Cloud Function
  /// to prevent client-side manipulation of the memberCount.
  Future<void> joinCommunity(int showId) async {
    if (_currentUid == null) return;

    final communityRef = _communities.doc(showId.toString());
    final memberRef = communityRef.collection('members').doc(_currentUid);
    final userCommunityRef = _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('my_communities')
        .doc(showId.toString());

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Check if already member (Read first)
        final memberSnapshot = await transaction.get(memberRef);
        if (memberSnapshot.exists) {
          // Already joined, idempotent exit.
          // We might want to ensure the user list doc exists too, but assuming sync.
          return;
        }

        // 2. Create Member Record
        transaction.set(memberRef, {
          'uid': _currentUid,
          'joinedAt': FieldValue.serverTimestamp(),
          'role': 'member',
        });

        // 3. Add to User's List
        transaction.set(userCommunityRef, {
          'showId': showId,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // 4. Increment Counter
        // Using increment inside transaction is safe.
        transaction.update(communityRef, {
          'memberCount': FieldValue.increment(1),
          // We don't necessarily update lastActivityAt on join
        });
      });

      print('👤 Joined community $showId');
    } catch (e) {
      print('❌ Error joining community: $e');
      rethrow;
    }
  }

  /// Leave a community using a Transaction.
  Future<void> leaveCommunity(int showId) async {
    if (_currentUid == null) return;

    final communityRef = _communities.doc(showId.toString());
    final memberRef = communityRef.collection('members').doc(_currentUid);
    final userCommunityRef = _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('my_communities')
        .doc(showId.toString());

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Check if member (Read first)
        final memberSnapshot = await transaction.get(memberRef);
        if (!memberSnapshot.exists) {
          // Not a member, mostly idempotent, but let's just return
          return;
        }

        // 2. Delete Member Record
        transaction.delete(memberRef);

        // 3. Remove from User's List
        transaction.delete(userCommunityRef);

        // 4. Decrement Counter
        transaction.update(communityRef, {
          'memberCount': FieldValue.increment(-1),
        });
      });

      print('👋 Left community $showId');
    } catch (e) {
      print('❌ Error leaving community: $e');
      rethrow;
    }
  }

  /// Check if user is a member of a community
  Future<bool> isMember(int showId) async {
    if (_currentUid == null) return false;

    final memberDoc = await _communities
        .doc(showId.toString())
        .collection('members')
        .doc(_currentUid)
        .get();

    return memberDoc.exists;
  }

  /// Delete a community (only if creator)
  Future<bool> deleteCommunity(int showId) async {
    if (_currentUid == null) return false;

    try {
      final docRef = _communities.doc(showId.toString());
      final doc = await docRef.get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      if (data['createdBy'] != _currentUid) {
        throw Exception(
          'Unauthorized: Only the creator can delete this community',
        );
      }

      // In a production app, we'd also delete all posts, members, and comments.
      // For now, we'll just delete the community document.
      await docRef.delete();
      return true;
    } catch (e) {
      print('❌ Error deleting community: $e');
      return false;
    }
  }
}
