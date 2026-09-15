import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../localization/localization_service.dart';
import '../theme/app_theme.dart';
import '../../features/profile/controllers/user_controller.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/verification/controllers/verification_controller.dart';
import '../../features/verification/screens/collector_verification_screen.dart';
import '../../features/verification/screens/harvester_verification_screen.dart';
import '../../features/verification/screens/lab_verification_screen.dart';
import '../../features/verification/screens/packaging_verification_screen.dart';

/// Centralized profile and role verification completion guard for HoneyChain.
/// Enforces mandatory profile completion and backend profile verification
/// before allowing any role-specific workflow actions across Harvester,
/// Collection & Processing, Lab Testing, and Packaging Manager roles.
class ProfileGuard {
  ProfileGuard._();

  /// Checks if the current user's basic profile is complete.
  static bool checkOrPrompt(BuildContext context) {
    final userCtrl = context.read<UserController>();
    if (userCtrl.user.isProfileComplete) {
      return true;
    }

    showIncompleteProfileDialog(context);
    return false;
  }

  /// 1. Harvester Verification Guard
  /// Checks if a Harvester has completed both profile and 3-step Harvester Verification.
  static bool checkHarvesterVerificationOrPrompt(BuildContext context) {
    final verCtrl = context.read<VerificationController>();
    if (verCtrl.verification.isFullyVerified) return true;

    final userCtrl = context.read<UserController>();
    if (!userCtrl.user.isProfileComplete) {
      showIncompleteProfileDialog(context);
      return false;
    }

    showHarvesterVerificationDialog(context);
    return false;
  }

  /// 2. Collection & Processing Verification Guard
  /// Checks if a Collector/Processor has completed 3/3 profile verification.
  static bool checkCollectorVerificationOrPrompt(BuildContext context) {
    final verCtrl = context.read<VerificationController>();
    if (verCtrl.collectorVerification.isFullyVerified) return true;

    final userCtrl = context.read<UserController>();
    if (!userCtrl.user.isProfileComplete) {
      showIncompleteProfileDialog(context);
      return false;
    }

    showCollectorVerificationDialog(context);
    return false;
  }

  /// 3. Lab Tester Verification Guard
  /// Checks if a Lab Tester has completed 3/3 profile verification.
  static bool checkLabVerificationOrPrompt(BuildContext context) {
    final verCtrl = context.read<VerificationController>();
    if (verCtrl.labVerification.isFullyVerified) return true;

    final userCtrl = context.read<UserController>();
    if (!userCtrl.user.isProfileComplete) {
      showIncompleteProfileDialog(context);
      return false;
    }

    showLabVerificationDialog(context);
    return false;
  }

  /// 4. Packaging Manager Verification Guard
  /// Checks if a Packaging Manager has completed 3/3 profile verification.
  static bool checkPackagingVerificationOrPrompt(BuildContext context) {
    final verCtrl = context.read<VerificationController>();
    if (verCtrl.packagingVerification.isFullyVerified) return true;

    final userCtrl = context.read<UserController>();
    if (!userCtrl.user.isProfileComplete) {
      showIncompleteProfileDialog(context);
      return false;
    }

    showPackagingVerificationDialog(context);
    return false;
  }

  /// Displays the modal dialog prompting the user to complete their profile.
  static void showIncompleteProfileDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dialogContext.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : dialogContext.borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppConstants.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    color: AppConstants.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Please Complete Your Profile First',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: dialogContext.textPrimaryColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Complete your profile and required details before continuing with this role action.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: dialogContext.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: dialogContext.textSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dialogContext.colors.primary,
                          foregroundColor: dialogContext.colors.onPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Complete Profile',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dialog prompting the harvester to complete Harvester Verification.
  static void showHarvesterVerificationDialog(BuildContext context) {
    _showVerificationRequiredDialog(
      context: context,
      title: 'Harvester Verification Required',
      description: 'Complete profile verification to add hives and start harvesting activities.',
      buttonLabel: 'Verify Profile',
      onConfirm: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HarvesterVerificationScreen()),
      ),
    );
  }

  /// Alias for backward compatibility
  static void showIncompleteVerificationDialog(BuildContext context) {
    showHarvesterVerificationDialog(context);
  }

  /// Dialog prompting the collector to complete Collection & Processing Verification.
  static void showCollectorVerificationDialog(BuildContext context) {
    _showVerificationRequiredDialog(
      context: context,
      title: 'Collection & Processing Verification Required',
      description: 'Complete profile verification to start collection & processing activities.',
      buttonLabel: 'Complete Verification',
      onConfirm: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CollectorVerificationScreen()),
      ),
    );
  }

  /// Dialog prompting the lab tester to complete Laboratory Verification.
  static void showLabVerificationDialog(BuildContext context) {
    _showVerificationRequiredDialog(
      context: context,
      title: 'Laboratory Testing Verification Required',
      description: 'Complete profile verification to accept and perform laboratory testing requests.',
      buttonLabel: 'Complete Verification',
      onConfirm: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LabVerificationScreen()),
      ),
    );
  }

  /// Dialog prompting the packaging manager to complete Packaging Verification.
  static void showPackagingVerificationDialog(BuildContext context) {
    _showVerificationRequiredDialog(
      context: context,
      title: 'Packaging Verification Required',
      description: 'Complete profile verification to start packaging activities.',
      buttonLabel: 'Complete Verification',
      onConfirm: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PackagingVerificationScreen()),
      ),
    );
  }

  static void _showVerificationRequiredDialog({
    required BuildContext context,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dialogContext.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : dialogContext.borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppConstants.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppConstants.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: dialogContext.textPrimaryColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: dialogContext.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: dialogContext.textSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dialogContext.colors.primary,
                          foregroundColor: dialogContext.colors.onPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          buttonLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
