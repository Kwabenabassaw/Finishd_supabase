import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/models/report_model.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Helper to get current user ID or throw error
  String get _currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Must be logged in to submit a report');
    }
    return user.id;
  }

  // ===========================================================================
  // PUBLIC METHODS
  // ===========================================================================

  /// Report a Community Post
  Future<void> reportCommunityPost({
    required String postId,
    required String communityId,
    required String authorId,
    required ReportReason reason,
    String? additionalInfo,
  }) async {
    // 1. Check duplicate
    if (await hasUserReported(postId, ReportType.communityPost)) {
      throw Exception('You have already reported this post');
    }

    // 2. Fetch content snapshot (from Supabase post table)
    final postResponse = await _supabase
        .from('community_posts')
        .select()
        .eq('id', postId)
        .maybeSingle();

    if (postResponse == null) throw Exception('Post not found');

    final snapshot = ContentSnapshot(
      text: postResponse['content'],
      mediaUrls: postResponse['media_urls'] != null
          ? List<String>.from(postResponse['media_urls'])
          : null,
      authorName: null, // Ideally fetch from profiles join
      createdAt: postResponse['created_at'] != null
          ? DateTime.parse(postResponse['created_at'])
          : null,
    );

    // 3. Create Report
    await _createReport(
      type: ReportType.communityPost,
      reason: reason,
      reportedContentId: postId,
      reportedUserId: authorId,
      communityId: communityId,
      additionalInfo: additionalInfo,
      contentSnapshot: snapshot,
    );
  }

  /// Report a Community Comment
  Future<void> reportCommunityComment({
    required String commentId,
    required String postId,
    required String communityId, // showId as string
    required String authorId,
    required ReportReason reason,
    String? additionalInfo,
  }) async {
    if (await hasUserReported(commentId, ReportType.communityComment)) {
      throw Exception('You have already reported this comment');
    }

    final commentResponse = await _supabase
        .from('community_comments')
        .select()
        .eq('id', commentId)
        .maybeSingle();

    if (commentResponse == null) throw Exception('Comment not found');

    final snapshot = ContentSnapshot(
      text: commentResponse['content'],
      authorName: null,
      createdAt: commentResponse['created_at'] != null
          ? DateTime.parse(commentResponse['created_at'])
          : null,
    );

    await _createReport(
      type: ReportType.communityComment,
      reason: reason,
      reportedContentId: commentId,
      reportedUserId: authorId,
      communityId: communityId,
      additionalInfo: additionalInfo,
      contentSnapshot: snapshot,
    );
  }

  /// Report a Chat Message
  Future<void> reportChatMessage({
    required String messageId,
    required String chatId,
    required String senderId,
    required ReportReason reason,
    String? additionalInfo,
  }) async {
    if (await hasUserReported(messageId, ReportType.chatMessage)) {
      throw Exception('You have already reported this message');
    }

    final messageResponse = await _supabase
        .from('messages')
        .select()
        .eq('id', messageId)
        .maybeSingle();

    if (messageResponse == null) throw Exception('Message not found');

    final snapshot = ContentSnapshot(
      text: messageResponse['content'],
      mediaUrls:
          messageResponse['media_url'] != null &&
              messageResponse['media_url'].toString().isNotEmpty
          ? [messageResponse['media_url']]
          : null,
      createdAt: messageResponse['created_at'] != null
          ? DateTime.parse(messageResponse['created_at'])
          : null,
    );

    await _createReport(
      type: ReportType.chatMessage,
      reason: reason,
      reportedContentId: messageId,
      reportedUserId: senderId,
      chatId: chatId,
      additionalInfo: additionalInfo,
      contentSnapshot: snapshot,
    );
  }

  /// Check if user has already reported this content
  Future<bool> hasUserReported(String contentId, ReportType type) async {
    final response = await _supabase
        .from('reports')
        .select()
        .eq('reported_by', _currentUserId)
        .eq('reported_content_id', contentId)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  /// Get reports submitted by current user
  Future<List<Report>> getUserReports() async {
    final response = await _supabase
        .from('reports')
        .select()
        .eq('reported_by', _currentUserId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Report.fromJson(json)).toList();
  }

  // ===========================================================================
  // INTERNAL LOGIC
  // ===========================================================================

  Future<void> _createReport({
    required ReportType type,
    required ReportReason reason,
    required String reportedContentId,
    required String reportedUserId,
    String? communityId,
    String? chatId,
    String? additionalInfo,
    required ContentSnapshot contentSnapshot,
  }) async {
    final uid = _currentUserId;

    // Calculate severity
    final severity = _calculateSeverity(reason);
    final weight = _calculateReportWeight(reason);

    // Create Report in Supabase
    await _supabase.from('reports').insert({
      'type': type.name,
      'reason': reason.name,
      'reported_content_id': reportedContentId,
      'reported_by': uid,
      'reported_user_id': reportedUserId,
      'community_id': communityId,
      'chat_id': chatId,
      'additional_info': additionalInfo,
      'content_snapshot': contentSnapshot.toJson(),
      'report_weight': weight,
      'severity': severity,
      'status': 'pending',
    });
  }

  String _calculateSeverity(ReportReason reason) {
    switch (reason) {
      case ReportReason.harassment:
      case ReportReason.hate:
      case ReportReason.inappropriate:
        return 'high';
      case ReportReason.spam:
      case ReportReason.misinformation:
        return 'medium';
      default:
        return 'low';
    }
  }

  double _calculateReportWeight(ReportReason reason) {
    double weight = 1.0;

    // Severity multiplier
    if (_calculateSeverity(reason) == 'high') weight += 2.0;
    if (_calculateSeverity(reason) == 'medium') weight += 1.0;

    return weight;
  }
}
