import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/Model/comment_data.dart';

/// Service for managing video comments in Supabase
class CommentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Add a comment to a video
  Future<CommentData> addComment({
    required String videoId,
    required String userId,
    required String userName,
    String? userAvatar,
    required String text,
    String? parentId,
  }) async {
    final response = await _supabase
        .from('video_comments')
        .insert({
          'video_id': videoId,
          'author_id': userId,
          'content': text,
          'parent_id': parentId,
        })
        .select()
        .single();

    // Map response back to CommentData
    // Note: The insert response only returns the video_comments row, so we need to
    // explicitly supply the userName and userAvatar that we have on the client
    // so it doesn't show up as 'Anonymous' until refresh.
    final comment = CommentData.fromJson(response);
    return comment.copyWith(userName: userName, userAvatar: userAvatar);
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String videoId,
    required String commentId,
    String? parentId,
  }) async {
    await _supabase.from('video_comments').delete().eq('id', commentId);
  }

  /// Get paginated comments for a video
  Future<List<CommentData>> getComments({
    required String videoId,
    int limit = 20,
    dynamic
    startAfter, // Replaced DocumentSnapshot with dynamic for cursor if needed
    bool repliesOnly = false,
    String? parentId,
  }) async {
    try {
      var query = _supabase
          .from('video_comments')
          .select(
            '*, profiles!video_comments_author_id_fkey(username, avatar_url)',
          )
          .eq('video_id', videoId);

      if (repliesOnly && parentId != null) {
        query = query.eq('parent_id', parentId);
      } else if (!repliesOnly) {
        query = query.filter('parent_id', 'is', null);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((json) => CommentData.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  /// Stream comments for real-time updates
  Stream<List<CommentData>> getCommentsStream({
    required String videoId,
    int limit = 50,
  }) {
    return _supabase
        .from('video_comments')
        .stream(primaryKey: ['id'])
        .eq('video_id', videoId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data.map((json) => CommentData.fromJson(json)).toList());
  }

  /// Get comment count for a video (from denormalized counter)
  Future<int> getCommentCount(String videoId) async {
    try {
      final response = await _supabase
          .from('creator_videos')
          .select('comment_count')
          .eq('id', videoId)
          .maybeSingle();
      return (response?['comment_count'] ?? 0) as int;
    } catch (e) {
      return 0;
    }
  }

  /// Stream comment count for real-time updates
  Stream<int> getCommentCountStream(String videoId) {
    return _supabase
        .from('creator_videos')
        .stream(primaryKey: ['id'])
        .eq('id', videoId)
        .map(
          (data) =>
              data.isEmpty ? 0 : (data.first['comment_count'] ?? 0) as int,
        );
  }

  /// Get a single comment by ID
  Future<CommentData?> getComment({
    required String videoId,
    required String commentId,
  }) async {
    try {
      final response = await _supabase
          .from('video_comments')
          .select()
          .eq('id', commentId)
          .single();
      return CommentData.fromJson(response);
    } catch (e) {
      print('Error getting comment: $e');
      return null;
    }
  }
}
