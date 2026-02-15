import 'package:finishd/models/report_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing show-centric communities.
/// Refactored for Supabase Migration.
class CommunityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUid => _supabase.auth.currentUser?.id;

  // ==========================================================================
  // COMMUNITY CREATION (LAZY / ON-DEMAND)
  // ==========================================================================

  Future<Map<String, dynamic>> ensureCommunityExists({
    required int showId,
    required String title,
    required String? posterPath,
    required String mediaType,
  }) async {
    final existing = await _supabase
        .from('communities')
        .select()
        .eq('show_id', showId)
        .maybeSingle();

    if (existing != null) {
      return existing;
    }

    final response = await _supabase
        .from('communities')
        .insert({
          'show_id': showId,
          'title': title,
          'poster_path': posterPath,
          'media_type': mediaType,
          'created_by': _currentUid,
        })
        .select()
        .single();

    return response;
  }

  // ==========================================================================
  // POSTS
  // ==========================================================================

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
      final comm = await ensureCommunityExists(
        showId: showId,
        title: showTitle,
        posterPath: posterPath,
        mediaType: mediaType,
      );
      final commId = comm['id'];

      final response = await _supabase
          .from('community_posts')
          .insert({
            'community_id': commId,
            'show_id': showId,
            'author_id': _currentUid,
            'content': content,
            'media_urls': mediaUrls,
            'media_types': mediaTypes,
            'hashtags': hashtags,
            'is_spoiler': isSpoiler,
          })
          .select()
          .single();

      await joinCommunity(showId);

      return response['id'];
    } catch (e) {
      print('❌ Error creating post: $e');
      return null;
    }
  }

  // ==========================================================================
  // VOTING (RPC)
  // ==========================================================================

  Future<void> voteOnPost({
    required String postId,
    required int showId,
    required int vote,
  }) async {
    if (_currentUid == null) return;
    try {
      await _supabase.rpc(
        'vote_on_post',
        params: {'p_post_id': postId, 'p_vote': vote},
      );
    } catch (e) {
      print('❌ Error voting on post: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // MEMBERSHIP (RPC)
  // ==========================================================================

  Future<void> joinCommunity(int showId) async {
    if (_currentUid == null) return;
    try {
      await _supabase.rpc('join_community', params: {'p_show_id': showId});
    } catch (e) {
      print('❌ Error joining community: $e');
    }
  }

  Future<void> leaveCommunity(int showId) async {
    if (_currentUid == null) return;
    try {
      await _supabase.rpc('leave_community', params: {'p_show_id': showId});
    } catch (e) {
      print('❌ Error leaving community: $e');
    }
  }

  // ==========================================================================
  // DISCOVERY
  // ==========================================================================

  Future<List<Map<String, dynamic>>> discoverCommunities({
    int limit = 20,
    String? mediaTypeFilter,
  }) async {
    // Correct Chaining: Filters FIRST, then Modifiers
    var query = _supabase.from('communities').select();

    query = query.gt('post_count', 0);

    if (mediaTypeFilter != null) {
      query = query.eq('media_type', mediaTypeFilter);
    }

    // Apply order and limit at the end
    final response = await query
        .order('post_count', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==========================================================================
  // READS
  // ==========================================================================

  Future<Map<String, dynamic>?> getCommunity(int showId) async {
    final response = await _supabase
        .from('communities')
        .select()
        .eq('show_id', showId)
        .maybeSingle();
    return response;
  }

  Stream<List<Map<String, dynamic>>> getPostsStream({
    required int showId,
    int limit = 20,
  }) {
    return _supabase
        .from('community_posts')
        .stream(primaryKey: ['id'])
        .eq('show_id', showId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<bool> deleteCommunity(int showId) async {
    try {
      await _supabase.from('communities').delete().eq('show_id', showId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPost(String postId) async {
    final response = await _supabase
        .from('community_posts')
        .select()
        .eq('id', postId)
        .maybeSingle();
    return response;
  }

  Future<void> voteOnComment({
    required String commentId,
    required String postId,
    required int showId,
    required int vote,
  }) async {
    if (_currentUid == null) return;
    int newVote = vote;
    // In V3 schema, we use strict upsert/delete on `comment_votes` table
    if (newVote == 0) {
      await _supabase.from('comment_votes').delete().match({
        'user_id': _currentUid!,
        'comment_id': commentId,
      });
    } else {
      await _supabase.from('comment_votes').upsert({
        'user_id': _currentUid,
        'comment_id': commentId,
        'vote': newVote,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<int> getUserCommentVote(String commentId) async {
    if (_currentUid == null) return 0;
    final response = await _supabase
        .from('comment_votes')
        .select('vote')
        .eq('user_id', _currentUid!)
        .eq('comment_id', commentId)
        .maybeSingle();
    return response?['vote'] as int? ?? 0;
  }

  Future<String?> addComment({
    required String postId,
    required int showId,
    required String content,
    String? parentId,
  }) async {
    if (_currentUid == null) return null;
    final response = await _supabase
        .from('community_comments')
        .insert({
          'post_id': postId,
          'author_id': _currentUid,
          'content': content,
          'parent_id': parentId,
        })
        .select()
        .single();
    return response['id'];
  }

  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _supabase
        .from('community_comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true);
  }

  Future<bool> deletePost(String postId, int showId) async {
    try {
      // Soft delete by setting is_hidden = true (or actually delete if policy allows)
      // For now, let's try strict delete, but usually we want soft delete
      await _supabase.from('community_posts').delete().eq('id', postId);
      return true;
    } catch (e) {
      print('Error deleting post: $e');
      return false;
    }
  }

  // ==========================================================================
  // MODERATION ACTIONS
  // ==========================================================================

  Future<void> reportContent({
    required ReportType type,
    required ReportReason reason,
    required String contentId,
    required String reportedUserId,
    String? additionalInfo,
    String? communityId,
    Map<String, dynamic>? contentSnapshot,
  }) async {
    if (_currentUid == null) return;

    try {
      await _supabase.from('reports').insert({
        'type': type.name,
        'reason': reason.name,
        'reported_content_id': contentId,
        'reported_by': _currentUid,
        'reported_user_id': reportedUserId,
        'community_id': communityId,
        'additional_info': additionalInfo,
        'content_snapshot': contentSnapshot ?? {},
        'status': 'pending',
        'severity': 'low', // Default, backend trigger can update this
        'report_weight': 1.0,
      });
    } catch (e) {
      print('❌ Error reporting content: $e');
      rethrow;
    }
  }

  Future<void> muteCommunity(int showId, bool mute) async {
    if (_currentUid == null) return;
    final community = await getCommunity(showId);
    if (community == null) return;

    try {
      await _supabase
          .from(
            'community_members',
          ) // Assuming this table links users to communities
          .update({'is_muted': mute})
          .match({'community_id': community['id'], 'user_id': _currentUid!});
    } catch (e) {
      print('Error muting community: $e');
      rethrow;
    }
  }

  Future<List<int>> getMutedCommunityIds() async {
    if (_currentUid == null) return [];
    try {
      final response = await _supabase
          .from('community_members')
          .select('communities(show_id)')
          .eq('user_id', _currentUid!)
          .eq('is_muted', true);

      final List<int> ids = [];
      for (final row in response) {
        final comm = row['communities'];
        if (comm != null && comm['show_id'] != null) {
          ids.add(comm['show_id'] as int);
        }
      }
      return ids;
    } catch (e) {
      print('Error fetching muted communities: $e');
      return [];
    }
  }

  Future<void> hidePost(String postId, bool hide) async {
    await _supabase
        .from('community_posts')
        .update({'is_hidden': hide})
        .eq('id', postId);
  }

  Future<void> lockPost(String postId, bool lock) async {
    await _supabase
        .from('community_posts')
        .update({'is_locked': lock})
        .eq('id', postId);
  }

  Future<void> pinPost(String postId, bool pin) async {
    await _supabase
        .from('community_posts')
        .update({'pinned_at': pin ? DateTime.now().toIso8601String() : null})
        .eq('id', postId);
  }

  Future<String?> getMemberRole(int showId) async {
    if (_currentUid == null) return null;
    final community = await getCommunity(showId);
    if (community == null) return null;
    final response = await _supabase
        .from('community_members')
        .select('role')
        .eq('community_id', community['id'])
        .eq('user_id', _currentUid!)
        .maybeSingle();
    return response?['role'] as String?;
  }

  Future<bool> isMember(int showId) async {
    final role = await getMemberRole(showId);
    return role != null;
  }

  Future<List<Map<String, dynamic>>> getMyCommunities() async {
    if (_currentUid == null) return [];
    final response = await _supabase
        .from('community_members')
        .select('communities(*)')
        .eq('user_id', _currentUid!);
    return (response as List)
        .map((e) => e['communities'] as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPosts({
    required int showId,
    int limit = 20,
  }) async {
    final response = await _supabase
        .from('community_posts')
        .select()
        .eq('show_id', showId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<int> getUserVote(String postId, int showId) async {
    if (_currentUid == null) return 0;
    final response = await _supabase
        .from('post_votes')
        .select('vote')
        .eq('user_id', _currentUid!)
        .eq('post_id', postId)
        .maybeSingle();
    return response?['vote'] as int? ?? 0;
  }

  Future<Map<String, Map<String, dynamic>>> getProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};
    final uniqueIds = userIds.toSet().toList();
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, avatar_url')
          .inFilter('id', uniqueIds); // Use inFilter for list matching

      print(
        '👤 [CommunityService] Fetched ${response.length} profiles for hydration',
      );

      final Map<String, Map<String, dynamic>> profiles = {};
      for (final p in response) {
        profiles[p['id'] as String] = p;
      }
      return profiles;
    } catch (e) {
      print('Error fetching profiles: $e');
      return {};
    }
  }
}
