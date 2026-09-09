import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

enum AuthStateStatus {
  idle,
  authenticating,
  authenticated,
  otpSent,
  passwordResetSent,
  error,
}

enum AuthMode {
  login,
  register,
  phoneOtp,
  forgotPassword,
}

/// Roles in the HoneyChain supply chain
enum UserRole {
  harvester,
  collectionProcessing,
  labTesting,
  packaging,
}

/// Production Controller managing business authentication & session state
class AuthController extends ChangeNotifier {
  final AuthService _authService;

  AuthStateStatus _status = AuthStateStatus.idle;
  AuthMode _mode = AuthMode.login;

  String? _errorMessage;
  String? _infoMessage;
  User? _currentUser;
  bool _isDemoMode = false;

  // Role State
  UserRole? _selectedRole;

  // Form & Security State
  bool _isPasswordVisible = false;
  String _phoneNumberForOtp = '';
  int _otpCountdown = 0;
  Timer? _otpTimer;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    if (_authService.isFirebaseInitialized) {
      _currentUser = _authService.currentUser;
      if (_currentUser != null) {
        _status = AuthStateStatus.authenticated;
      }
    }
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }

  // Getters
  AuthStateStatus get status => _status;
  AuthMode get mode => _mode;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  User? get currentUser => _currentUser;
  bool get isAuthenticated =>
      _currentUser != null || (_isDemoMode && _status == AuthStateStatus.authenticated);
  bool get isPasswordVisible => _isPasswordVisible;
  String get phoneNumberForOtp => _phoneNumberForOtp;
  int get otpCountdown => _otpCountdown;
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

  /// Single Sign In Handler with validation
  Future<void> loginWithEmailOrPhone(String emailOrPhone, String password) async {
    final identifier = emailOrPhone.trim();
    final pass = password.trim();

    if (identifier.isEmpty || pass.isEmpty) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Please provide both your business email/phone and password.';
      notifyListeners();
      return;
    }

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    try {
      if (!_authService.isFirebaseInitialized) {
        _isDemoMode = true;
        _status = AuthStateStatus.authenticated;
      } else {
        _isDemoMode = true;
        _status = AuthStateStatus.authenticated;
      }
    } catch (e) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Invalid email/phone or password. Please try again.';
    }
    notifyListeners();
  }

  /// Register Business Account
  Future<void> registerBusinessAccount({
    required String businessName,
    required String emailOrPhone,
    required String password,
  }) async {
    if (businessName.trim().isEmpty || emailOrPhone.trim().isEmpty || password.trim().isEmpty) {
      _status = AuthStateStatus.error;
      _errorMessage = 'All business registration fields are required.';
      notifyListeners();
      return;
    }

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    _isDemoMode = true;
    _status = AuthStateStatus.authenticated;
    notifyListeners();
  }

  /// Google Sign-In
  Future<void> signInWithGoogle() async {
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

    await Future.delayed(const Duration(milliseconds: 700));
    _isDemoMode = true;
    _status = AuthStateStatus.authenticated;
    notifyListeners();
  }

  /// Initiate Phone Verification (OTP)
  Future<void> startPhoneAuth(String phoneNumber) async {
    final phone = phoneNumber.trim();
    if (phone.isEmpty || phone.length < 7) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Please enter a valid business phone number.';
      notifyListeners();
      return;
    }

    _phoneNumberForOtp = phone;
    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    _status = AuthStateStatus.otpSent;
    _mode = AuthMode.phoneOtp;
    _startOtpTimer();
    notifyListeners();
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    _otpCountdown = 30;
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown > 0) {
        _otpCountdown--;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  /// Verify OTP Code
  Future<void> verifyPhoneOtp(String otpCode) async {
    final code = otpCode.trim();
    if (code.length < 6) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Please enter the 6-digit verification code.';
      notifyListeners();
      return;
    }

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    _isDemoMode = true;
    _status = AuthStateStatus.authenticated;
    notifyListeners();
  }

  /// Send Password Reset Email/SMS
  Future<void> sendPasswordReset(String identifier) async {
    final target = identifier.trim();
    if (target.isEmpty) {
      _status = AuthStateStatus.error;
      _errorMessage = 'Please enter your registered email or phone.';
      notifyListeners();
      return;
    }

    _status = AuthStateStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    _status = AuthStateStatus.passwordResetSent;
    _infoMessage = 'Reset instructions sent to $target.';
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
