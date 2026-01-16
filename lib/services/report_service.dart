import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/models/report_model.dart';
import 'package:finishd/Model/community_models.dart';
import 'package:finishd/models/message_model.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection References
  CollectionReference get _reportsRef => _db.collection('reports');
  CollectionReference get _auditLogsRef => _db.collection('audit_logs');
  CollectionReference get _communityPostsRef =>
      _db.collection('community_posts');
  CollectionReference get _communityCommentsRef =>
      _db.collection('community_comments');

  // Helper to get current user ID or throw error
  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Must be logged in to submit a report');
    }
    return user.uid;
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
    final uid = _currentUserId;

    // 1. Check duplicate
    if (await hasUserReported(postId, ReportType.communityPost)) {
      throw Exception('You have already reported this post');
    }

    // 2. Fetch content snapshot
    final postSnapshot = await _db
        .collection('community_posts')
        .doc(postId)
        .get();
    if (!postSnapshot.exists) throw Exception('Post not found');

    final data = postSnapshot.data() as Map<String, dynamic>;
    final snapshot = ContentSnapshot(
      text: data['content'],
      mediaUrls: data['mediaUrls'] != null
          ? List<String>.from(data['mediaUrls'])
          : null,
      authorName: data['authorName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
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
    final uid = _currentUserId;

    if (await hasUserReported(commentId, ReportType.communityComment)) {
      throw Exception('You have already reported this comment');
    }

    final commentDoc = await _db
        .collection('community_comments')
        .doc(commentId)
        .get();
    if (!commentDoc.exists) throw Exception('Comment not found');

    final data = commentDoc.data() as Map<String, dynamic>;
    final snapshot = ContentSnapshot(
      text: data['content'],
      authorName: data['authorName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
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
    final uid = _currentUserId;

    if (await hasUserReported(messageId, ReportType.chatMessage)) {
      throw Exception('You have already reported this message');
    }

    final messageDoc = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .get();

    if (!messageDoc.exists) throw Exception('Message not found');

    final data = messageDoc.data() as Map<String, dynamic>;
    final snapshot = ContentSnapshot(
      text: data['text'],
      mediaUrls:
          data['mediaUrl'] != null && data['mediaUrl'].toString().isNotEmpty
          ? [data['mediaUrl']]
          : null,
      createdAt: (data['timestamp'] as Timestamp?)?.toDate(),
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
    final query = await _reportsRef
        .where('reportedBy', isEqualTo: _currentUserId)
        .where('reportedContentId', isEqualTo: contentId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  /// Get reports submitted by current user
  Future<List<Report>> getUserReports() async {
    final query = await _reportsRef
        .where('reportedBy', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs.map((doc) => Report.fromDocument(doc)).toList();
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
    final timestamp = DateTime.now();

    // Calculate severity
    final severity = _calculateSeverity(reason);
    final weight = _calculateReportWeight(reason);

    // Run transaction
    await _db.runTransaction((transaction) async {
      // 1. Create Report Document
      final newReportRef = _reportsRef.doc();
      final report = Report(
        id: newReportRef.id,
        type: type,
        reason: reason,
        reportedContentId: reportedContentId,
        reportedBy: uid,
        reportedUserId: reportedUserId,
        communityId: communityId,
        chatId: chatId,
        additionalInfo: additionalInfo,
        contentSnapshot: contentSnapshot,
        reportWeight: weight,
        severity: severity,
        status: ReportStatus.pending,
        createdAt: timestamp,
        updatedAt: timestamp,
      );

      transaction.set(newReportRef, report.toJson());

      // 2. Check for Auto-Moderation (Optional: could be Cloud Function)
      // For client-side, we can just aggregate weights if we query other reports.
      // But purely client-side aggregation is expensive/insecure without Cloud Functions.
      // We will implement a simplified check:
      // If this is a high-severity report, flag it.

      // NOTE: Real auto-moderation threshold logic (3 reports -> hide) is best done
      // via Cloud Functions to avoid race conditions and client trust issues.
      // However, we can update a 'report_stats' subcollection or field on the content
      // if security rules allow it.

      // For now, we'll leave actual content hiding to the Admin Dashboard
      // or a future Cloud Function as per architectural best practices.
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
