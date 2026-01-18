import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/models/appeal_model.dart';

/// Service for managing user appeals against moderation actions
class AppealService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _appealsRef => _db.collection('appeals');

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Submit a new appeal against a suspension or ban
  Future<void> submitAppeal({
    required AppealActionType actionType,
    required String originalReason,
    required String appealMessage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Must be logged in to submit an appeal');
    }

    // Check if user already has a pending appeal for this action type
    final existingAppeals = await _appealsRef
        .where('userId', isEqualTo: user.uid)
        .where('actionType', isEqualTo: actionType.name)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingAppeals.docs.isNotEmpty) {
      throw Exception('You already have a pending appeal for this action');
    }

    // Get user data for the appeal
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final appeal = Appeal(
      id: '',
      userId: user.uid,
      userEmail: user.email,
      username: userData['username'],
      actionType: actionType,
      originalReason: originalReason,
      appealMessage: appealMessage,
      status: AppealStatus.pending,
      createdAt: DateTime.now(),
    );

    await _appealsRef.add(appeal.toJson());
  }

  /// Check if user has a pending appeal
  Future<bool> hasPendingAppeal(AppealActionType actionType) async {
    if (_currentUserId == null) return false;

    final existing = await _appealsRef
        .where('userId', isEqualTo: _currentUserId)
        .where('actionType', isEqualTo: actionType.name)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return existing.docs.isNotEmpty;
  }

  /// Get all appeals for current user
  Future<List<Appeal>> getMyAppeals() async {
    if (_currentUserId == null) return [];

    final snapshot = await _appealsRef
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Appeal.fromDocument(doc)).toList();
  }

  /// Get the most recent appeal for the current user
  Future<Appeal?> getLatestAppeal() async {
    if (_currentUserId == null) return null;

    final snapshot = await _appealsRef
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Appeal.fromDocument(snapshot.docs.first);
  }

  /// Stream all appeals for current user (for real-time updates)
  /// Efficient: only 1 listener, updates only when data changes
  Stream<List<Appeal>> streamMyAppeals() {
    if (_currentUserId == null) return Stream.value([]);

    return _appealsRef
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Appeal.fromDocument(doc)).toList(),
        );
  }
}
