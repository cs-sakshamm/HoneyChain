import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service wrapping Firebase Authentication & Google Sign-In
class AuthService {
  final FirebaseAuth? _customFirebaseAuth;
  final GoogleSignIn? _customGoogleSignIn;
  GoogleSignIn? _lazyGoogleSignIn;

  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _customFirebaseAuth = firebaseAuth,
        _customGoogleSignIn = googleSignIn;

  GoogleSignIn get _googleSignIn {
    if (_customGoogleSignIn != null) return _customGoogleSignIn!;
    _lazyGoogleSignIn ??= GoogleSignIn();
    return _lazyGoogleSignIn!;
  }

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  FirebaseAuth? get _firebaseAuth {
    if (_customFirebaseAuth != null) return _customFirebaseAuth;
    if (isFirebaseInitialized) {
      try {
        return FirebaseAuth.instance;
      } catch (e) {
        if (kDebugMode) {
          print('Error accessing FirebaseAuth: $e');
        }
      }
    }
    return null;
  }

  /// Reactive stream of current authenticated user
  Stream<User?> get authStateChanges =>
      _firebaseAuth?.authStateChanges() ?? Stream.value(null);

  /// Currently logged in user
  User? get currentUser => _firebaseAuth?.currentUser;

  /// Trigger native Google Account Sign-In flow
  Future<UserCredential?> signInWithGoogle() async {
    final auth = _firebaseAuth;
    if (auth == null) {
      return null;
    }

    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        return await auth.signInWithPopup(googleProvider);
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await auth.signInWithCredential(credential);
    } catch (e) {
      if (kDebugMode) {
        print('AuthService Error: $e');
      }
      rethrow;
    }
  }

  /// Log out from Firebase & Google Sign-In
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }

    try {
      await _firebaseAuth?.signOut();
    } catch (_) {}
  }
}

