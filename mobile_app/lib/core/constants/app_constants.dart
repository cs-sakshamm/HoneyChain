import 'package:flutter/material.dart';

/// Production Design System & App Constants for HoneyChain Mobile
class AppConstants {
  AppConstants._();

  // App Identity
  static const String appName = 'HoneyChain';
  static const String appTagline = 'Supply chain management simplified for business owners.';
  static const String legalDisclaimer =
      'By continuing, you agree to HoneyChain\'s Terms of Service and Privacy Policy.';

  // Design Tokens: Color Palette (Senior SaaS Product Palette)
  static const Color primary = Color(0xFFD97706); // Warm Honey Amber
  static const Color honeyAccent = primary; // Alias for compatibility
  static const Color primaryDark = Color(0xFFB45309); // Deep Amber
  static const Color primarySoft = Color(0xFFFFFBEB); // Soft Amber Tint
  static const Color secondary = Color(0xFF4B5563); // Muted Secondary Color

  static const Color background = Color(0xFFF9FAFB); // Neutral Light Background (Gray-50)
  static const Color surface = Color(0xFFFFFFFF); // Pure White Surface
  static const Color border = Color(0xFFE5E7EB); // Subtle Border (Gray-200)
  static const Color borderFocus = Color(0xFFD97706); // Active Input Focus

  static const Color textPrimary = Color(0xFF111827); // Dark Neutral (Gray-900)
  static const Color textSecondary = Color(0xFF4B5563); // Muted Body Text (Gray-600)
  static const Color textMuted = Color(0xFF9CA3AF); // Placeholder / Caption (Gray-400)

  static const Color success = Color(0xFF059669); // Emerald Success
  static const Color successBackground = Color(0xFFECFDF5);
  static const Color error = Color(0xFFDC2626); // Production Error Red
  static const Color errorBackground = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFD97706); // Warning Amber

  // Spacing Tokens (4px Grid System)
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // Component Dimensions
  static const double buttonHeight = 48.0;
  static const double inputHeight = 48.0;
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;

  // Auth Text & Strings
  static const String loginTitle = 'Welcome back';
  static const String loginSubtitle = 'Sign in to continue to HoneyChain.';
  static const String brandHeadline = 'Everything you need, connected in one place.';
  static const String brandSubtitle = 'Sign in to continue your HoneyChain experience.';
  static const String emailLabel = 'Email address';
  static const String emailHint = 'Enter your email address';
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Enter your password';
  static const String loginButtonText = 'Sign in';
  static const String createAccountButtonText = 'Create account';
  static const String forgotPasswordText = 'Forgot password?';
  static const String orDividerText = 'OR';

  // Provider Tooltips & Text
  static const String continueWithGoogleText = 'Continue with Google';
  static const String continueWithPhoneText = 'Continue with phone';

  // Navigation Links
  static const String dontHaveAccountText = "New to HoneyChain? ";
  static const String createAccountLinkText = 'Create Business Account';
  static const String alreadyHaveAccountText = 'Already have an account? Sign In';

  // OTP Verification
  static const String phoneOtpTitle = 'Security Verification';
  static const String phoneOtpSubtitle = 'Enter the 6-digit code sent to your registered phone number.';
  static const String enterPhoneNumberHint = 'Mobile phone number (+1 234 567 8900)';
  static const String sendOtpButtonText = 'Send Verification Code';
  static const String verifyOtpButtonText = 'Verify & Access Dashboard';
  static const String resendOtpText = 'Resend Code';

  // Password Reset
  static const String resetPasswordTitle = 'Reset Password';
  static const String resetPasswordSubtitle = 'Enter your business email or phone to receive reset instructions.';
  static const String sendResetLinkText = 'Send Reset Instructions';

  // Status & Feedback
  static const String signingInText = 'Authenticating...';
  static const String authErrorText = 'Invalid credentials. Please verify your details and try again.';
  static const String tryAgainText = 'Try Again';

  // Logout Dialog
  static const String logoutTitle = 'Confirm Log Out';
  static const String logoutSubtitle = 'Are you sure you want to end your current session?';
  static const String logoutCancel = 'Cancel';
  static const String logoutConfirm = 'Log Out';
}
