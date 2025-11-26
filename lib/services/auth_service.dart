import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign Up with Email & Password
  Future<UserCredential?> signUpWithEmailAndPassword({
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

      return result;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An error occurred during sign up.';
    } catch (e) {
      throw 'An unexpected error occurred.';
    }
  }

  // Sign In with Email & Password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An error occurred during sign in.';
    } catch (e) {
      throw 'An unexpected error occurred.';
    }
  }

  // Sign In with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user canceled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);

      // Check if user document exists, if not create it
      await _checkAndCreateUserDocument(result.user);

      return result;
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

      return result;
    } catch (e) {
      throw 'Apple sign-in failed: $e';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
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
