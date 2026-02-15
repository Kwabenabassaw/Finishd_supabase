import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/models/appeal_model.dart';

/// Service for managing user appeals against moderation actions
class AppealService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Submit a new appeal against a suspension or ban
  Future<void> submitAppeal({
    required AppealActionType actionType,
    required String originalReason,
    required String appealMessage,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Must be logged in to submit an appeal');
    }

    // Check if user already has a pending appeal for this action type
    final existingAppeals = await _supabase
        .from('appeals')
        .select()
        .eq('user_id', user.id)
        .eq('action_type', actionType.name)
        .eq('status', 'pending')
        .limit(1);

    if (existingAppeals.isNotEmpty) {
      throw Exception('You already have a pending appeal for this action');
    }

    // Submit appeal
    await _supabase.from('appeals').insert({
      'user_id': user.id,
      'action_type': actionType.name,
      'original_reason': originalReason,
      'appeal_message': appealMessage,
      'status': 'pending',
    });
  }

  /// Check if user has a pending appeal
  Future<bool> hasPendingAppeal(AppealActionType actionType) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final existing = await _supabase
        .from('appeals')
        .select()
        .eq('user_id', userId)
        .eq('action_type', actionType.name)
        .eq('status', 'pending')
        .limit(1);

    return existing.isNotEmpty;
  }

  /// Get all appeals for current user
  Future<List<Appeal>> getMyAppeals() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final response = await _supabase
        .from('appeals')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Appeal.fromJson(json)).toList();
  }

  /// Get the most recent appeal for the current user
  Future<Appeal?> getLatestAppeal() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    final response = await _supabase
        .from('appeals')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return Appeal.fromJson(response);
  }

  /// Stream all appeals for current user
  Stream<List<Appeal>> streamMyAppeals() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('appeals')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Appeal.fromJson(json)).toList());
  }
}
