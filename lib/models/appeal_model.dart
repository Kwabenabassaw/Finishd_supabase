import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'username': username,
      'actionType': actionType.name,
      'originalReason': originalReason,
      'appealMessage': appealMessage,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
    };
  }

  factory Appeal.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appeal(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'],
      username: data['username'],
      actionType: AppealActionType.values.byName(
        data['actionType'] ?? 'suspension',
      ),
      originalReason: data['originalReason'] ?? '',
      appealMessage: data['appealMessage'] ?? '',
      status: AppealStatus.values.byName(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
    );
  }
}
