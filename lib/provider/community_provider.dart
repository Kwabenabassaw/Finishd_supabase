import 'package:flutter/material.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/services/community_service.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/services/storage_service.dart';
import 'package:finishd/services/voting_api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CommunityProvider extends ChangeNotifier {
  final CommunityService _communityService = CommunityService();
  final Trending _trending = Trending();
  final StorageService _storageService = StorageService();
  final VotingApiClient _votingApi = VotingApiClient();

  // Feature flag: Set to true to use new backend, false to use Firestore directly
  bool _useVotingBackend = true;

  bool _isUploadingMedia = false;
  String? _selectedHashtag;
  bool get isUploadingMedia => _isUploadingMedia;
  String? get selectedHashtag => _selectedHashtag;

  // My Communities
  List<Community> _myCommunities = [];
  bool _isLoadingMyCommunities = false;

  // Discover Content
  List<MediaItem> _discoverContent = [];
  bool _isLoadingDiscover = false;
  String _discoverFilter = 'trending'; // 'trending', 'tv', 'movie'

  // Trending & Recommended Communities
  List<Community> _trendingCommunities = [];
  List<Community> _recommendedCommunities = [];
  bool _isLoadingTrending = false;
  bool _isLoadingRecommended = false;

  // Current Open Community (for detail screen)
  Community? _currentCommunity;
  List<CommunityPost> _currentPosts = [];
  bool _isLoadingCommunityDetails = false;
  bool _isMemberOfCurrent = false;
  String _currentSortBy = 'createdAt';
  String _searchQuery = '';
  Map<String, int> _currentUserVotes = {}; // postId -> vote
  Map<String, int> _commentVotes = {}; // commentId -> vote

  // Getters
  List<CommunityPost> get filteredPosts {
    List<CommunityPost> results = _currentPosts;

    // Apply hashtag filter if any
    if (_selectedHashtag != null) {
      results = results
          .where((p) => p.hashtags.contains(_selectedHashtag))
          .toList();
    }

    // Apply search query filter if any
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      results = results.where((post) {
        final contentMatch = post.content.toLowerCase().contains(query);
        final authorMatch = post.authorName.toLowerCase().contains(query);
        final hashtagMatch = post.hashtags.any(
          (tag) => tag.toLowerCase().contains(query),
        );
        return contentMatch || authorMatch || hashtagMatch;
      }).toList();
    }

    return results;
  }

  /// Get trending hashtags for the current community based on post frequency
  List<String> get trendingHashtags {
    if (_currentPosts.isEmpty) return [];

    final counts = <String, int>{};
    for (final post in _currentPosts) {
      for (final tag in post.hashtags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }

    // Sort by frequency and return top 10
    final sortedTags = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return sortedTags.take(10).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Community> get myCommunities => _myCommunities;
  bool get isLoadingMyCommunities => _isLoadingMyCommunities;

  List<MediaItem> get discoverContent => _discoverContent;
  bool get isLoadingDiscover => _isLoadingDiscover;
  String get discoverFilter => _discoverFilter;

  List<Community> get trendingCommunities => _trendingCommunities;
  List<Community> get recommendedCommunities => _recommendedCommunities;
  bool get isLoadingTrending => _isLoadingTrending;
  bool get isLoadingRecommended => _isLoadingRecommended;

  Community? get currentCommunity => _currentCommunity;
  List<CommunityPost> get currentPosts => _currentPosts;
  bool get isLoadingCommunityDetails => _isLoadingCommunityDetails;
  bool get isMemberOfCurrent => _isMemberOfCurrent;
  String get currentSortBy => _currentSortBy;
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  Map<String, int> get currentUserVotes => _currentUserVotes;
  Map<String, int> get commentVotes => _commentVotes;

  // --- Global Lists ---

  Future<void> fetchMyCommunities() async {
    _isLoadingMyCommunities = true;
    notifyListeners();

    try {
      final results = await _communityService.getMyCommunities();
      _myCommunities = results.map((c) => Community.fromJson(c)).toList();
    } catch (e) {
      print('Error fetching my communities: $e');
    } finally {
      _isLoadingMyCommunities = false;
      notifyListeners();
    }
  }

  Future<void> fetchDiscoverContent() async {
    _isLoadingDiscover = true;
    notifyListeners();

    try {
      List<MediaItem> content = [];

      // We need to know my communities to filter them out
      if (_myCommunities.isEmpty) {
        // Ensure my communities are loaded for filtering
        final myResults = await _communityService.getMyCommunities();
        _myCommunities = myResults.map((c) => Community.fromJson(c)).toList();
      }
      final myShowIds = _myCommunities.map((c) => c.showId).toSet();

      if (_discoverFilter == 'trending' || _discoverFilter == 'movie') {
        final movies = await _trending.fetchTrendingMovie();
        content.addAll(movies);
      }

      if (_discoverFilter == 'trending' || _discoverFilter == 'tv') {
        final shows = await _trending.fetchTrendingShow();
        content.addAll(shows);
      }

      if (_discoverFilter == 'trending') {
        content.shuffle();
      }

      // Filter out joined communities
      _discoverContent = content
          .where((item) => !myShowIds.contains(item.id))
          .take(10)
          .toList();
    } catch (e) {
      print('Error fetching discover content: $e');
    } finally {
      _isLoadingDiscover = false;
      notifyListeners();
    }
  }

  Future<void> fetchTrendingCommunities() async {
    _isLoadingTrending = true;
    notifyListeners();

    try {
      final results = await _communityService.discoverCommunities(limit: 10);
      _trendingCommunities = results.map((c) => Community.fromJson(c)).toList();
    } catch (e) {
      print('Error fetching trending communities: $e');
    } finally {
      _isLoadingTrending = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecommendedCommunities() async {
    _isLoadingRecommended = true;
    notifyListeners();

    try {
      // For now, recommendation is just more active communities but potentially different order/filter
      // In a real app, this would be based on user interests
      final results = await _communityService.discoverCommunities(limit: 15);
      final all = results.map((c) => Community.fromJson(c)).toList();

      // Filter out joined ones and trending ones to make it feel "recommended"
      final trendingIds = _trendingCommunities.map((c) => c.showId).toSet();
      final myIds = _myCommunities.map((c) => c.showId).toSet();

      _recommendedCommunities = all
          .where(
            (c) => !myIds.contains(c.showId) && !trendingIds.contains(c.showId),
          )
          .take(10)
          .toList();

      // If empty, just show some diverse ones
      if (_recommendedCommunities.isEmpty) {
        _recommendedCommunities = all
            .where((c) => !myIds.contains(c.showId))
            .take(10)
            .toList();
      }
    } catch (e) {
      print('Error fetching recommended communities: $e');
    } finally {
      _isLoadingRecommended = false;
      notifyListeners();
    }
  }

  void setDiscoverFilter(String filter) {
    if (_discoverFilter != filter) {
      _discoverFilter = filter;
      fetchDiscoverContent();
    }
  }

  // --- Single Community Details ---

  void clearCurrentCommunity() {
    _currentCommunity = null;
    _currentPosts = [];
    _isMemberOfCurrent = false;
    _currentUserVotes = {};
    _selectedHashtag = null;
    // Don't notify listeners here usually to avoid rebuilds during nav,
    // but if needed: notifyListeners();
  }

  Future<void> loadCommunityDetails(int showId, {String? sortBy}) async {
    _isLoadingCommunityDetails = true;
    // We might not want to clear previous immediately if we want to show stale data while loading
    // but for now let's be safe
    if (sortBy != null) _currentSortBy = sortBy;

    notifyListeners();

    try {
      // Fetch community info and posts in parallel
      final results = await Future.wait([
        _communityService.getCommunity(showId),
        _communityService.isMember(showId),
        _communityService.getPosts(showId: showId, sortBy: _currentSortBy),
      ]);

      final communityData = results[0] as Map<String, dynamic>?;
      final isMember = results[1] as bool;
      final postsData = results[2] as List<Map<String, dynamic>>;

      _currentCommunity = communityData != null
          ? Community.fromJson(communityData)
          : null;
      _isMemberOfCurrent = isMember;
      _currentPosts = postsData.map((p) => CommunityPost.fromJson(p)).toList();

      // Load votes in parallel
      final voteFutures = _currentPosts.map((post) async {
        final vote = await _communityService.getUserVote(post.id, showId);
        return MapEntry(post.id, vote);
      });

      final votes = await Future.wait(voteFutures);
      _currentUserVotes = Map.fromEntries(votes);
    } catch (e) {
      print('Error loading community details: $e');
    } finally {
      _isLoadingCommunityDetails = false;
      notifyListeners();
    }
  }

  Future<void> setSortBy(int showId, String sortBy) async {
    if (_currentSortBy != sortBy) {
      _currentSortBy = sortBy;
      await loadCommunityDetails(showId);
    }
  }

  /// Sets the hashtag filter and refreshes the post list
  void setHashtagFilter(String? tag) {
    if (_selectedHashtag == tag) return;
    _selectedHashtag = tag;
    notifyListeners();
  }

  Future<void> joinCommunity(int showId, Community? community) async {
    // Store previous state for revert on failure
    final wasMember = _isMemberOfCurrent;
    final previousMemberCount = _currentCommunity?.memberCount ?? 0;

    // Optimistic update
    _isMemberOfCurrent = true;
    if (_currentCommunity != null && _currentCommunity!.showId == showId) {
      _currentCommunity = _currentCommunity!.copyWith(
        memberCount: _currentCommunity!.memberCount + 1,
      );
    }

    // Optimistically add to myCommunities if we have the data
    if (community != null) {
      if (!_myCommunities.any((c) => c.showId == showId)) {
        _myCommunities.add(
          community.copyWith(memberCount: community.memberCount + 1),
        );
      }
    }
    notifyListeners();

    try {
      await _communityService.joinCommunity(showId);

      // On success, refresh list if community was null
      if (community == null) {
        fetchMyCommunities();
      }
    } catch (e) {
      // Revert optimistic update on failure
      _isMemberOfCurrent = wasMember;
      if (_currentCommunity != null && _currentCommunity!.showId == showId) {
        _currentCommunity = _currentCommunity!.copyWith(
          memberCount: previousMemberCount,
        );
      }
      _myCommunities.removeWhere((c) => c.showId == showId);
      notifyListeners();
      print('Error joining community: $e');
      rethrow;
    }
  }

  Future<void> leaveCommunity(int showId) async {
    await _communityService.leaveCommunity(showId);
    _isMemberOfCurrent = false;

    // Optimistically update current community member count
    if (_currentCommunity != null && _currentCommunity!.showId == showId) {
      _currentCommunity = _currentCommunity!.copyWith(
        memberCount: _currentCommunity!.memberCount - 1,
      );
    }

    // Remove from myCommunities
    _myCommunities.removeWhere((c) => c.showId == showId);

    // Refresh discover to potentially add it back
    // fetchDiscoverContent();

    notifyListeners();
  }

  Future<void> voteOnPost(String postId, int showId, int vote) async {
    final currentVote = _currentUserVotes[postId] ?? 0;
    final newVote = currentVote == vote ? 0 : vote;

    debugPrint(
      '[CommunityProvider] voteOnPost: postId=$postId, currentVote=$currentVote, newVote=$newVote',
    );

    // Optimistic update for immediate UI feedback
    _currentUserVotes[postId] = newVote;

    // Update the post score in the list locally for immediate feedback
    final index = _currentPosts.indexWhere((p) => p.id == postId);
    int? previousUpvotes;
    int? previousDownvotes;

    if (index != -1) {
      final post = _currentPosts[index];
      previousUpvotes = post.upvotes;
      previousDownvotes = post.downvotes;

      // Calculate deltas for optimistic update
      int upvoteDelta = 0;
      int downvoteDelta = 0;

      if (currentVote == 1) upvoteDelta -= 1;
      if (currentVote == -1) downvoteDelta -= 1;
      if (newVote == 1) upvoteDelta += 1;
      if (newVote == -1) downvoteDelta += 1;

      _currentPosts[index] = post.copyWith(
        upvotes: post.upvotes + upvoteDelta,
        downvotes: post.downvotes + downvoteDelta,
        score: post.score + (upvoteDelta - downvoteDelta),
      );
      debugPrint('[CommunityProvider] Optimistic update applied');
    }
    notifyListeners();

    try {
      if (_useVotingBackend) {
        // Use backend API (Supabase/Node.js)
        // We send the original 'vote' intent (1 or -1)
        // The server handles the toggle-off logic if vote == currentVote
        debugPrint('[CommunityProvider] Using voting backend API...');
        final result = await _votingApi.voteOnPost(postId, showId, vote);

        // Update with server values (source of truth)
        debugPrint('[CommunityProvider] Server response: $result');
        if (index != -1) {
          _currentPosts[index] = _currentPosts[index].copyWith(
            upvotes: result.upvotes,
            downvotes: result.downvotes,
            score: result.score,
          );
        }
        _currentUserVotes[postId] = result.userVote ?? 0;
        notifyListeners();
      } else {
        // Fallback to old Firestore method
        debugPrint('[CommunityProvider] Using Firestore directly (fallback)');
        final newVote = currentVote == vote ? 0 : vote;
        await _communityService.voteOnPost(
          postId: postId,
          showId: showId,
          vote: newVote,
        );
      }
    } catch (e) {
      // Revert optimistic update on failure
      debugPrint('[CommunityProvider] ❌ Vote failed: $e');
      _currentUserVotes[postId] = currentVote;

      if (index != -1 && previousUpvotes != null && previousDownvotes != null) {
        _currentPosts[index] = _currentPosts[index].copyWith(
          upvotes: previousUpvotes,
          downvotes: previousDownvotes,
          score: previousUpvotes - previousDownvotes,
        );
      }
      notifyListeners();

      // Log detailed error for debugging
      debugPrint('[CommunityProvider] Error details: ${e.toString()}');
      rethrow; // Let UI handle the error
    }
  }

  // --- Comments ---

  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _communityService.getCommentsStream(postId);
  }

  Future<void> addComment({
    required String postId,
    required int showId,
    required String content,
    String? parentId,
  }) async {
    await _communityService.addComment(
      postId: postId,
      showId: showId,
      content: content,
      parentId: parentId,
    );
    // Update comment count locally for immediate feedback if needed
    // reloadCommunityDetails(showId);
  }

  /// Vote on a comment with optimistic update
  Future<void> voteOnComment({
    required String commentId,
    required String postId,
    required int showId,
    required int vote,
  }) async {
    final currentVote = _commentVotes[commentId] ?? 0;
    final newVote = currentVote == vote ? 0 : vote;

    // Optimistic update
    _commentVotes[commentId] = newVote;
    notifyListeners();

    try {
      await _communityService.voteOnComment(
        commentId: commentId,
        postId: postId,
        showId: showId,
        vote: newVote,
      );
    } catch (e) {
      // Revert if failed
      _commentVotes[commentId] = currentVote;
      notifyListeners();
      print("Comment vote failed: $e");
    }
  }

  /// Get current user's vote on a comment (for initial load)
  int getCommentVote(String commentId) {
    return _commentVotes[commentId] ?? 0;
  }

  /// Load user's votes for a list of comments
  Future<void> loadCommentVotes(List<String> commentIds) async {
    for (final commentId in commentIds) {
      if (!_commentVotes.containsKey(commentId)) {
        final vote = await _communityService.getUserCommentVote(commentId);
        _commentVotes[commentId] = vote;
      }
    }
    notifyListeners();
  }

  Future<String?> createPost({
    required int showId,
    required String showTitle,
    String? posterPath,
    required String mediaType,
    required String content,
    List<XFile> mediaFiles = const [],
    List<String> hashtags = const [],
    bool isSpoiler = false,
    List<String> gifUrls = const [],
  }) async {
    List<String> mediaUrls = [];
    List<String> mediaTypes = [];

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    // Add GIFs directly to media lists
    for (final gifUrl in gifUrls) {
      mediaUrls.add(gifUrl);
      mediaTypes.add('image'); // GIFs are treated as images by the renderer
    }

    if (mediaFiles.isNotEmpty) {
      _isUploadingMedia = true;
      notifyListeners();

      try {
        for (final xFile in mediaFiles) {
          final file = File(xFile.path);
          final isVideo =
              file.path.endsWith('.mp4') ||
              file.path.endsWith('.mov') ||
              file.path.endsWith('.avi');

          final url = await _storageService.uploadCommunityMedia(
            showId.toString(),
            uid,
            file,
          );

          mediaUrls.add(url);
          mediaTypes.add(isVideo ? 'video' : 'image');
        }
      } catch (e) {
        print('Error uploading media for community post: $e');
        _isUploadingMedia = false;
        notifyListeners();
        rethrow;
      }

      _isUploadingMedia = false;
      notifyListeners();
    }

    return _communityService.createPost(
      showId: showId,
      showTitle: showTitle,
      posterPath: posterPath,
      mediaType: mediaType,
      content: content,
      mediaUrls: mediaUrls,
      mediaTypes: mediaTypes,
      hashtags: hashtags,
      isSpoiler: isSpoiler,
    );
  }

  /// Delete a post and remove it from the local list
  Future<bool> deletePost(String postId, int showId) async {
    final success = await _communityService.deletePost(postId, showId);
    if (success) {
      _currentPosts.removeWhere((p) => p.id == postId);
      notifyListeners();
    }
    return success;
  }

  /// Delete a community and remove it from the local list
  Future<bool> deleteCommunity(int showId) async {
    final success = await _communityService.deleteCommunity(showId);
    if (success) {
      _myCommunities.removeWhere((c) => c.showId == showId);
      if (_currentCommunity?.showId == showId) {
        clearCurrentCommunity();
      }
      notifyListeners();
      fetchMyCommunities(); // Refresh list to be sure
    }
    return success;
  }

  Future<CommunityPost?> getPost(String postId) async {
    try {
      final postData = await _communityService.getPost(postId);
      if (postData == null) return null;
      return CommunityPost.fromJson(postData);
    } catch (e) {
      print('Error fetching post: $e');
      return null;
    }
  }
}
