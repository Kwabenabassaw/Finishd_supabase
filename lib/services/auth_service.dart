import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  /// Moderation status result
  /// Returns null if user is OK, otherwise contains block details
  Future<ModerationStatus?> checkUserModerationStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;

      // Check permanent ban
      if (data['isBanned'] == true) {
        final reason = data['banReason'] ?? 'Policy violation';
        return ModerationStatus(
          isBanned: true,
          isSuspended: false,
          reason: reason,
        );
      }

      // Check temporary suspension
      if (data['isSuspended'] == true) {
        final suspendedUntil = data['suspendedUntil'];
        if (suspendedUntil != null) {
          final until = (suspendedUntil as dynamic).toDate() as DateTime;
          if (until.isAfter(DateTime.now())) {
            final reason = data['suspensionReason'] ?? 'Policy violation';
            final daysLeft = until.difference(DateTime.now()).inDays + 1;
            return ModerationStatus(
              isBanned: false,
              isSuspended: true,
              reason: reason,
              daysRemaining: daysLeft,
            );
          } else {
            // Suspension expired, clear the flag
            await _firestore.collection('users').doc(userId).update({
              'isSuspended': false,
              'suspendedUntil': null,
              'suspensionReason': null,
            });
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
  // Returns a map with 'credential', 'isNewUser', and 'onboardingCompleted' flags
  Future<Map<String, dynamic>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _createUserDocument(
        result.user,
        firstName: firstName,
        lastName: lastName,
      );

      // Re-initialize Chat Sync for the new user
      try {
        await ChatSyncService.instance.reinitialize();
      } catch (e) {
        print('Error re-initializing chat sync: $e');
      }

      return {
        'credential': result,
        'isNewUser': true,
        'onboardingCompleted': false,
      };
    } on FirebaseAuthException catch (e) {
      // If email already exists, sign them in instead
      if (e.code == 'email-already-in-use') {
        try {
          final result = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          // Check if existing user has completed onboarding
          final onboardingCompleted = await hasCompletedOnboarding(
            result.user!.uid,
          );
          return {
            'credential': result,
            'isNewUser': false,
            'onboardingCompleted': onboardingCompleted,
          };
        } catch (signInError) {
          throw 'Account exists but password is incorrect.';
        }
      }
      throw e.message ?? 'An error occurred during sign up.';
    } catch (e) {
      throw 'An unexpected error occurred.';
    }
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists && doc.data()?['onboardingCompleted'] == true;
    } catch (e) {
      return false;
    }
  }

  // Sign In with Email & Password
  // Returns a map with 'credential' and 'isNewUser' flag
  Future<Map<String, dynamic>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Re-initialize Chat Sync
      try {
        await ChatSyncService.instance.reinitialize();
      } catch (e) {
        print('Error re-initializing chat sync: $e');
      }

      return {'credential': result, 'isNewUser': false};
    } on FirebaseAuthException catch (e) {
      // If user doesn't exist, auto-create account
      if (e.code == 'user-not-found') {
        try {
          final result = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          // Create user document with basic info
          await _createUserDocument(result.user);
          return {'credential': result, 'isNewUser': true};
        } catch (createError) {
          throw 'Failed to create account: $createError';
        }
      }
      throw e.message ?? 'An error occurred during sign in.';
    } catch (e) {
      throw 'An unexpected error occurred.';
    }
  }

  // Sign In with Google
  // Returns a map with 'credential', 'isNewUser', and 'onboardingCompleted' flags
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Force sign-out before sign-in to show account picker
      // This allows users to switch between Google accounts
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user canceled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);

      // Check if user document exists
      final userDoc = await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .get();
      final isNewUser = !userDoc.exists;

      // Create user document if it doesn't exist
      if (isNewUser) {
        await _checkAndCreateUserDocument(result.user);
      }

      final onboardingCompleted =
          userDoc.exists && userDoc.data()?['onboardingCompleted'] == true;

      // Re-initialize Chat Sync
      try {
        await ChatSyncService.instance.reinitialize();
      } catch (e) {
        print('Error re-initializing chat sync: $e');
      }

      return {
        'credential': result,
        'isNewUser': isNewUser,
        'onboardingCompleted': onboardingCompleted,
      };
    } catch (e) {
      throw 'Google sign-in failed: $e';
    }
  }

  // Sign In with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final OAuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      UserCredential result = await _auth.signInWithCredential(credential);

      String? firstName = appleCredential.givenName;
      String? lastName = appleCredential.familyName;

      await _checkAndCreateUserDocument(
        result.user,
        firstName: firstName,
        lastName: lastName,
      );

      // Re-initialize Chat Sync
      try {
        await ChatSyncService.instance.reinitialize();
      } catch (e) {
        print('Error re-initializing chat sync: $e');
      }

      return result;
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

    // Clear local chat data (ObjectBox) to prevent leaking between accounts
    try {
      await ChatSyncService.instance.clearLocalData();
    } catch (e) {
      print('Error clearing chat data: $e');
    }

    // Clear SQLite cache data (feed, recommendations, followers, etc.)
    try {
      await AppDatabase.instance.clearAllUserData();
    } catch (e) {
      print('Error clearing SQLite cache: $e');
    }

    // Clear social database (movie lists, friend activity, favorites)
    try {
      await SocialDatabaseHelper().clearAllUserData();
    } catch (e) {
      print('Error clearing social database: $e');
    }

    // Disconnect Google Sign-In to fully clear cached account
    // This allows switching to a different Google account on next sign-in
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      // disconnect() throws error if user never signed in with Google
      // or if already disconnected - fallback to signOut()
      await _googleSignIn.signOut();
    }

    await _auth.signOut();
  }

  // Create User Document in Firestore
  Future<void> _createUserDocument(
    User? user, {
    String? firstName,
    String? lastName,
  }) async {
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);

    await userRef.set({
      'uid': user.uid,
      'email': user.email,
      'username': '${firstName ?? ''} ${lastName ?? ''}'.trim(),
      'firstName': firstName ?? '',
      'lastName': lastName ?? '',
      'profileImage': user.photoURL ?? '',
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  // Check and Create User Document (for Social Auth)
  Future<void> _checkAndCreateUserDocument(
    User? user, {
    String? firstName,
    String? lastName,
  }) async {
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'username':
            user.displayName ?? '${firstName ?? ''} ${lastName ?? ''}'.trim(),
        'firstName': firstName ?? '',
        'lastName': lastName ?? '',
        'profileImage': user.photoURL ?? '',
        'joinedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
