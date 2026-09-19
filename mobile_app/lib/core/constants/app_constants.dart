import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

/// Production Design System & App Constants for HoneyChain Mobile
class AppConstants {
  AppConstants._();

  // App Identity
  static const String appName = 'HoneyChain';
  static const String appTagline = 'Supply chain management simplified for business owners.';

  /// Raw dart-define override (always wins when provided)
  static const String _backendUrlOverride = String.fromEnvironment('BACKEND_URL');

  /// Backend / API base (single source of truth for app → backend calls).
  ///
  /// - Explicit build override : --dart-define=BACKEND_URL=http://host:8000
  /// - Web                     : localhost:8000 (backend must allow this origin; CORS is open)
  /// - Android emulator        : 10.0.2.2:8000 (host loopback alias)
  /// - Native desktop          : localhost:8000
  static String get backendBaseUrl {
    if (_backendUrlOverride.isNotEmpty) return _backendUrlOverride;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'http://localhost:8000';
    }
    return 'http://10.0.2.2:8000'; // Android emulator host-loopback alias
  }

  /// Public verification base URL for customer QR codes.
  static const String _publicVerifyUrlOverride = String.fromEnvironment('PUBLIC_VERIFY_URL');

  static String get publicVerificationBaseUrl {
    if (_publicVerifyUrlOverride.isNotEmpty) return _publicVerifyUrlOverride.replaceAll(RegExp(r'/+$'), '');
    return 'https://generates-keep-michael-truck.trycloudflare.com';
  }

  static const String legalDisclaimer =
      'By continuing, you agree to HoneyChain\'s Terms of Service and Privacy Policy.';

  // Design Tokens: Color Palette (Honey Brand & Neutrals)
  // Honey is the single brand accent across BOTH themes (buttons, icons,
  // highlights, active states, progress). Neutrals carry the surfaces/text.
  static const Color primary = honeyAccent; // Honey — brand primary
  static const Color onPrimary = Color(0xFF1C1917); // Stone-900: readable on honey
  static const Color honeyAccent = Color(0xFFEAB308); // Yellow-500 (Honey)
  static const Color primaryDark = Color(0xFF09090B); // Zinc-950
  static const Color primarySoft = Color(0xFFF4F4F5); // Zinc-100 (neutral soft container)
  static const Color secondary = Color(0xFF52525B); // Zinc-500

  static const Color background = Color(0xFFF9FAFB); // Neutral Off-White Background
  static const Color surface = Color(0xFFFFFFFF); // Pure White Surface
  static const Color border = Color(0xFFE4E4E7); // Zinc-200
  static const Color borderFocus = Color(0xFFEAB308); // Honey Accent

  static const Color textPrimary = Color(0xFF09090B); // Zinc-950
  static const Color textSecondary = Color(0xFF52525B); // Zinc-500
  static const Color textMuted = Color(0xFFA1A1AA); // Zinc-400

  static const Color success = Color(0xFF22C55E); // Green-500
  static const Color successBackground = Color(0xFFF0FDF4); // Green-50
  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color errorBackground = Color(0xFFFEF2F2); // Red-50
  static const Color warning = Color(0xFFF59E0B); // Amber-500
  static const Color warningBackground = Color(0xFFFFFBEB); // Amber-50

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
  static const String googleRecommendationText = 'Recommended for faster sign-in';
  static const String continueWithGoogleText = 'Continue with Google';
  static const String googleSignInText = 'Sign in with Google';
  static const String appleSignInText = 'Sign in with Apple';

  // Navigation Links
  static const String dontHaveAccountText = "Don't have an account? ";
  static const String createAccountLinkText = 'Create account';
  static const String alreadyHaveAccountText = 'Already have an account? Sign In';

  // Password Reset
  static const String resetPasswordTitle = 'Reset Password';
  static const String resetPasswordSubtitle = 'Enter your registered email address to receive reset instructions.';
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

  // Harvester identity (issued by backend when available; locally unique otherwise)
  static const String bsidPrefix = 'BSID';
  static const String bspPassPrefix = 'BSP';
}

class RoleImageItem {
  final String url;
  final String label;
  final String localAssetFallback;

  const RoleImageItem({
    required this.url,
    required this.label,
    required this.localAssetFallback,
  });
}

class RoleImages {
  // 1. HARVESTER: Beekeeping, Beehives, Bees, Honey Harvesting (Exactly 1 Hero Image)
  static const List<RoleImageItem> harvesterImages = [
    RoleImageItem(
      url: 'assets/images/beekeeping_hero.webp',
      label: 'Beekeeping and hive inspection in active apiary',
      localAssetFallback: 'assets/images/beekeeping_hero.webp',
    ),
  ];

  // 2. COLLECTION & PROCESSING: Honey Extraction & Processing Facility (Exactly 1 Hero Image)
  static const List<RoleImageItem> collectionProcessingImages = [
    RoleImageItem(
      url: 'assets/images/collection_processing_hero.webp',
      label: 'Regional honey collection and centrifugal extraction facility',
      localAssetFallback: 'assets/images/collection_processing_hero.webp',
    ),
  ];

  // 3. LAB TESTER: Food Laboratory & Purity Testing (Exactly 1 Hero Image)
  static const List<RoleImageItem> labTesterImages = [
    RoleImageItem(
      url: 'assets/images/lab_testing_hero.webp',
      label: 'Advanced food laboratory testing honey purity and quality',
      localAssetFallback: 'assets/images/lab_testing_hero.webp',
    ),
  ];

  // 4. PACKAGING: Honey Bottling & Sealed Packaging Line (Exactly 1 Hero Image)
  static const List<RoleImageItem> packagingImages = [
    RoleImageItem(
      url: 'assets/packaging_hero.jpg',
      label: 'Automated honey bottling line and sealed batch packaging',
      localAssetFallback: 'assets/packaging_hero.jpg',
    ),
  ];

  static List<RoleImageItem> getImagesForRole(String role) {
    final r = role.toUpperCase();
    if (r.contains('COLLECT') || r.contains('PROCESS')) {
      return collectionProcessingImages;
    } else if (r.contains('LAB')) {
      return labTesterImages;
    } else if (r.contains('PKG') || r.contains('PACKAG')) {
      return packagingImages;
    }
    return harvesterImages;
  }

  static IconData getRoleIcon(String role) {
    final r = role.toUpperCase();
    if (r.contains('COLLECT') || r.contains('PROCESS')) {
      return Icons.precision_manufacturing_rounded;
    } else if (r.contains('LAB')) {
      return Icons.science_rounded;
    } else if (r.contains('PKG') || r.contains('PACKAG')) {
      return Icons.inventory_2_rounded;
    }
    return Icons.hive_rounded;
  }
}
