/// Type of moderation action being appealed
enum AppealActionType { suspension, ban }

/// Status of the appeal
enum AppealStatus { pending, approved, rejected }

/// Model for user appeals against moderation actions
class Appeal {
  final String id;
  final String userId;
  final String? userEmail;
  final String? username;
  final AppealActionType actionType;
  final String originalReason;
  final String appealMessage;
  final AppealStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? adminResponse; // Moderator's response message

  Appeal({
    required this.id,
    required this.userId,
    this.userEmail,
    this.username,
    required this.actionType,
    required this.originalReason,
    required this.appealMessage,
    this.status = AppealStatus.pending,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.adminResponse,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'userEmail':
          userEmail, // Keep for legacy if needed, though not in my schema
      'username': username,
      'action_type': actionType.name,
      'original_reason': originalReason,
      'appeal_message': appealMessage,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (adminResponse != null) 'admin_notes': adminResponse,
    };
  }

  factory Appeal.fromJson(Map<String, dynamic> json) {
    return Appeal(
      id: json['id']?.toString() ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      userEmail: json['userEmail'],
      username: json['username'],
      actionType: AppealActionType.values.byName(
        json['action_type'] ?? json['actionType'] ?? 'suspension',
      ),
      originalReason: json['original_reason'] ?? json['originalReason'] ?? '',
      appealMessage: json['appeal_message'] ?? json['appealMessage'] ?? '',
      status: AppealStatus.values.byName(json['status'] ?? 'pending'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
          ? (json['createdAt'] is String
                ? DateTime.parse(json['createdAt'])
                : (json['createdAt'] as dynamic).toDate())
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : json['reviewedAt'] != null
          ? (json['reviewedAt'] is String
                ? DateTime.parse(json['reviewedAt'])
                : (json['reviewedAt'] as dynamic).toDate())
          : null,
      reviewedBy: json['reviewed_by'] ?? json['reviewedBy'],
      adminResponse: json['admin_notes'] ?? json['adminResponse'],
    );
  }
}
