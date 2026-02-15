import 'package:flutter/material.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/services/community_service.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:finishd/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';

/// Encapsulates the state for Comms search to ensure determinism
class CommsSearchState {
  final String query;
  final bool isSearching;
  final List<MediaItem> results;
  final int lastRequestId;

  CommsSearchState({
    this.query = '',
    this.isSearching = false,
    this.results = const [],
    this.lastRequestId = 0,
  });

  CommsSearchState copyWith({
    String? query,
    bool? isSearching,
    List<MediaItem>? results,
    int? lastRequestId,
  }) {
    return CommsSearchState(
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      lastRequestId: lastRequestId ?? this.lastRequestId,
    );
  }
}

class CommunityProvider extends ChangeNotifier {
  final CommunityService _communityService = CommunityService();
  final Trending _trending = Trending();
  final StorageService _storageService = StorageService();

  bool _isUploadingMedia = false;
  String? _selectedHashtag;
  bool get isUploadingMedia => _isUploadingMedia;
  String? get selectedHashtag => _selectedHashtag;

  // My Communities
  List<Community> _myCommunities = [];
  bool _isLoadingMyCommunities = false;
  Set<int> _mutedCommunityIds = {};

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
  // Keyed by Post ID to prevent duplicates
  final Map<String, CommunityPost> _postsMap = {};
  List<CommunityPost> _currentPosts = [];
  bool _isLoadingCommunityDetails = false;
  bool _isMemberOfCurrent = false;
  String _currentSortBy = 'createdAt';
  String _searchQuery = '';
  Map<String, int> _currentUserVotes = {}; // postId -> vote

  final Map<String, int> _commentVotes = {}; // commentId -> vote
  String? _currentUserRole; // 'admin', 'moderator', or null

  // Real-time listener for posts
  StreamSubscription<List<Map<String, dynamic>>>? _postsSubscription;

  // Getters
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
  String get searchQuery => _searchQuery;
  Map<String, int> get currentUserVotes => _currentUserVotes;

  String? get currentUserRole => _currentUserRole;
  bool get isModerator =>
      _currentUserRole == 'moderator' || _currentUserRole == 'admin';
  bool get isAdmin => _currentUserRole == 'admin';

  String? get currentUid => Supabase.instance.client.auth.currentUser?.id;

  /// Returns sorted and filtered posts (by hashtag if selected)
  List<CommunityPost> get filteredPosts {
    if (_selectedHashtag == null || _selectedHashtag!.isEmpty) {
      return _currentPosts;
    }
    return _currentPosts
        .where((post) => post.hashtags.contains(_selectedHashtag))
        .toList();
  }

  /// Returns Trending Communities filtered by search query
  List<Community> get filteredTrendingCommunities {
    if (_searchQuery.isEmpty) return _trendingCommunities;

    final query = _searchQuery.toLowerCase();

    // Filter by prefix (startsWith)
    final filtered = _trendingCommunities
        .where((c) => c.title.toLowerCase().startsWith(query))
        .toList();

    // Sort by: 1. Popularity (memberCount) DESC, 2. Alphabetical ASC
    filtered.sort((a, b) {
      if (a.memberCount != b.memberCount) {
        return b.memberCount.compareTo(a.memberCount); // Popularity DESC
      }
      return a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ); // Alpha ASC
    });

