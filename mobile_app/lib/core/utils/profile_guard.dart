import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../localization/localization_service.dart';
import '../theme/app_theme.dart';
import '../../features/profile/controllers/user_controller.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/verification/controllers/verification_controller.dart';
import '../../features/verification/screens/harvester_verification_screen.dart';

/// Centralized profile and harvester verification completion guard for HoneyChain.
/// Enforces mandatory profile completion before allowing any workflow actions
/// across Harvester, Collection & Processing, Lab Testing, and Packaging roles.
/// Also enforces mandatory 5-parameter Harvester Verification for Harvester actions.
class ProfileGuard {
  ProfileGuard._();

  /// Checks if the current user's profile is complete.
  /// If complete, returns `true`.
  /// If incomplete, displays the standardized HoneyChain profile completion dialog and returns `false`.
  static bool checkOrPrompt(BuildContext context) {
    final userCtrl = context.read<UserController>();
    if (userCtrl.user.isProfileComplete) {
      return true;
    }

    showIncompleteProfileDialog(context);
    return false;
  }

  /// Checks if a Harvester has completed BOTH profile completeness AND 5-parameter Harvester Verification.
  /// If complete and fully verified on-chain, returns `true`.
  /// If profile is incomplete, prompts to complete profile.
  /// If profile is complete but verification is not 'Verified', prompts to complete Harvester Verification.
  static bool checkHarvesterVerificationOrPrompt(BuildContext context) {
    final userCtrl = context.read<UserController>();
    if (!userCtrl.user.isProfileComplete) {
      showIncompleteProfileDialog(context);
      return false;
    }

    final verCtrl = context.read<VerificationController>();
    if (!verCtrl.verification.isFullyVerified) {
      showIncompleteVerificationDialog(context);
      return false;
    }

    return true;
  }

  /// Displays the standardized modern modal dialog prompting the user to complete their profile.
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
                // Warning / Shield Icon
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

                // Title
                Text(
                  dialogContext.tr('profile_incomplete_title') != 'profile_incomplete_title'
                      ? dialogContext.tr('profile_incomplete_title')
                      : 'Please Complete Your Profile First',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: dialogContext.textPrimaryColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  'Complete your profile and required details (Name, Email, Phone) before you can continue with this action.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: dialogContext.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Actions: Cancel & Complete Profile
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          dialogContext.tr('cancel') != 'cancel'
                              ? dialogContext.tr('cancel')
                              : 'Cancel',
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

  /// Displays the standardized modern modal dialog prompting the harvester to complete Harvester Verification.
  static void showIncompleteVerificationDialog(BuildContext context) {
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
                // Shield / Verification Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppConstants.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppConstants.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  'Harvester Verification Required',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: dialogContext.textPrimaryColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  'You must complete the 5-parameter Harvester Verification before you can register hives or initiate harvest sessions on HoneyChain.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: dialogContext.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Actions: Cancel & Verify Now
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
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
                              builder: (context) => const HarvesterVerificationScreen(),
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
                          'Verify Now',
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
