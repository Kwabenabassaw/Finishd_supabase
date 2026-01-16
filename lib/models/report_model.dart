import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of content being reported
enum ReportType { communityPost, communityComment, chatMessage }

/// Reason for the report
enum ReportReason {
  spam, // Unwanted commercial content
  harassment, // Bullying, threats
  inappropriate, // NSFW, violence
  misinformation, // False information
  copyright, // IP violations
  hate, // Hate speech
  other, // User-defined
}

/// Status of the report workflow
enum ReportStatus { pending, reviewed, actioned, dismissed }

/// Snapshot of the content at the time of reporting
/// Allows admins to view content even if it's deleted later
class ContentSnapshot {
  final String? text;
  final List<String>? mediaUrls;
  final String? authorName;
  final DateTime? createdAt;

  ContentSnapshot({this.text, this.mediaUrls, this.authorName, this.createdAt});

  Map<String, dynamic> toJson() {
    return {
      if (text != null) 'text': text,
      if (mediaUrls != null) 'mediaUrls': mediaUrls,
      if (authorName != null) 'authorName': authorName,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  factory ContentSnapshot.fromJson(Map<String, dynamic> json) {
    return ContentSnapshot(
      text: json['text'],
      mediaUrls: json['mediaUrls'] != null
          ? List<String>.from(json['mediaUrls'])
          : null,
      authorName: json['authorName'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

/// Main Report model
class Report {
  final String id;
  final ReportType type;
  final ReportReason reason;
  final String reportedContentId;
  final String reportedBy;
  final String reportedUserId; // Author of reported content

  // Context fields
  final String? communityId; // For community posts/comments
  final String? chatId; // For chat messages

  final String? additionalInfo; // User explanation
  final ContentSnapshot contentSnapshot;

  // Aggregation & Scoring
  final int reportCount; // Total reports for this content
  final double reportWeight; // Weighted score (1.0 - 10.0)
  final String severity; // 'low', 'medium', 'high'

  final ReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Report({
    required this.id,
    required this.type,
    required this.reason,
    required this.reportedContentId,
    required this.reportedBy,
    required this.reportedUserId,
    this.communityId,
    this.chatId,
    this.additionalInfo,
    required this.contentSnapshot,
    this.reportCount = 1,
    this.reportWeight = 1.0,
    this.severity = 'low',
    this.status = ReportStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'reason': reason.name,
      'reportedContentId': reportedContentId,
      'reportedBy': reportedBy,
      'reportedUserId': reportedUserId,
      if (communityId != null) 'communityId': communityId,
      if (chatId != null) 'chatId': chatId,
      if (additionalInfo != null) 'additionalInfo': additionalInfo,
      'contentSnapshot': contentSnapshot.toJson(),
      'reportCount': reportCount,
      'reportWeight': reportWeight,
      'severity': severity,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Report.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      type: ReportType.values.byName(data['type'] ?? 'communityPost'),
      reason: ReportReason.values.byName(data['reason'] ?? 'other'),
      reportedContentId: data['reportedContentId'] ?? '',
      reportedBy: data['reportedBy'] ?? '',
      reportedUserId: data['reportedUserId'] ?? '',
      communityId: data['communityId'],
      chatId: data['chatId'],
      additionalInfo: data['additionalInfo'],
      contentSnapshot: ContentSnapshot.fromJson(
        data['contentSnapshot'] as Map<String, dynamic>? ?? {},
      ),
      reportCount: data['reportCount'] ?? 1,
      reportWeight: (data['reportWeight'] ?? 1.0).toDouble(),
      severity: data['severity'] ?? 'low',
      status: ReportStatus.values.byName(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