    return filtered;
  }

  /// Returns Recommended Communities filtered by search query
  List<Community> get filteredRecommendedCommunities {
    if (_searchQuery.isEmpty) return _recommendedCommunities;
    final query = _searchQuery.toLowerCase();
    return _recommendedCommunities
        .where((c) => c.title.toLowerCase().startsWith(query))
        .toList();
  }

  /// Placeholder for trending hashtags in a community
  List<String> get trendingHashtags {
    if (_currentPosts.isEmpty) return [];
    final Map<String, int> counts = {};
    for (var post in _currentPosts) {
      for (var tag in post.hashtags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    var sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  // ...

  // Deterministic search state
  CommsSearchState _searchState = CommsSearchState();
  CommsSearchState get searchState => _searchState;

  // --- Collection Fetches ---

  Future<void> fetchMyCommunities() async {
    _isLoadingMyCommunities = true;
    notifyListeners();
    try {
      final data = await _communityService.getMyCommunities();
      _myCommunities = data.map((json) => Community.fromJson(json)).toList();
      loadMutedCommunities();
    } catch (e) {
      debugPrint('Error fetching my communities: $e');
    } finally {
      _isLoadingMyCommunities = false;
      notifyListeners();
    }
  }

  Future<void> fetchTrendingCommunities() async {
    _isLoadingTrending = true;
    notifyListeners();
    try {
      final data = await _communityService.discoverCommunities(limit: 10);
      _trendingCommunities = data
          .map((json) => Community.fromJson(json))
          .toList();
    } finally {
      _isLoadingTrending = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecommendedCommunities() async {
    _isLoadingRecommended = true;
    notifyListeners();
    try {
      // For now, same as trending or some logic
      final data = await _communityService.discoverCommunities(limit: 10);
      _recommendedCommunities = data
          .map((json) => Community.fromJson(json))
          .toList();
    } finally {
      _isLoadingRecommended = false;
      notifyListeners();
    }
  }

  Future<void> fetchDiscoverContent({String? filter}) async {
    if (filter != null) _discoverFilter = filter;
    _isLoadingDiscover = true;
    notifyListeners();
    try {
      List<MediaItem> results;
      if (_discoverFilter == 'tv') {
        results = await _trending.fetchTrendingShow();
      } else if (_discoverFilter == 'movie') {
        results = await _trending.fetchTrendingMovie();
      } else {
        // Combined
        final shows = await _trending.fetchTrendingShow();
        final movies = await _trending.fetchTrendingMovie();
        results = [...shows, ...movies]..shuffle();
      }
      _discoverContent = results;
    } catch (e) {
      debugPrint('Error fetching discover content: $e');
    } finally {
      _isLoadingDiscover = false;
      notifyListeners();
    }
  }

  void setDiscoverFilter(String filter) {
    if (_discoverFilter == filter) return;
    _discoverFilter = filter;
    fetchDiscoverContent();
  }

  // --- Search Logic ---

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchState = CommsSearchState();
    notifyListeners();
  }

  Future<void> searchCommunities(String query) async {
    final requestId = DateTime.now().millisecondsSinceEpoch;
    _searchState = _searchState.copyWith(
      query: query,
      isSearching: true,
      lastRequestId: requestId,
    );
    notifyListeners();

    try {
      // Use Trending service to search media (to find shows/movies to start a community for)
      final results = await _trending.searchMedia(query);

      // Ensure we only update if this is the latest request
      if (_searchState.lastRequestId == requestId) {
        _searchState = _searchState.copyWith(
          results: results,
          isSearching: false,
        );
      }
    } catch (e) {
      debugPrint('Error searching communities: $e');
      if (_searchState.lastRequestId == requestId) {
        _searchState = _searchState.copyWith(isSearching: false);
      }
    } finally {
      notifyListeners();
    }
  }

  // --- Single Community Details ---

  void clearCurrentCommunity() {
    _currentCommunity = null;
    _postsMap.clear();
    _currentPosts = [];
    _isMemberOfCurrent = false;

    _currentUserRole = null;
    _currentUserVotes = {};
    _selectedHashtag = null;
    _stopPostsStream();
  }

  Future<void> loadCommunityDetails(int showId, {String? sortBy}) async {
    _isLoadingCommunityDetails = true;
    if (sortBy != null) _currentSortBy = sortBy;

    // Clear previous state to avoid cross-contamination
    _postsMap.clear();
    _currentPosts = [];
    notifyListeners();

    try {
      // Fetch community info and membership status
      final results = await Future.wait([
        _communityService.getCommunity(showId),
        _communityService.getMemberRole(showId),
      ]);

      final communityData = results[0] as Map<String, dynamic>?;
      final role = results[1] as String?;

      _currentCommunity = communityData != null
          ? Community.fromJson(communityData)
          : null;
      _currentUserRole = role;
      _isMemberOfCurrent = role != null;

      // Start listening to posts stream for real-time updates
      _listenToPostsStream(showId);

      // Note: We can't load votes here for _currentPosts because they are empty initially.
      // We will load votes incrementally as posts arrive or in batches.
    } catch (e) {
      print('Error loading community details: $e');
    } finally {
      _isLoadingCommunityDetails = false;
      notifyListeners();
    }
  }

  /// Listen to real-time posts stream
  void _listenToPostsStream(int showId) {
    // Cancel any existing subscription
    _postsSubscription?.cancel();

    print(
      '🔄 [CommunityProvider] Starting real-time listener for showId: $showId',
    );

    _postsSubscription = _communityService
        .getPostsStream(showId: showId, limit: 50)
        .listen(
          (postsData) async {
            print(
              '📡 [CommunityProvider] Received ${postsData.length} posts from stream',
            );

            // 1. Collect Author IDs
            final List<String> authorIds = [];
            for (final data in postsData) {
              if (data['author_id'] != null) {
                authorIds.add(data['author_id'] as String);
              }
            }

            // 2. Fetch Profiles for these authors
            final profilesMap = await _communityService.getProfiles(authorIds);

            // 3. Process incoming posts and merge with profile data
            for (final data in postsData) {
              // Inject author data from profilesMap into the JSON before parsing
              final authorId = data['author_id'];
              if (authorId != null && profilesMap.containsKey(authorId)) {
                final profile = profilesMap[authorId]!;
                data['author_name'] = profile['username'];
                data['author_avatar'] = profile['avatar_url'];
                // print('✅ Hydrated post ${data['id']} with author: ${profile['username']}');
              } else {
                print(
                  '⚠️ Failed to hydrate post ${data['id']} (Author ID: $authorId)',
                );
              }

              final post = CommunityPost.fromJson(data);
              // Insert or update logic: Always take the latest from server
              _postsMap[post.id] = post;
            }

            // 4. Re-derive the sorted list
            _rebuildPostsList();

            // 5. Load votes for new posts (optimization: only for new ones)
            _loadVotesForCurrentPosts(showId);

            notifyListeners();
          },
          onError: (error) {
            print('❌ [CommunityProvider] Error in posts stream: $error');
          },
        );
  }

  void _rebuildPostsList() {
    final list = _postsMap.values.toList();

    // Check sort order
    if (_currentSortBy == 'top') {
      list.sort((a, b) => b.score.compareTo(a.score));
    } else {
      // Default: createdAt descending (newest first)
      list.sort(
        (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
          a.createdAt ?? DateTime.now(),
        ),
      );
    }

    _currentPosts = list;
  }

  Future<void> _loadVotesForCurrentPosts(int showId) async {
    if (_currentPosts.isEmpty) return;
    try {
      final voteFutures = _currentPosts
          .where(
            (p) => !_currentUserVotes.containsKey(p.id),
          ) // Only fetch unknown
          .map((post) async {
            final vote = await _communityService.getUserVote(post.id, showId);
            return MapEntry(post.id, vote);
          });

      if (voteFutures.isNotEmpty) {
        final votes = await Future.wait(voteFutures);
        _currentUserVotes.addAll(Map.fromEntries(votes));
        notifyListeners(); // Notify again if votes changed
      }
    } catch (e) {
      print('Error loading votes: $e');
    }
  }

  /// Stop listening to posts stream
  void _stopPostsStream() {
    _postsSubscription?.cancel();
    _postsSubscription = null;
    print('🛑 [CommunityProvider] Stopped posts stream');
  }

  @override
  void dispose() {
    _stopPostsStream();
    super.dispose();
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

  Future<void> loadMutedCommunities() async {
    final ids = await _communityService.getMutedCommunityIds();
    _mutedCommunityIds = ids.toSet();
    notifyListeners();
  }

  Future<void> muteCommunity(int showId, bool mute) async {
    // Optimistic
    if (mute) {
      _mutedCommunityIds.add(showId);
    } else {
      _mutedCommunityIds.remove(showId);
    }
    notifyListeners();

    try {
      await _communityService.muteCommunity(showId, mute);
    } catch (e) {
      print('Error muting community: $e');
      // Revert
      if (mute) {
        _mutedCommunityIds.remove(showId);
      } else {
        _mutedCommunityIds.add(showId);
      }
      notifyListeners();
    }
  }

  bool isMuted(int showId) => _mutedCommunityIds.contains(showId);

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
      // Use efficient Supabase RPC method directly
      await _communityService.voteOnPost(
        postId: postId,
        showId: showId,
        vote: newVote,
      );

      // No need to manually update from server response here;
      // the real-time stream listener in _listenToPostsStream
      // will receive the updated post data (upvotes/downvotes/score) automatically.
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

  // ==========================================================================
  // MODERATION ACTIONS
  // ==========================================================================

  Future<void> hidePost(String postId, bool hide) async {
    // Optimistic update
    final index = _currentPosts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final oldPost = _currentPosts[index];
      _currentPosts[index] = oldPost.copyWith(isHidden: hide);
      notifyListeners();

      try {
        await _communityService.hidePost(postId, hide);
      } catch (e) {
        // Revert
        _currentPosts[index] = oldPost;
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> lockPost(String postId, bool lock) async {
    // Optimistic update
    final index = _currentPosts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final oldPost = _currentPosts[index];
      _currentPosts[index] = oldPost.copyWith(isLocked: lock);
      notifyListeners();

      try {
        await _communityService.lockPost(postId, lock);
      } catch (e) {
        // Revert
        _currentPosts[index] = oldPost;
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> pinPost(String postId, bool pin) async {
    // Optimistic update
    final index = _currentPosts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final oldPost = _currentPosts[index];
      _currentPosts[index] = oldPost.copyWith(
        pinnedAt: pin ? DateTime.now() : null,
      );
      // If pinning, move to top? Or just rely on re-sort?
      // For now, just update the field.
      notifyListeners();

      try {
        await _communityService.pinPost(postId, pin);
      } catch (e) {
        // Revert
        _currentPosts[index] = oldPost;
        notifyListeners();
        rethrow;
      }
    }
  }

  // --- Comments ---

  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _communityService.getCommentsStream(postId).asyncMap((
      comments,
    ) async {
      if (comments.isEmpty) return comments;

      // Collect author IDs
      final authorIds = comments
          .map((c) => c['author_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      // Fetch profiles for these authors
      final profilesMap = await _communityService.getProfiles(authorIds);

      // Inject author data into each comment
      for (final comment in comments) {
        final authorId = comment['author_id'] as String?;
        if (authorId != null && profilesMap.containsKey(authorId)) {
          final profile = profilesMap[authorId]!;
          comment['author_name'] = profile['username'];
          comment['author_avatar'] = profile['avatar_url'];
        }
      }

      return comments;
    });
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

    final uid = Supabase.instance.client.auth.currentUser?.id;
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

    // OPTIMISTIC UI: Create temporary post and add to list immediately
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempPost = CommunityPost(
      id: tempId,
      showId: showId,
      showTitle: showTitle,
      communityId: showId.toString(),
      authorId: uid,
      authorName:
          Supabase
              .instance
              .client
              .auth
              .currentUser
              ?.userMetadata?['username'] ??
          'You',
      authorAvatar: Supabase
          .instance
          .client
          .auth
          .currentUser
          ?.userMetadata?['avatar_url'],
      content: content,
      mediaUrls: mediaUrls,
      mediaTypes: mediaTypes,
      hashtags: hashtags,
      isSpoiler: isSpoiler,
      isHidden: false,
      score: 0,
      upvotes: 0,
      downvotes: 0,
      commentCount: 0,
      createdAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
    );

    // Add to map and rebuild list for immediate UI update
    _postsMap[tempId] = tempPost;
    _rebuildPostsList();
    notifyListeners();

    print('✨ [CommunityProvider] Optimistic UI: Added temp post $tempId');

    try {
      // Create the actual post in Firestore
      final postId = await _communityService.createPost(
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

      if (postId != null) {
        print('✅ [CommunityProvider] Post created with ID: $postId');
        // Remove temp post and let the real-time listener handle the new post
        // OR manually swap it if we want instant ID consistency before the listener fires
        _postsMap.remove(tempId);
        _rebuildPostsList();
        notifyListeners();
      } else {
        // If post creation failed (but no exception), remove the temp post
        print('❌ [CommunityProvider] Post creation returned null ID');
        _postsMap.remove(tempId);
        _rebuildPostsList();
        notifyListeners();
      }

      return postId;
    } catch (e) {
      print('❌ [CommunityProvider] Post creation failed: $e');
      // Remove temp post on error
      _postsMap.remove(tempId);
      _rebuildPostsList();
      notifyListeners();
      rethrow;
    }
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
