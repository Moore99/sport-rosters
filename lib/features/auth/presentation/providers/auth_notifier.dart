import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../data/user_repository.dart';
import '../../domain/app_user.dart';

/// Converts Firebase error codes to user-friendly messages.
String friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Invalid email or password.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'No internet connection. Please try again.';
    case 'account-exists-with-different-credential':
      return 'This email is already registered with a different sign-in method. Please use your original sign-in method.';
    default:
      // Include error code in debug builds to help diagnose unexpected errors
      assert(() {
        // ignore: avoid_print
        print('FirebaseAuthException — code: ${e.code}, message: ${e.message}');
        return true;
      }());
      return 'Something went wrong (${e.code}). Please try again.';
  }
}

/// Handles auth actions: sign in, register, sign out, password reset.
/// State = error message string, or null when idle/successful.
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseAuth _auth;
  final UserRepository _users;

  AuthNotifier(this._auth, this._users) : super(const AsyncData(null));

  Future<bool> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      state = const AsyncData(null);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AsyncError(friendlyAuthError(e), StackTrace.current);
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    state = const AsyncLoading();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;

      // Create Firestore profile
      await _users.createUser(AppUser(
        userId:    uid,
        name:      name.trim(),
        email:     email.trim(),
        phone:     phone?.trim().isEmpty == true ? null : phone?.trim(),
        teams:     [],
        adFree:    false,
        role:      'player',
        deleted:   false,
        createdAt: DateTime.now(),
      ));

      state = const AsyncData(null);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AsyncError(friendlyAuthError(e), StackTrace.current);
      return false;
    }
  }

  /// Signs in with Google. Creates a Firestore profile if first sign-in.
  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the picker
        state = const AsyncData(null);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      final user     = userCred.user!;

      // Create Firestore profile on first Google sign-in
      final existing = await _users.getUser(user.uid);
      if (existing == null) {
        await _users.createUser(AppUser(
          userId:    user.uid,
          name:      user.displayName ?? '',
          email:     user.email ?? '',
          photoUrl:  user.photoURL,
          teams:     [],
          adFree:    false,
          role:      'player',
          deleted:   false,
          createdAt: DateTime.now(),
        ));
      }

      state = const AsyncData(null);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AsyncError(friendlyAuthError(e), StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncError('Google sign-in failed. Please try again.', StackTrace.current);
      return false;
    }
  }

  /// Signs in with Apple (iOS only). Creates a Firestore profile if first sign-in.
  /// Apple only provides name/email on the *first* authentication — subsequent
  /// sign-ins omit them, so we fall back to whatever Firebase has on the user.
  Future<bool> signInWithApple() async {
    state = const AsyncLoading();
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken:     appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCred = await _auth.signInWithCredential(oauthCredential);
      final user     = userCred.user!;

      // Create Firestore profile on first Apple sign-in
      final existing = await _users.getUser(user.uid);
      if (existing == null) {
        final firstName = appleCredential.givenName ?? '';
        final lastName  = appleCredential.familyName ?? '';
        final fullName  = '$firstName $lastName'.trim();

        await _users.createUser(AppUser(
          userId:    user.uid,
          name:      fullName.isNotEmpty
              ? fullName
              : (user.displayName ?? user.email?.split('@').first ?? 'Player'),
          email:     user.email ?? '',
          teams:     [],
          adFree:    false,
          role:      'player',
          deleted:   false,
          createdAt: DateTime.now(),
        ));
      }

      state = const AsyncData(null);
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User dismissed the sheet — not an error
        state = const AsyncData(null);
        return false;
      }
      state = AsyncError('Apple sign-in failed. Please try again.', StackTrace.current);
      return false;
    } on FirebaseAuthException catch (e) {
      state = AsyncError(friendlyAuthError(e), StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncError('Apple sign-in failed. Please try again.', StackTrace.current);
      return false;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
    // Clear Firestore offline cache so the next user starts with a clean slate.
    // Must be called after sign-out (no active listeners).
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (_) {
      // clearPersistence fails if listeners are still active — safe to ignore.
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      state = const AsyncData(null);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AsyncError(friendlyAuthError(e), StackTrace.current);
      return false;
    }
  }

  void clearError() => state = const AsyncData(null);
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(
    FirebaseAuth.instance,
    ref.read(userRepositoryProvider),
  );
});
