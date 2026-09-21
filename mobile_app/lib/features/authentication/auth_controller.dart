import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_token_store.dart';
import '../../../core/utils/phone_utils.dart';
import 'auth_service.dart';

/// Persisted keys written on phone login and read by [_restoreSession].
abstract final class _SessionKeys {
  static const token = 'auth_token';
  static const userId = 'auth_user_id';
  static const profileId = 'user_profile_id';
  static const profileName = 'user_profile_name';
  static const profileEmail = 'user_profile_email';
  static const profilePhone = 'user_profile_phone';
  static const profileRole = 'user_profile_role';
  static const profileAuthProvider = 'user_profile_auth_provider';
  static const beekeeperId = 'user_profile_beekeeper_id';
}

enum AuthStateStatus {
  idle,
  authenticating,
  authenticated,
  codeSent,
  error,
}

enum AuthMode {
  phoneEntry,
  otpEntry,
}

/// Roles in the HoneyChain supply chain
enum UserRole {
  harvester,
  collectionProcessing,
  labTesting,
  packaging,
}

String userRoleToString(UserRole? role) {
  switch (role) {
    case UserRole.harvester:
      return 'HARVESTER';
    case UserRole.collectionProcessing:
      return 'COLLECTOR_PROCESSOR';
    case UserRole.labTesting:
      return 'LAB';
    case UserRole.packaging:
      return 'PACKAGING';
    default:
      return 'HARVESTER';
  }
}

UserRole userRoleFromString(String? roleStr) {
  if (roleStr == null) return UserRole.harvester;
  final r = roleStr.toUpperCase();
  if (r.contains('COLLECT') || r.contains('PROCESS')) return UserRole.collectionProcessing;
  if (r.contains('LAB')) return UserRole.labTesting;
  if (r.contains('PKG') || r.contains('PACKAG')) return UserRole.packaging;
  return UserRole.harvester;
}

/// Human-readable role name (used by the DEMO ONLY Google bypass to name the
/// demo account; harmless elsewhere).
extension UserRoleDisplayName on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.harvester:
        return 'Harvester';
      case UserRole.collectionProcessing:
        return 'Collection & Processing';
      case UserRole.labTesting:
        return 'Lab Testing';
      case UserRole.packaging:
        return 'Packaging';
    }
  }
}

/// Production Controller managing business authentication & session state backed by PostgreSQL API
class AuthController extends ChangeNotifier {
  final AuthService _authService;
  final http.Client _client;
  final String _baseUrl;

  AuthStateStatus _status = AuthStateStatus.idle;
  AuthMode _mode = AuthMode.phoneEntry;

  String? _errorMessage;
  String? _infoMessage;
  User? _currentUser;
  String? _verificationId;
  int? _resendToken;
  String _pendingPhone = '';
  bool _isRequestingOtp = false;

  // Role State
  UserRole? _selectedRole;

  AuthController({AuthService? authService, http.Client? client, String? baseUrl})
      : _authService = authService ?? AuthService(),
        _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveBaseUrl() {
    _initSession();
  }

