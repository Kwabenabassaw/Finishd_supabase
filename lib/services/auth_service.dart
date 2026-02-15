import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/db/app_database.dart';
import 'package:finishd/services/chat_sync_service.dart';
import 'package:finishd/services/moderation_listener_service.dart';
import 'package:finishd/services/moderation_notification_handler.dart';
import 'package:finishd/services/social_database_helper.dart';

/// Structured moderation status
class ModerationStatus {
  final bool isBanned;
  final bool isSuspended;
  final String reason;
  final int? daysRemaining;

  ModerationStatus({
    required this.isBanned,
    required this.isSuspended,
    required this.reason,
    this.daysRemaining,
  });
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // GoogleSignIn logic handled by Supabase OAuth or native Deep Links
  // For now, we assume Supabase native Auth UI or Deep Links

  // Stream of auth changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Moderation status result
  Future<ModerationStatus?> checkUserModerationStatus(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final data = response;

      // Check permanent ban
      if (data['is_banned'] == true) {
        final reason = data['ban_reason'] ?? 'Policy violation';
        return ModerationStatus(
          isBanned: true,
          isSuspended: false,
          reason: reason,
        );
      }

      // Check temporary suspension
      if (data['is_suspended'] == true) {
        final suspendedUntilStr = data['suspended_until'];
        if (suspendedUntilStr != null) {
          final until = DateTime.parse(suspendedUntilStr);
          if (until.isAfter(DateTime.now())) {
            final reason = data['suspension_reason'] ?? 'Policy violation';
            final daysLeft = until.difference(DateTime.now()).inDays + 1;
            return ModerationStatus(
              isBanned: false,
              isSuspended: true,
              reason: reason,
              daysRemaining: daysLeft,
            );
          } else {
            // Suspension expired, clear the flag
            await _supabase
                .from('profiles')
                .update({
                  'is_suspended': false,
                  'suspended_until': null,
                  'suspension_reason': null,
                })
                .eq('id', userId);
          }
        }
      }

      return null; // All clear
    } catch (e) {
      print('Error checking moderation status: $e');
      return null; // Don't block on error
    }
  }

  // Sign Up with Email & Password
  Future<Map<String, dynamic>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final result = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'username': '$firstName $lastName'.trim(),
        },
      );

      if (result.user == null) {
        throw 'Sign up failed.';
      }

      // Profile is created automatically via Postgres trigger

      // Re-initialize Chat Sync
      try {
        await ChatSyncService.instance.reinitialize();
      } catch (e) {
        print('Error re-initializing chat sync: $e');
      }

      return {
        'credential': result, // AuthResponse
        'isNewUser': true,
        'onboardingCompleted': false,
      };
    } on AuthException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('onboarding_completed')
          .eq('id', userId)
          .single();
      return response['onboarding_completed'] == true;
    } catch (e) {
      return false;
    }
  }

  // Sign In with Email & Password
  Future<Map<String, dynamic>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Re-initialize Chat Sync
      try {
        await ChatSyncService.instance.reinitialize();
      } catch (e) {
        print('Error re-initializing chat sync: $e');
      }

      final onboardingCompleted = await hasCompletedOnboarding(result.user!.id);

      return {
        'credential': result,
        'isNewUser': false,
        'onboardingCompleted': onboardingCompleted,
      };
    } on AuthException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  // Sign In with Google
  // Uses Supabase OAuth
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Perform web-based OAuth with deep link redirect
      // The redirectTo must match the scheme configured in AndroidManifest.xml
      // and be added to Supabase Auth settings as an allowed redirect URL
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'finishd://login-callback',
      );

      // The session is handled via deep link callback (DeepLinkService)
      // Returns null here and let the auth state stream handle the session
      return null;
    } catch (e) {
      throw 'Google sign-in failed: $e';
    }
  }

  // Sign In with Apple
  Future<void> signInWithApple() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'finishd://login-callback',
      );
    } catch (e) {
      throw 'Apple sign-in failed: $e';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    // Stop real-time moderation listener
    ModerationListenerService.instance.stopListening();

    // Stop moderation notification handler
    ModerationNotificationHandler.instance.stopListening();

    // Clear local chat data
    try {
      await ChatSyncService.instance.clearLocalData();
    } catch (e) {
      print('Error clearing chat data: $e');
    }

    // Clear SQLite cache
    try {
      await AppDatabase.instance.clearAllUserData();
    } catch (e) {
      print('Error clearing SQLite cache: $e');
    }

    // Clear social database
    try {
      await SocialDatabaseHelper().clearAllUserData();
    } catch (e) {
      print('Error clearing social database: $e');
    }

    await _supabase.auth.signOut();
  }
}
