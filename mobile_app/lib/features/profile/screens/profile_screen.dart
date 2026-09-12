import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../authentication/auth_controller.dart';
import '../../authentication/widgets/google_logo_icon.dart';
import '../../verification/controllers/verification_controller.dart';
import '../../verification/screens/harvester_verification_screen.dart';
import '../../verification/screens/verification_certificate_screen.dart';
import '../controllers/user_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'language_setting_screen.dart';
import 'theme_setting_screen.dart';

/// Profile page — polished card-based layout, pill actions, both themes.
/// The old notification ON/OFF toggle has been removed by design.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            dialogContext.tr('logout'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Confirm logging out of your account?',
            style: GoogleFonts.inter(fontSize: 14, color: dialogContext.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('cancel'), style: GoogleFonts.inter(color: dialogContext.textSecondaryColor, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<AuthController>().signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: Text(dialogContext.tr('logout'), style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userCtrl = context.watch<UserController>();
    final user = userCtrl.user;
    final complete = user.isProfileComplete;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppConstants.space24),
              Text(
                context.tr('profile'),
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppConstants.space24),

              // ── Profile card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.space24),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  children: [
                    const UserAvatar(size: 80),
                    const SizedBox(height: AppConstants.space16),
                    Text(
                      user.name.isEmpty ? 'Unknown User' : user.name,
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.primarySoftColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Text(
                        user.role.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Google Account Connected Badge if authenticated with Google
                    if (user.authProvider == 'google' || context.watch<AuthController>().currentUser != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const GoogleLogoIcon(size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Google Connected Account',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Profile Completion Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: complete
                            ? context.successBgColor
                            : context.warningBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: complete
                              ? context.successColor.withValues(alpha: 0.3)
                              : context.warningColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            complete ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                            size: 14,
                            color: complete ? context.successColor : context.warningColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            complete ? 'Profile Complete ✓' : 'Profile Incomplete ⚠️',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: complete ? context.successColor : context.warningColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.space20),
                    // Account info rows
                    _infoRow(context, Icons.alternate_email_rounded, user.email.isEmpty ? 'No email' : user.email),
                    const SizedBox(height: 10),
                    _infoRow(
                      context,
                      Icons.call_rounded,
                      user.phone.isEmpty
                          ? (user.authProvider == 'google' ? 'Google Account (No phone linked)' : 'No phone')
                          : user.phone,
                    ),

                    if (user.beekeeperId != null && user.beekeeperId!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(context, Icons.badge_outlined, 'Beekeeper ID: ${user.beekeeperId!}'),
                    ],
                    if (user.id != null && user.id!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(context, Icons.fingerprint_rounded, 'User ID: ${user.id!}'),
                    ],
                    if (user.organizationName != null && user.organizationName!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(context, Icons.business_rounded, user.organizationName!),
                    ],
                    if (user.facilityLocation != null && user.facilityLocation!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(context, Icons.location_on_outlined, user.facilityLocation!),
                    ],
                    if (user.licenseNumber != null && user.licenseNumber!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(context, Icons.verified_outlined, user.licenseNumber!),
                    ],

                    const SizedBox(height: AppConstants.space20),
                    _PillAction(
                      label: context.tr('edit_profile'),
                      icon: Icons.edit_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Profile completion banner ──
              if (!complete) ...[
                const SizedBox(height: AppConstants.space16),
                Container(
                  padding: const EdgeInsets.all(AppConstants.space20),
                  decoration: BoxDecoration(
                    color: context.warningBgColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.warningColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: context.warningColor, size: 28),
                      const SizedBox(width: AppConstants.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('profile_incomplete_title') != 'profile_incomplete_title'
                                  ? context.tr('profile_incomplete_title')
                                  : 'Please Complete Your Profile First',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: context.warningColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete your profile and required verification details before you can continue with this request.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: context.textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppConstants.space24),

              // ── Settings & activity ──
              Text(
                context.tr('preferences'),
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: AppConstants.space16),
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      context,
                      title: 'Harvester Verification',
                      icon: Icons.verified_user_outlined,
                      trailingBadge: context.watch<VerificationController>().verification.isFullyVerified
                          ? 'Verified ✓'
                          : '${context.watch<VerificationController>().verification.completedStepsCount}/5 Steps',
                      badgeColor: context.watch<VerificationController>().verification.isFullyVerified
                          ? context.successColor
                          : context.textPrimaryColor,
                      badgeBg: context.watch<VerificationController>().verification.isFullyVerified
                          ? context.successBgColor
                          : context.primarySoftColor,
                      onTap: () {
                        if (context.read<VerificationController>().verification.isFullyVerified) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const VerificationCertificateScreen()),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HarvesterVerificationScreen()),
                          );
                        }
                      },
                    ),
                    Divider(height: 1, indent: 56, color: context.borderColor),
                    _buildSettingsTile(
                      context,
                      title: context.tr('language'),
                      icon: Icons.language_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LanguageSettingScreen()),
                        );
                      },
                    ),
                    Divider(height: 1, indent: 56, color: context.borderColor),
                    _buildSettingsTile(
                      context,
                      title: context.tr('appearance'),
                      icon: Icons.palette_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ThemeSettingScreen()),
                        );
                      },
                    ),
                    Divider(height: 1, indent: 56, color: context.borderColor),
                    _buildSettingsTile(
                      context,
                      title: context.tr('change_password'),
                      icon: Icons.lock_outline_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.space32),

              // ── Logout pill ──
              Center(
                child: _PillAction(
                  label: context.tr('logout'),
                  icon: Icons.logout_rounded,
                  destructive: true,
                  onTap: () => _showLogoutDialog(context),
                ),
              ),

              const SizedBox(height: 120), // clear the floating bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.textMutedColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    String? trailingBadge,
    Color? badgeColor,
    Color? badgeBg,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.primarySoftColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.borderColor),
                ),
                child: Icon(icon, size: 20, color: context.textPrimaryColor),
              ),
              const SizedBox(width: AppConstants.space16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
              if (trailingBadge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg ?? context.primarySoftColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trailingBadge,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor ?? context.primaryDarkColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMutedColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled pill button used for primary profile actions.
class _PillAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  const _PillAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? AppConstants.error : context.primaryDarkColor;
    final bg = destructive
        ? AppConstants.error.withValues(alpha: 0.1)
        : context.primarySoftColor;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
