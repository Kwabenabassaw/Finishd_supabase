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
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
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
          ? DateTime.parse(json['createdAt'])
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
      'reported_content_id': reportedContentId,
      'reported_by': reportedBy,
      'reported_user_id': reportedUserId,
      if (communityId != null) 'community_id': communityId,
      if (chatId != null) 'chat_id': chatId,
      if (additionalInfo != null) 'additional_info': additionalInfo,
      'content_snapshot': contentSnapshot.toJson(),
      'report_weight': reportWeight,
      'severity': severity,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id']?.toString() ?? '',
      type: ReportType.values.byName(json['type'] ?? 'communityPost'),
      reason: ReportReason.values.byName(json['reason'] ?? 'other'),
      reportedContentId:
          json['reported_content_id'] ?? json['reportedContentId'] ?? '',
      reportedBy: json['reported_by'] ?? json['reportedBy'] ?? '',
      reportedUserId: json['reported_user_id'] ?? json['reportedUserId'] ?? '',
      communityId: json['community_id'] ?? json['communityId'],
      chatId: json['chat_id'] ?? json['chatId'],
      additionalInfo: json['additional_info'] ?? json['additionalInfo'],
      contentSnapshot: ContentSnapshot.fromJson(
        json['content_snapshot'] as Map<String, dynamic>? ??
            json['contentSnapshot'] as Map<String, dynamic>? ??
            {},
      ),
      reportCount: json['reportCount'] ?? 1,
      reportWeight: (json['report_weight'] ?? json['reportWeight'] ?? 1.0)
          .toDouble(),
      severity: json['severity'] ?? 'low',
      status: ReportStatus.values.byName(json['status'] ?? 'pending'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
          ? (json['createdAt'] is String
                ? DateTime.parse(json['createdAt'])
                : (json['createdAt'] as dynamic).toDate())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : json['updatedAt'] != null
          ? (json['updatedAt'] is String
                ? DateTime.parse(json['updatedAt'])
                : (json['updatedAt'] as dynamic).toDate())
          : DateTime.now(),
    );
  }
}
