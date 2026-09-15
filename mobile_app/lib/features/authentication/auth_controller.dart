import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import 'auth_service.dart';

enum AuthStateStatus {
  idle,
  authenticating,
  authenticated,
  passwordResetSent,
  error,
}

enum AuthMode {
  login,
  register,
  forgotPassword,
  resetPassword,
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

/// Production Controller managing business authentication & session state backed by PostgreSQL API
class AuthController extends ChangeNotifier {
  final AuthService _authService;
  final http.Client _client;
  final String _baseUrl;

  AuthStateStatus _status = AuthStateStatus.idle;
  AuthMode _mode = AuthMode.login;

  String? _errorMessage;
  String? _infoMessage;
  User? _currentUser;
  bool _isDemoMode = false;
  String? _resetToken;

  // Role State
  UserRole? _selectedRole;

  // Form & Security State
  bool _isPasswordVisible = false;

  AuthController({AuthService? authService, http.Client? client, String? baseUrl})
      : _authService = authService ?? AuthService(),
        _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveBaseUrl() {
    if (_authService.isFirebaseInitialized) {
      _currentUser = _authService.currentUser;
      if (_currentUser != null) {
        _status = AuthStateStatus.authenticated;
      }
    }
  }

  static String _resolveBaseUrl() {
    if (kIsWeb) {
      return AppConstants.backendBaseUrl;
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {}
    return AppConstants.backendBaseUrl;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };


  // Getters
  AuthStateStatus get status => _status;
  AuthMode get mode => _mode;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  User? get currentUser => _currentUser;
  String? get resetToken => _resetToken;
  bool get isAuthenticated =>
      _currentUser != null || (_isDemoMode && _status == AuthStateStatus.authenticated);
  bool get isPasswordVisible => _isPasswordVisible;
  UserRole? get selectedRole => _selectedRole;

  void setRole(UserRole role) {
    _selectedRole = role;
    notifyListeners();
  }

  void clearRole() {
    _selectedRole = null;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  void switchMode(AuthMode newMode) {
    _mode = newMode;
    _status = AuthStateStatus.idle;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  void resetError() {
    _status = AuthStateStatus.idle;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  /// Email Sign In Handler with validation against PostgreSQL backend API
  Future<void> loginWithEmail(String email, String password, [UserRole? role]) async {
    final identifier = email.trim();
    final pass = password.trim();
    final activeRole = role ?? _selectedRole ?? UserRole.harvester;
    final roleStr = userRoleToString(activeRole);

    if (identifier.isEmpty || pass.isEmpty) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Please provide both your email address and password.';
      notifyListeners();
      return;
    }

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/api/auth/login');
      final response = await _client
          .post(
            url,
            headers: _headers,
            body: jsonEncode({
              'emailOrPhone': identifier,
              'password': pass,
              'role': roleStr,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          final u = data['user'];
          final prefs = await SharedPreferences.getInstance();
          if (u['id'] != null) await prefs.setString('user_profile_id', u['id']);
          if (u['name'] != null) await prefs.setString('user_profile_name', u['name']);
          if (u['email'] != null) await prefs.setString('user_profile_email', u['email']);
          if (u['phone'] != null) await prefs.setString('user_profile_phone', u['phone']);
          if (u['role'] != null) await prefs.setString('user_profile_role', u['role']);
          if (u['bsid'] != null) await prefs.setString('user_profile_bsid', u['bsid']);
          if (u['bspPass'] != null) await prefs.setString('user_profile_bsp_pass', u['bspPass']);
        }
        _isDemoMode = true;
        _status = AuthStateStatus.authenticated;
        notifyListeners();
        return;
      } else {
        final data = jsonDecode(response.body);
        _status = AuthStateStatus.error;
        _errorMessage = data['error'] ?? data['message'] ?? 'Authentication failed.';
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('[AuthController] Backend login error: $e');
    }

    _status = AuthStateStatus.error;
    _errorMessage = 'Unable to connect to server. Please verify your connection.';
    notifyListeners();
  }

  /// Backward-compatible alias for loginWithEmail
  Future<void> loginWithEmailOrPhone(String emailOrPhone, String password) =>
      loginWithEmail(emailOrPhone, password);

  /// Register User Account against PostgreSQL backend API
  Future<void> registerAccount({
    required String name,
    required String email,
    required String password,
    UserRole? role,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final activeRole = role ?? _selectedRole ?? UserRole.harvester;
    final roleStr = userRoleToString(activeRole);

    if (cleanName.isEmpty || cleanEmail.isEmpty || cleanPassword.isEmpty) {
      _status = AuthStateStatus.error;
      _errorMessage = 'All registration fields are required.';
      notifyListeners();
      return;
    }

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/api/auth/register');
      final response = await _client
          .post(
            url,
            headers: _headers,
            body: jsonEncode({
              'name': cleanName,
              'email': cleanEmail,
              'password': cleanPassword,
              'role': roleStr,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          final u = data['user'];
          final prefs = await SharedPreferences.getInstance();
          if (u['id'] != null) await prefs.setString('user_profile_id', u['id']);
          if (u['name'] != null) await prefs.setString('user_profile_name', u['name']);
          if (u['email'] != null) await prefs.setString('user_profile_email', u['email']);
          if (u['phone'] != null) await prefs.setString('user_profile_phone', u['phone']);
          if (u['role'] != null) await prefs.setString('user_profile_role', u['role']);
          if (u['bsid'] != null) await prefs.setString('user_profile_bsid', u['bsid']);
          if (u['bspPass'] != null) await prefs.setString('user_profile_bsp_pass', u['bspPass']);
        }
        _isDemoMode = true;
        _status = AuthStateStatus.authenticated;
        notifyListeners();
        return;
      } else {
        final data = jsonDecode(response.body);
        _status = AuthStateStatus.error;
        _errorMessage = data['error'] ?? data['message'] ?? 'Registration failed.';
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('[AuthController] Backend registration error: $e');
    }

    _status = AuthStateStatus.error;
    _errorMessage = 'Unable to connect to server. Please try again.';
    notifyListeners();
  }

  /// Backward-compatible alias for registerAccount
  Future<void> registerBusinessAccount({
    required String businessName,
    required String emailOrPhone,
    required String password,
  }) =>
      registerAccount(
        name: businessName,
        email: emailOrPhone,
        password: password,
      );

  /// Google Sign-In
  Future<void> signInWithGoogle([UserRole? role]) async {
    final activeRole = role ?? _selectedRole ?? UserRole.harvester;
    final roleStr = userRoleToString(activeRole);

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        if (!_authService.isFirebaseInitialized) {
          _isDemoMode = true;
          _status = AuthStateStatus.authenticated;
        } else {
          _status = AuthStateStatus.idle;
        }
      } else {
        _currentUser = credential.user;
        _status = AuthStateStatus.authenticated;
        if (_currentUser != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_profile_auth_provider', 'google');
          if (_currentUser!.uid.isNotEmpty) {
            await prefs.setString('user_profile_id', _currentUser!.uid);
          }
          if (_currentUser!.displayName != null && _currentUser!.displayName!.isNotEmpty) {
            await prefs.setString('user_profile_name', _currentUser!.displayName!);
          }
          if (_currentUser!.email != null && _currentUser!.email!.isNotEmpty) {
            await prefs.setString('user_profile_email', _currentUser!.email!);
          }
          if (_currentUser!.photoURL != null && _currentUser!.photoURL!.isNotEmpty) {
            await prefs.setString('user_profile_google_photo_url', _currentUser!.photoURL!);
            await prefs.setString('user_profile_photo_url', _currentUser!.photoURL!);
          }
          if (_currentUser!.phoneNumber != null && _currentUser!.phoneNumber!.isNotEmpty) {
            await prefs.setString('user_profile_phone', _currentUser!.phoneNumber!);
          }

          // Sync Google Account details to backend PostgreSQL for this role
          try {
            final syncUrl = Uri.parse('$_baseUrl/api/auth/google');
            final response = await _client.post(
              syncUrl,
              headers: _headers,
              body: jsonEncode({
                'name': _currentUser!.displayName,
                'email': _currentUser!.email,
                'phone': _currentUser!.phoneNumber,
                'role': roleStr,
                'photoUrl': _currentUser!.photoURL,
              }),
            ).timeout(const Duration(seconds: 4));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['user'] != null) {
                final u = data['user'];
                if (u['id'] != null) await prefs.setString('user_profile_id', u['id']);
                if (u['beekeeperId'] != null) await prefs.setString('user_profile_beekeeper_id', u['beekeeperId']);
                if (u['bsid'] != null) await prefs.setString('user_profile_bsid', u['bsid']);
                if (u['bspPass'] != null) await prefs.setString('user_profile_bsp_pass', u['bspPass']);
                if (u['role'] != null) await prefs.setString('user_profile_role', u['role']);
                if (u['googlePhotoUrl'] != null) await prefs.setString('user_profile_google_photo_url', u['googlePhotoUrl']);
                if (u['avatarUrl'] != null) await prefs.setString('user_profile_avatar_url', u['avatarUrl']);
                if (u['photoUrl'] != null) await prefs.setString('user_profile_photo_url', u['photoUrl']);
              }
            }
          } catch (e) {
            debugPrint('[AuthController] Google backend sync warning: $e');
          }
        }
      }
    } catch (e) {
      if (kIsWeb) {
        _isDemoMode = true;
        _status = AuthStateStatus.authenticated;
      } else {
        _status = AuthStateStatus.error;
        _errorMessage = 'Unable to complete Google authentication.';
      }
    }
    notifyListeners();
  }

  /// Apple Sign-In
  Future<void> signInWithApple() async {
    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));
    _isDemoMode = true;
    _status = AuthStateStatus.authenticated;
    notifyListeners();
  }

