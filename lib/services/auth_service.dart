import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:finishd/db/app_database.dart';
import 'package:finishd/services/chat_sync_service.dart';
import 'package:finishd/services/moderation_listener_service.dart';
import 'package:finishd/services/moderation_notification_handler.dart';
import 'package:finishd/services/social_database_helper.dart';
import 'package:finishd/config/env.dart';

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

  Future<String> _generateUniqueUsername(
    String firstName,
    String lastName,
  ) async {
    String base = (firstName + lastName)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (base.isEmpty) {
      base = 'user${DateTime.now().millisecondsSinceEpoch}';
    }

    final random = Random();
    final suggestions = [
      base,
      "$base${random.nextInt(99)}",
      "$base${random.nextInt(999)}",
      "${base}_${random.nextInt(9)}",
      "$base${DateTime.now().millisecond}",
    ];

    for (String suggestion in suggestions) {
      final response = await _supabase
          .from('profiles')
          .select('username')
          .eq('username', suggestion)
          .maybeSingle();
      if (response == null) {
        return suggestion;
      }
    }

    return "$base${DateTime.now().millisecondsSinceEpoch}";
  }

  // Sign Up with Email & Password
  Future<Map<String, dynamic>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final generatedUsername = await _generateUniqueUsername(
        firstName,
        lastName,
      );

      final result = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'username': generatedUsername,
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
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      /// TODO: Replace these with your actual IDs from Google Cloud Console
      /// Instructions are provided in the google_sign_in_setup.md
      final webClientId = Env.googleWebClientId;
      final iosClientId = Env.googleIosClientId;

      final GoogleSignIn signIn = GoogleSignIn.instance;

      await signIn.initialize(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      late GoogleSignInAccount googleUser;
      if (signIn.supportsAuthenticate()) {
        googleUser = await signIn.authenticate();
      } else {
        throw 'Interactive sign-in not supported on this platform directly via authenticate().';
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(['email']);
      final accessToken = authorization?.accessToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      final AuthResponse res = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Re-initialize Chat Sync
      try {
        await ChatSyncService.instance.reinitialize();
      } catch (e) {
        print('Error re-initializing chat sync: $e');
      }

      // Check onboarding state if there's a user
      bool onboardingCompleted = false;
      if (res.user != null) {
        onboardingCompleted = await hasCompletedOnboarding(res.user!.id);
      }

      return {
        'credential': res,
        'isNewUser':
            false, // signInWithIdToken doesn't return user creation stat easily, safely assume false
        'onboardingCompleted': onboardingCompleted,
      };
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