  Future<void> _initSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_SessionKeys.token);
    final savedRole = prefs.getString(_SessionKeys.profileRole);
    if (savedRole != null && savedRole.isNotEmpty) {
      _selectedRole = userRoleFromString(savedRole);
    }
    if (token != null && token.isNotEmpty) {
      _currentUser = _authService.currentUser;
      _status = AuthStateStatus.authenticated;
      notifyListeners();
      // A stored token alone doesn't prove it's still valid: re-exchange the
      // Firebase session for a fresh backend JWT. On success the app stays
      // authenticated (and the role/profile are refreshed from the server);
      // on failure (expired Firebase session, revoked token, offline) the
      // user is signed out instead of stranding them on a broken dashboard.
      await _restoreSession();
    } else if (_authService.isFirebaseInitialized) {
      _currentUser = _authService.currentUser;
      if (_currentUser != null) {
        // Live Firebase session but NO stored backend JWT. Exchange it now
        // instead of rendering a dashboard where every API call would 401
        // ("Authentication token is required.").
        _status = AuthStateStatus.authenticated;
        notifyListeners();
        await _restoreSession();
      }
    }
  }

  /// Re-validates the persisted session by exchanging the current Firebase
  /// ID token for a fresh backend JWT. Fire-and-forget at startup:
  /// the app renders as authenticated meanwhile, then silently re-auths or
  /// signs out based on the result.
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // DEMO ONLY: Google Auth temporarily bypassed.
      // A demo (bypass) session is a pure backend JWT with no Firebase
      // identity behind it, so it cannot be re-exchanged. Instead it is
      // re-validated by fetching the profile with the stored token and kept
      // unless the backend rejects it (expired/revoked).
      if (prefs.getString(_SessionKeys.profileAuthProvider) == 'local') {
        final checkRes = await _client
            .get(Uri.parse('$_baseUrl/api/profile'), headers: _headers)
            .timeout(_authTimeout);
        if (checkRes.statusCode == 200) {
          final data = jsonDecode(checkRes.body);
          final u = data['user'] is Map<String, dynamic>
              ? data['user'] as Map<String, dynamic>
              : null;
          if (u != null) {
            if (u['id'] != null) await prefs.setString(_SessionKeys.profileId, u['id']);
            if (u['name'] != null) await prefs.setString(_SessionKeys.profileName, u['name']);
            if (u['email'] != null) await prefs.setString(_SessionKeys.profileEmail, u['email']);
            if (u['phone'] != null) await prefs.setString(_SessionKeys.profilePhone, u['phone']);
            if (u['role'] != null) {
              await prefs.setString(_SessionKeys.profileRole, u['role']);
              _selectedRole = userRoleFromString(u['role']);
            }
          }
          notifyListeners();
          return;
        }
        // Token rejected/expired: fall through to a normal sign-out below.
        await signOut();
        return;
      }

      final idToken = await _authService.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        // No live Firebase session behind the stored token — it cannot be
        // refreshed, so treat the session as expired.
        await signOut();
        return;
      }

      // Restore through the SAME provider the session was created with.
      // Phone-OTP sessions re-exchange via /api/auth/phone. Google sessions
      // MUST NOT: a Google/Firebase ID token carries no verified
      // phone_number claim, so /api/auth/phone correctly rejects it with
      // 401 INVALID_PHONE_TOKEN. This path previously treated that as a
      // dead session and signed the user out — silently destroying a
      // perfectly valid backend identity at every app start, which left
      // Add Hive (and every other call) without an Authorization header:
      // the backend's 401 "Authentication token is required."
      final storedProvider = prefs.getString(_SessionKeys.profileAuthProvider);
      final isPhoneSession = storedProvider != null
          ? storedProvider == 'phone'
          : (_authService.currentUser?.phoneNumber ?? '').isNotEmpty;

      final savedRole = prefs.getString(_SessionKeys.profileRole);
      final restoreUrl =
          Uri.parse('$_baseUrl${isPhoneSession ? '/api/auth/phone' : '/api/auth/google'}');
      final response = await _client
          .post(
            restoreUrl,
            headers: isPhoneSession ? _headers : _firebaseBearerHeaders(idToken),
            body: jsonEncode(
              isPhoneSession
                  // No role: the backend falls back to the existing account
                  // for this verified number instead of creating a duplicate.
                  ? {'idToken': idToken}
                  // Role from the original sign-in so the backend resolves
                  // the SAME (email, role) account row — omitting it would
                  // default to HARVESTER and fork duplicates for other roles.
                  : {
                      if (savedRole != null && savedRole.isNotEmpty) 'role': savedRole,
                    },
            ),
          )
          .timeout(_authTimeout);

      if (response.statusCode != 200) {
        await signOut();
        return;
      }

      final data = jsonDecode(response.body);
      if (data['token'] != null) {
        await prefs.setString(_SessionKeys.token, data['token']);
        AuthTokenStore.set(token: data['token']);
      }
      // Persist which provider owns this session so the NEXT restore
      // exchanges through the same endpoint (phone -> /api/auth/phone,
      // google -> /api/auth/google). Writing a hardcoded 'phone' here
      // would misroute the next Google restore and re-trigger the bug.
      await prefs.setString(
        _SessionKeys.profileAuthProvider,
        isPhoneSession ? 'phone' : 'google',
      );
      final u = data['user'];
      if (u is Map<String, dynamic>) {
        if (u['id'] != null) {
          await prefs.setString(_SessionKeys.profileId, u['id']);
          await prefs.setString(_SessionKeys.userId, u['id']);
          AuthTokenStore.set(userId: u['id']);
        }
        if (u['name'] != null) await prefs.setString(_SessionKeys.profileName, u['name']);
        if (u['email'] != null) await prefs.setString(_SessionKeys.profileEmail, u['email']);
        if (u['phone'] != null) await prefs.setString(_SessionKeys.profilePhone, u['phone']);
        if (u['role'] != null) {
          await prefs.setString(_SessionKeys.profileRole, u['role']);
          _selectedRole = userRoleFromString(u['role']);
        }
        if (u['beekeeperId'] != null) {
          await prefs.setString(_SessionKeys.beekeeperId, u['beekeeperId']);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthController] session restore skipped: $e');
      // Network hiccup at startup: keep the cached session rather than
      // logging the user out for being briefly offline.
    }
  }

  static String _resolveBaseUrl() {
    // Works on web, Android emulator (10.0.2.2), and physical devices
    // (override with --dart-define=BACKEND_URL=...).
    return AppConstants.backendBaseUrl;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Map<String, String> _firebaseBearerHeaders(String firebaseIdToken) => {
        ..._headers,
        'Authorization': 'Bearer $firebaseIdToken',
      };

  /// Auth calls run bcrypt(12) hashing + cloud PostgreSQL round-trips server
  /// side (~2s measured locally). A 4s budget aborted legitimate logins on
  /// slower networks and surfaced as "Unable to connect", which made email/
  /// password auth look broken. 15s keeps the same security while tolerating
  /// real-world latency.
  static const Duration _authTimeout = Duration(seconds: 15);

  /// Extract a user-facing message from either a plain JSON body or FastAPI's
  /// HTTPException envelope ("detail": {"error": ..., "message": ...} or
  /// "detail": "string"). Previously the envelope was never unwrapped, so
  /// every failure showed the generic "Authentication failed." text.
  String _extractErrorMessage(dynamic body, String fallback) {
    if (body is Map<String, dynamic>) {
      final dynamic detail = body['detail'];
      if (detail is Map<String, dynamic>) {
        return (detail['error'] ?? detail['message'] ?? body['error'] ?? body['message'] ?? fallback).toString();
      }
      if (detail is String && detail.trim().isNotEmpty) return detail;
      return (body['error'] ?? body['message'] ?? fallback).toString();
    }
    return fallback;
  }

  dynamic _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }


  // Getters
  AuthStateStatus get status => _status;
  AuthMode get mode => _mode;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  User? get currentUser => _currentUser;
  String? get verificationId => _verificationId;
  String get pendingPhone => _pendingPhone;
  bool get isRequestingOtp => _isRequestingOtp;
  bool get isAuthenticated =>
      _currentUser != null || _status == AuthStateStatus.authenticated;
  UserRole? get selectedRole => _selectedRole;

  void setRole(UserRole role) {
    _selectedRole = role;
    notifyListeners();
  }

  void clearRole() {
    _selectedRole = null;
    notifyListeners();
  }

  void switchMode(AuthMode newMode) {
    _mode = newMode;
    _status = AuthStateStatus.idle;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  /// Normalizes Indian local numbers (10 digits) to full E.164 (+91…).
  /// Numbers the user already typed with a country code are kept as-is.
  ///
  /// Kept for backwards compatibility; new code should use
  /// [normalizePhoneForCountry] from `core/utils/phone_utils.dart` so the
  /// selected country is respected.
  static String normalizePhoneNumber(String raw) {
    return normalizePhoneForCountry(raw, kDefaultCountry).e164;
  }

  /// Maps Firebase Auth errors to clean, user-facing messages.
  String _friendlyFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That mobile number doesn\'t look right. Please check and try again.';
      case 'invalid-verification-code':
        return 'The code you entered is incorrect. Please check the SMS and try again.';
      case 'session-expired':
      case 'code-expired':
        return 'This verification session has expired. Please request a new code.';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many attempts. Please wait a moment before trying again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'captcha-check-failed':
        return 'Verification challenge failed. Please try again.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled yet. Please contact support.';
      case 'provider-already-linked':
      case 'credential-already-in-use':
        return 'This mobile number is already linked to an account. Try signing in instead.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// ── Step 1: send the SMS OTP via Firebase ──
  Future<void> requestOtp(String rawPhone, [UserRole? role, CountryInfo? country]) async {
    // Re-entrancy guard: a double-tap on "Send OTP" / "Resend OTP" must not
    // fire two Firebase verification requests (quota + SMS spam).
    if (_isRequestingOtp) return;

    final selectedCountry = country ?? kDefaultCountry;
    final normalized = normalizePhoneForCountry(rawPhone, selectedCountry);
    final phone = normalized.e164;
    final activeRole = role ?? _selectedRole ?? UserRole.harvester;

    if (!normalized.isValid) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Enter a valid mobile number for ${selectedCountry.name}.';
      notifyListeners();
      return;
    }

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    _infoMessage = null;
    _pendingPhone = phone;
    _isRequestingOtp = true;
    notifyListeners();

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phone,
        // Pass the resend token when available so Firebase can skip a new
        // verification round-trip and reduce SMS quota consumption.
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          // Android auto-retrieval / instant verification.
          try {
            final auth = FirebaseAuth.instance;
            final result = await auth.signInWithCredential(credential);
            await _completePhoneAuthentication(result.user, userRoleToString(activeRole));
          } on FirebaseAuthException catch (e) {
            _status = AuthStateStatus.error;
            _errorMessage = _friendlyFirebaseError(e);
            notifyListeners();
          }
        },
        verificationFailed: (error) {
          _status = AuthStateStatus.error;
          _errorMessage = _friendlyFirebaseError(error);
          notifyListeners();
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _mode = AuthMode.otpEntry;
          _status = AuthStateStatus.codeSent;
          _infoMessage = 'Verification code sent to $phone.';
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          // Keep the code entry usable after auto-retrieval gives up.
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      debugPrint('[AuthController] requestOtp error: $e');
      _status = AuthStateStatus.error;
      _errorMessage = 'Unable to send the verification code. Please try again.';
    } finally {
      _isRequestingOtp = false;
    }
    notifyListeners();
  }

  /// ── Step 2: verify the SMS code the user typed ──
  Future<void> verifyOtp(String smsCode, [UserRole? role]) async {
    final activeRole = role ?? _selectedRole ?? UserRole.harvester;
    final verificationId = _verificationId;
    final code = smsCode.trim();

    if (verificationId == null || verificationId.isEmpty) {
      _status = AuthStateStatus.error;
      _errorMessage = 'No active verification. Please request a new code.';
      notifyListeners();
      return;
    }
    if (code.length < 6) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Enter the 6-digit code from the SMS.';
      notifyListeners();
      return;
    }

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithSmsCode(
        verificationId: verificationId,
        smsCode: code,
      );
      if (result?.user == null) {
        _status = AuthStateStatus.error;
        _errorMessage = 'Verification failed. Please try again.';
        notifyListeners();
        return;
      }
      await _completePhoneAuthentication(result!.user, userRoleToString(activeRole));
    } on FirebaseAuthException catch (e) {
      _status = AuthStateStatus.error;
      _errorMessage = _friendlyFirebaseError(e);
    } catch (e) {
      debugPrint('[AuthController] verifyOtp error: $e');
      _status = AuthStateStatus.error;
      _errorMessage = 'Unable to verify the code. Please try again.';
    }
    notifyListeners();
  }

  /// Firebase user → HoneyChain session: exchange the Firebase ID token for a
  /// backend JWT, persist the profile, and land on the role dashboard.
  Future<void> _completePhoneAuthentication(User? user, String roleStr) async {
    if (user == null) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Verification failed. Please try again.';
      notifyListeners();
      return;
    }

    final idToken = await _authService.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Could not establish your session. Please try again.';
      notifyListeners();
      return;
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/auth/phone'),
            headers: _headers,
            body: jsonEncode({
              'idToken': idToken,
              'role': roleStr,
              'phone': user.phoneNumber,
            }),
          )
          .timeout(_authTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        if (data['token'] != null) {
          await prefs.setString(_SessionKeys.token, data['token']);
          AuthTokenStore.set(token: data['token']);
        }
        if (data['user'] != null) {
          final u = data['user'];
          if (u['id'] != null) {
            await prefs.setString(_SessionKeys.profileId, u['id']);
            await prefs.setString(_SessionKeys.userId, u['id']);
            AuthTokenStore.set(userId: u['id']);
          }
          if (u['name'] != null) await prefs.setString(_SessionKeys.profileName, u['name']);
          if (u['email'] != null) await prefs.setString(_SessionKeys.profileEmail, u['email']);
          if (u['phone'] != null) await prefs.setString(_SessionKeys.profilePhone, u['phone']);
          if (u['role'] != null) await prefs.setString(_SessionKeys.profileRole, u['role']);
          if (u['beekeeperId'] != null) await prefs.setString(_SessionKeys.beekeeperId, u['beekeeperId']);
        }
        await prefs.setString(_SessionKeys.profileAuthProvider, 'phone');
        _currentUser = user;
        _status = AuthStateStatus.authenticated;
        _verificationId = null;
        _resendToken = null;
        notifyListeners();
      } else {
        _status = AuthStateStatus.error;
        _errorMessage = _extractErrorMessage(_decodeBody(response), 'Sign-in succeeded but the session could not be created. Please try again.');
      }
    } catch (e) {
      debugPrint('[AuthController] phone session exchange error: $e');
      _status = AuthStateStatus.error;
      _errorMessage = 'Unable to reach the HoneyChain server. Please check your connection.';
    }
    notifyListeners();
  }

  void resetError() {
    _status = AuthStateStatus.idle;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  /// Google Sign-In (secondary provider, preserved from the existing flow)
  // DEMO ONLY: Google Auth temporarily bypassed.
  // When [kGoogleAuthBypassEnabled] is true, tapping "Continue with Google"
  // skips the Google Sign-In / Firebase identity flow entirely and instead
  // signs in through the app's EXISTING backend auth system
  // (/api/auth/register + /api/auth/login) with a deterministic demo account
  // for the selected role. This creates a REAL HoneyChain backend session
  // (JWT) — no fake Google account, no fake Firebase token, no second auth
  // system — so dashboards, requests and profile all work against real data.
  // TO RESTORE: set kGoogleAuthBypassEnabled to false. The original Google
  // implementation below is preserved verbatim.
  static const bool kGoogleAuthBypassEnabled = true;

  Future<void> signInWithGoogle([UserRole? role]) async {
    if (kGoogleAuthBypassEnabled) {
      await _demoOnlyBypassedGoogleSignIn(role);
      return;
    }
    return _signInWithGoogleOriginal(role);
  }

  /// DEMO ONLY: Google Auth temporarily bypassed.
  ///
  /// Signs in via the existing backend email/password auth using a fixed demo
  /// identity per selected role (e.g. demo.harvester@demo.honeychain.local).
  /// The account is created on first use (idempotent — an existing account
  /// for (email, role) is detected by the backend's ROLE_ACCOUNT_EXISTS check)
  /// and then logged in normally, so the app lands in the exact same
  /// post-login flow as any other backend-authenticated session.
  Future<void> _demoOnlyBypassedGoogleSignIn(UserRole? role) async {
    final activeRole = role ?? _selectedRole ?? UserRole.harvester;
    final roleStr = userRoleToString(activeRole);

    // Deterministic per-role demo identity. Not presented as a Google
    // account anywhere — the profile screen will simply show a normal
    // (email/password) HoneyChain account.
    final demoEmailSuffix = roleStr.toLowerCase();
    final demoEmail = 'demo.$demoEmailSuffix@demo.honeychain.local';
    const demoPassword = 'Demo-2026-HoneyChain';

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Ensure the demo account exists (existing backend register).
      final registerRes = await _client
          .post(
            Uri.parse('$_baseUrl/api/auth/register'),
            headers: _headers,
            body: jsonEncode({
              'name': 'Demo ${activeRole.displayName}',
              'email': demoEmail,
              'password': demoPassword,
              'role': roleStr,
            }),
          )
          .timeout(_authTimeout);

      // 409 ROLE_ACCOUNT_EXISTS is expected on every run after the first —
      // anything else is a real failure.
      if (registerRes.statusCode != 200 && registerRes.statusCode != 409) {
        _status = AuthStateStatus.error;
        _errorMessage = _extractErrorMessage(
          _decodeBody(registerRes),
          'Could not create the demo session. Please try again.',
        );
        notifyListeners();
        return;
      }

      // 2. Log in through the EXISTING backend login (same as email/password).
      final loginRes = await _client
          .post(
            Uri.parse('$_baseUrl/api/auth/login'),
            headers: _headers,
            body: jsonEncode({
              'emailOrPhone': demoEmail,
              'password': demoPassword,
              'role': roleStr,
            }),
          )
          .timeout(_authTimeout);

      if (loginRes.statusCode != 200) {
        _status = AuthStateStatus.error;
        _errorMessage = _extractErrorMessage(
          _decodeBody(loginRes),
          'Demo sign-in failed. Please try again.',
        );
        notifyListeners();
        return;
      }

      // 3. Persist the session exactly like the other auth methods do
      //    (same keys, same JWT, same post-login flow).
      final data = jsonDecode(loginRes.body) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      if (data['token'] != null) {
        await prefs.setString('auth_token', data['token']);
        AuthTokenStore.set(token: data['token']);
      }
      if (data['user'] != null) {
        final u = data['user'] as Map<String, dynamic>;
        if (u['id'] != null) {
          await prefs.setString('user_profile_id', u['id']);
          await prefs.setString('auth_user_id', u['id']);
          AuthTokenStore.set(userId: u['id']);
        }
        if (u['name'] != null) await prefs.setString('user_profile_name', u['name']);
        if (u['email'] != null) await prefs.setString('user_profile_email', u['email']);
        if (u['role'] != null) {
          await prefs.setString('user_profile_role', u['role']);
          _selectedRole = userRoleFromString(u['role']);
        }
        if (u['beekeeperId'] != null) await prefs.setString('user_profile_beekeeper_id', u['beekeeperId']);
      }
      await prefs.setString('user_profile_auth_provider', 'local');
      _currentUser = null; // no Firebase user exists in this mode
      _status = AuthStateStatus.authenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthController] DEMO ONLY Google bypass sign-in failed: $e');
      _status = AuthStateStatus.error;
      _errorMessage = 'Could not reach HoneyChain servers. Check your connection and try again.';
    }
    notifyListeners();
  }

  /// Original Google Sign-In flow (Firebase + backend exchange).
  /// DEMO ONLY: unreachable while [kGoogleAuthBypassEnabled] is true — kept
  /// verbatim for restoration.
  Future<void> _signInWithGoogleOriginal([UserRole? role]) async {
    final activeRole = role ?? _selectedRole ?? UserRole.harvester;
    final roleStr = userRoleToString(activeRole);

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        _status = AuthStateStatus.idle;
      } else {
        final firebaseUser = credential.user;
        if (firebaseUser == null) {
          _status = AuthStateStatus.error;
          _errorMessage = 'Google sign-in did not return a Firebase user. Please try again.';
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_profile_auth_provider', 'google');
          if (firebaseUser.uid.isNotEmpty) {
            await prefs.setString('user_profile_id', firebaseUser.uid);
          }
          if (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty) {
            await prefs.setString('user_profile_name', firebaseUser.displayName!);
          }
          if (firebaseUser.email != null && firebaseUser.email!.isNotEmpty) {
            await prefs.setString('user_profile_email', firebaseUser.email!);
          }
          if (firebaseUser.photoURL != null && firebaseUser.photoURL!.isNotEmpty) {
            await prefs.setString('user_profile_google_photo_url', firebaseUser.photoURL!);
            await prefs.setString('user_profile_photo_url', firebaseUser.photoURL!);
          }
          if (firebaseUser.phoneNumber != null && firebaseUser.phoneNumber!.isNotEmpty) {
            await prefs.setString('user_profile_phone', firebaseUser.phoneNumber!);
          }

          // Exchange the Firebase session for a real backend JWT. The backend
          // accepts either a Google OAuth2 ID token or a Firebase ID token —
          // this is a session exchange, not an optional profile sync: without
          // the returned token every subsequent API call (Add Hive, requests)
          // fails with 401 while the app looks logged in.
          try {
            final syncUrl = Uri.parse('$_baseUrl/api/auth/google');
            final idToken = await _authService.getIdToken();
            if (idToken == null || idToken.isEmpty) {
              _status = AuthStateStatus.error;
              _errorMessage = 'Firebase signed in with Google, but no ID token was returned.';
              await _authService.signOut();
              notifyListeners();
              return;
            }

            final response = await _client.post(
              syncUrl,
              headers: _firebaseBearerHeaders(idToken),
              body: jsonEncode({
                'name': firebaseUser.displayName,
                'email': firebaseUser.email,
                'phone': firebaseUser.phoneNumber,
                'role': roleStr,
                'photoUrl': firebaseUser.photoURL,
              }),
            ).timeout(_authTimeout);

            var exchangedBackendToken = false;
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['token'] != null) {
                await prefs.setString('auth_token', data['token']);
                AuthTokenStore.set(token: data['token']);
                exchangedBackendToken = true;
              }
              if (data['user'] != null) {
                final u = data['user'];
                if (u['id'] != null) {
                  await prefs.setString('user_profile_id', u['id']);
                  await prefs.setString('auth_user_id', u['id']);
                  AuthTokenStore.set(userId: u['id']);
                }
                if (u['beekeeperId'] != null) await prefs.setString('user_profile_beekeeper_id', u['beekeeperId']);
                if (u['role'] != null) {
                  await prefs.setString('user_profile_role', u['role']);
                  _selectedRole = userRoleFromString(u['role']);
                }
              }
              _currentUser = firebaseUser;
              _status = AuthStateStatus.authenticated;
            }

            // No backend session = the workflow cannot run. Surface it instead
            // of silently continuing to a dashboard where every call 401s.
            // _currentUser must be cleared too: isAuthenticated() is true
            // while it is set, so the error state would still route to the
            // (tokenless) dashboard instead of back to the login screen.
            if (!exchangedBackendToken) {
              _currentUser = null;
              _status = AuthStateStatus.error;
              await _authService.signOut();
              // Surface the backend's actual reason (e.g. an invalid Google ID
              // token) instead of a generic message that hides the cause.
              _errorMessage = _extractErrorMessage(
                _decodeBody(response),
                'Signed in with Google, but the server session could not be created. Please try again.',
              );
            }
          } catch (e) {
            debugPrint('[AuthController] Google backend session exchange failed: $e');
            _currentUser = null;
            _status = AuthStateStatus.error;
            await _authService.signOut();
            _errorMessage = 'Could not reach HoneyChain servers. Check your connection and try again.';
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthController] Google Firebase auth failed: ${e.code} ${e.message}');
      _status = AuthStateStatus.error;
      _errorMessage = e.message ?? 'Unable to complete Google authentication.';
    } catch (e) {
      debugPrint('[AuthController] Google authentication failed: $e');
      _status = AuthStateStatus.error;
      _errorMessage = 'Unable to complete Google authentication.';
    }
    notifyListeners();
  }

  /// Sign out and purge every cached profile key so no data leaks between
  /// accounts on a shared device.
  Future<void> signOut() async {
    await _authService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_SessionKeys.token);
    await prefs.remove(_SessionKeys.userId);
    await prefs.remove(_SessionKeys.profileId);
    await prefs.remove(_SessionKeys.profileName);
    await prefs.remove(_SessionKeys.profileEmail);
    await prefs.remove(_SessionKeys.profilePhone);
    await prefs.remove(_SessionKeys.profileRole);
    await prefs.remove('user_profile_avatar_url');
    await prefs.remove('user_profile_google_photo_url');
    await prefs.remove('user_profile_photo_url');
    await prefs.remove('user_profile_organization');
    await prefs.remove('user_profile_location');
    await prefs.remove('user_profile_license');
    await prefs.remove('user_profile_designation');
    await prefs.remove(_SessionKeys.beekeeperId);
    await prefs.remove('user_profile_bsid');
    await prefs.remove('user_profile_bsp_pass');
    await prefs.remove(_SessionKeys.profileAuthProvider);
    AuthTokenStore.clear();
    _currentUser = null;
    _selectedRole = null;
    _status = AuthStateStatus.idle;
    _mode = AuthMode.phoneEntry;
    _verificationId = null;
    _resendToken = null;
    _pendingPhone = '';
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }
}