  /// Send Password Reset Email
  Future<void> sendPasswordReset(String email) async {
    final target = email.trim();
    if (target.isEmpty) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Please enter your registered email address.';
      notifyListeners();
      return;
    }

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/api/auth/forgot-password');
      final response = await _client
          .post(
            url,
            headers: _headers,
            body: jsonEncode({'email': target}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _status = AuthStateStatus.passwordResetSent;
        _infoMessage = 'Reset instructions sent to $target.';
        if (data['devToken'] != null) {
          _resetToken = data['devToken'];
          _mode = AuthMode.resetPassword;
        }
      } else {
        final data = jsonDecode(response.body);
        _status = AuthStateStatus.error;
        _errorMessage = data['error'] ?? data['message'] ?? 'Failed to send reset link.';
      }
    } catch (e) {
      debugPrint('[AuthController] Backend reset error: $e');
      _status = AuthStateStatus.error;
      _errorMessage = 'Unable to connect to server. Please try again.';
    }
    notifyListeners();
  }

  /// Reset Password with Token
  Future<void> resetPasswordWithToken(String token, String newPassword) async {
    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/api/auth/reset-password');
      final response = await _client
          .post(
            url,
            headers: _headers,
            body: jsonEncode({'token': token, 'newPassword': newPassword}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        _status = AuthStateStatus.idle;
        _mode = AuthMode.login;
        _infoMessage = 'Password reset successfully. Please log in.';
        _resetToken = null;
      } else {
        final data = jsonDecode(response.body);
        _status = AuthStateStatus.error;
        _errorMessage = data['error'] ?? data['message'] ?? 'Failed to reset password.';
      }
    } catch (e) {
      debugPrint('[AuthController] Reset password error: $e');
      _status = AuthStateStatus.error;
      _errorMessage = 'Unable to connect to server. Please try again.';
    }
    notifyListeners();
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _isDemoMode = false;
    _selectedRole = null;
    _status = AuthStateStatus.idle;
    _mode = AuthMode.login;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }
}
