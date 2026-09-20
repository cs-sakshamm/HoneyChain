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

  /// Trigger the Firebase Phone-OTP flow.
  ///
  /// - verificationCompleted: Android auto-retrieval / instant verification —
  ///   the credential signs the user in without manual OTP entry.
  /// - codeSent: store the verificationId and show the OTP entry UI.
  /// - codeAutoRetrievalTimeout: keep the verificationId for manual entry.
  /// - forceResendingToken: pass the token from a previous [codeSent] callback
  ///   to reuse the same verification session (reduces SMS quota usage on resend).
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException error) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final auth = _firebaseAuth;
    if (auth == null) {
      verificationFailed(
        FirebaseAuthException(code: 'firebase-not-initialized', message: 'Firebase is not available on this device.'),
      );
      return;
    }
    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      forceResendingToken: forceResendingToken,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  /// Complete phone authentication with the SMS code.
  Future<UserCredential?> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final auth = _firebaseAuth;
    if (auth == null) return null;
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return auth.signInWithCredential(credential);
  }

  /// Fresh Firebase ID token for backend session exchange.
  Future<String?> getIdToken() async {
    try {
      return await _firebaseAuth?.currentUser?.getIdToken(true);
    } catch (_) {
      return null;
    }
  }

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

