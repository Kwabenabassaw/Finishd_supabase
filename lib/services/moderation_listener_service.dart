import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/screens/moderation_block_screen.dart';

/// Real-time listener for moderation status changes using Supabase Realtime.
class ModerationListenerService {
  static final ModerationListenerService _instance =
      ModerationListenerService._internal();
  static ModerationListenerService get instance => _instance;
  ModerationListenerService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  void startListening() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _subscription?.unsubscribe();

    // Listen to changes on public.profiles for this user
    _subscription = _supabase
        .channel('public:profiles:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) {
            _handleStatusChange(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleStatusChange(Map<String, dynamic> data) {
    final isBanned = data['is_banned'] == true;
    final isSuspended = data['is_suspended'] == true;

    if (isBanned || isSuspended) {
      String reason;
      int? daysRemaining;

      if (isBanned) {
        reason = data['ban_reason'] ?? 'Policy violation';
      } else {
        reason = data['suspension_reason'] ?? 'Policy violation';
        final suspendedUntilStr = data['suspended_until'];
        if (suspendedUntilStr != null) {
          final until = DateTime.tryParse(suspendedUntilStr);
          if (until != null && until.isAfter(DateTime.now())) {
            daysRemaining = until.difference(DateTime.now()).inDays + 1;
          } else {
            return; // Suspended until passed
          }
        }
      }

      _navigateToBlockScreen(
        isBanned: isBanned,
        reason: reason,
        daysRemaining: daysRemaining,
      );
    }
  }

  void _navigateToBlockScreen({
    required bool isBanned,
    required String reason,
    int? daysRemaining,
  }) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ModerationBlockScreen(
          isBanned: isBanned,
          reason: reason,
          daysRemaining: daysRemaining,
        ),
      ),
      (route) => false,
    );
  }

  void stopListening() {
    _subscription?.unsubscribe();
    _subscription = null;
  }
}
