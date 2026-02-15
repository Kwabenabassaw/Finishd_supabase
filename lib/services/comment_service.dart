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
    // Note: userName and userAvatar are currently not in video_comments table,
    // they should be joined from profiles if needed, or we keep them in CommentData
    // as it's a UI model.
    return CommentData.fromJson(response);
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
