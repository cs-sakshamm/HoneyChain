import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_guard.dart';
import '../../../core/widgets/my_requests_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../../authentication/auth_controller.dart';
import '../../authentication/widgets/google_logo_icon.dart';
import '../../collection/screens/collection_dashboard_screen.dart';
import '../../hives/controllers/hive_controller.dart';
import '../../hives/screens/add_edit_hive_screen.dart';
import '../../hives/screens/start_harvesting_screen.dart';
import '../../lab/screens/lab_dashboard_screen.dart';
import '../../packaging/screens/packaging_dashboard_screen.dart';
import '../../verification/controllers/verification_controller.dart';
import '../../verification/screens/collector_verification_screen.dart';
import '../../verification/screens/harvester_verification_screen.dart';
import '../../verification/screens/lab_verification_screen.dart';
import '../../verification/screens/packaging_verification_screen.dart';
import '../../verification/screens/verification_certificate_screen.dart';
import '../controllers/user_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'language_setting_screen.dart';
import 'theme_setting_screen.dart';

/// Profile page — polished card-based layout with profile details and settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserController>().user;
      final userId = user.id ?? user.email;
      if (userId.isNotEmpty) {
        context.read<VerificationController>().loadVerificationStatus(role: user.role, userId: userId);
      }
    });
  }

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
    final verCtrl = context.watch<VerificationController>();
    final user = userCtrl.user;
    // A user is eligible for role operations if their basic profile is complete
    // OR their role verification is fully complete. These are the two paths to
    // eligibility — checking either prevents the "Verified ✓ but Profile incomplete" paradox.
    final r = user.role.toUpperCase();
    final verificationComplete = r.contains('COLLECT') || r.contains('PROCESS')
        ? verCtrl.collectorVerification.isFullyVerified
        : r.contains('LAB')
            ? verCtrl.labVerification.isFullyVerified
            : r.contains('PKG') || r.contains('PACKAG')
                ? verCtrl.packagingVerification.isFullyVerified
                : verCtrl.verification.isFullyVerified;
    final complete = user.isProfileComplete || user.isVerified || verificationComplete;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppConstants.space16),

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
                    // Role-specific Account info rows
                    _infoRow(context, Icons.alternate_email_rounded, user.email.isEmpty ? 'No email' : user.email),
                    const SizedBox(height: 10),
                    _infoRow(
                      context,
                      Icons.call_rounded,
                      user.phone.isEmpty
                          ? (user.authProvider == 'google' ? 'Google Account (No phone linked)' : 'No phone')
                          : user.phone,
                    ),

                    if (user.role == 'HARVESTER') ...[
                      if (user.beekeeperId != null && user.beekeeperId!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.badge_outlined, 'Beekeeper ID: ${user.beekeeperId!}'),
                      ],
                      if (user.bsid != null && user.bsid!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.fingerprint_rounded, 'BSID: ${user.bsid!}'),
                      ],
                    ] else if (user.role.contains('COLLECT') || user.role.contains('PROCESS')) ...[
                      if (user.organizationName != null && user.organizationName!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.business_rounded, 'Center: ${user.organizationName!}'),
                      ],
                      if (user.facilityLocation != null && user.facilityLocation!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.location_on_outlined, 'Location: ${user.facilityLocation!}'),
                      ],
                      if (user.licenseNumber != null && user.licenseNumber!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.verified_outlined, 'License: ${user.licenseNumber!}'),
                      ],
                    ] else if (user.role.contains('LAB')) ...[
                      if (user.organizationName != null && user.organizationName!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.science_outlined, 'Laboratory: ${user.organizationName!}'),
                      ],
                      if (user.facilityLocation != null && user.facilityLocation!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.location_on_outlined, 'Lab Address: ${user.facilityLocation!}'),
                      ],
                      if (user.licenseNumber != null && user.licenseNumber!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.verified_outlined, 'Accreditation: ${user.licenseNumber!}'),
                      ],
                      if (user.designation != null && user.designation!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.person_outline_rounded, 'Role: ${user.designation!}'),
                      ],
                    ] else if (user.role.contains('PKG') || user.role.contains('PACKAG')) ...[
                      if (user.organizationName != null && user.organizationName!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.inventory_2_outlined, 'Packaging Unit: ${user.organizationName!}'),
                      ],
                      if (user.facilityLocation != null && user.facilityLocation!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.location_on_outlined, 'Facility: ${user.facilityLocation!}'),
                      ],
                      if (user.licenseNumber != null && user.licenseNumber!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(context, Icons.verified_outlined, 'FSSAI License: ${user.licenseNumber!}'),
                      ],
                    ],

                    const SizedBox(height: AppConstants.space20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppConstants.space16,
                      runSpacing: AppConstants.space16,
                      children: [
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
                        const SizedBox(width: AppConstants.space16),
                        // Harvester branch removed: no profile-verification
                        // option for harvesters. Other roles keep theirs.
                        if (!(user.role.toUpperCase() == 'HARVESTER' ||
                            user.role.toUpperCase().trim().isEmpty))
                          _PillAction(
                            label: complete ? 'Verified' : 'Complete Profile',
                            icon: complete ? Icons.verified_rounded : Icons.pending_actions_rounded,
                            color: complete ? context.successBgColor : context.warningBgColor,
                            textColor: complete ? context.successColor : context.warningColor,
                            onTap: () {
                              if (!complete) {
                                if (user.role.toUpperCase().contains('COLLECT') || user.role.toUpperCase().contains('PROCESS')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CollectorVerificationScreen()));
                                } else if (user.role.toUpperCase().contains('LAB')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LabVerificationScreen()));
                                } else if (user.role.toUpperCase().contains('PKG') || user.role.toUpperCase().contains('PACKAG')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PackagingVerificationScreen()));
                                }
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const VerificationCertificateScreen()));
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.space20),

              // ── 3. Role-Specific Verification Checklist Card ──
              // (Harvester Profile Verification section removed by product
              // decision: harvesters no longer have a separate verification
              // flow. Other roles keep their existing verification cards.)
              if (!(user.role.toUpperCase() == 'HARVESTER' ||
                  user.role.toUpperCase().trim().isEmpty))
                _buildRoleVerificationChecklistCard(context, user.role, verCtrl, userCtrl),

              const SizedBox(height: AppConstants.space20),

              // ── 4. Prioritized Role Operations & Workflow Action Buttons ──
              _buildPrioritizedActionsCard(context, user.role),

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
                              'Complete your profile and required verification details before you can continue with role operations.',
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
                    // Role-specific Verification Tile
                    if (user.role.toUpperCase().contains('COLLECT') || user.role.toUpperCase().contains('PROCESS'))
                      _buildSettingsTile(
                        context,
                        title: 'Collector Verification',
                        icon: Icons.verified_user_outlined,
                        trailingBadge: context.watch<VerificationController>().collectorVerification.isFullyVerified
                            ? 'Verified ✓'
                            : '${context.watch<VerificationController>().collectorVerification.completedStepsCount}/2 Steps',
                        badgeColor: context.watch<VerificationController>().collectorVerification.isFullyVerified
                            ? context.successColor
                            : context.textPrimaryColor,
                        badgeBg: context.watch<VerificationController>().collectorVerification.isFullyVerified
                            ? context.successBgColor
                            : context.primarySoftColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CollectorVerificationScreen()),
                          );
                        },
                      )
                    else if (user.role.toUpperCase().contains('LAB'))
                      _buildSettingsTile(
                        context,
                        title: 'Lab Verification',
                        icon: Icons.science_outlined,
                        trailingBadge: context.watch<VerificationController>().labVerification.isFullyVerified
                            ? 'Verified ✓'
                            : '${context.watch<VerificationController>().labVerification.completedStepsCount}/2 Steps',
                        badgeColor: context.watch<VerificationController>().labVerification.isFullyVerified
                            ? context.successColor
                            : context.textPrimaryColor,
                        badgeBg: context.watch<VerificationController>().labVerification.isFullyVerified
                            ? context.successBgColor
                            : context.primarySoftColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LabVerificationScreen()),
                          );
                        },
                      )
                    else if (user.role.toUpperCase().contains('PKG') || user.role.toUpperCase().contains('PACKAG'))
                      _buildSettingsTile(
                        context,
                        title: 'Packaging Verification',
                        icon: Icons.inventory_2_outlined,
                        trailingBadge: context.watch<VerificationController>().packagingVerification.isFullyVerified
                            ? 'Verified ✓'
                            : '${context.watch<VerificationController>().packagingVerification.completedStepsCount}/2 Steps',
                        badgeColor: context.watch<VerificationController>().packagingVerification.isFullyVerified
                            ? context.successColor
                            : context.textPrimaryColor,
                        badgeBg: context.watch<VerificationController>().packagingVerification.isFullyVerified
                            ? context.successBgColor
                            : context.primarySoftColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PackagingVerificationScreen()),
                          );
                        },
                      ),
                    // NOTE: 'Harvester Verification' tile removed by product
                    // decision — harvesters no longer have a separate
                    // profile-verification flow. Other roles keep theirs.
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

  /// Detailed Verification Checklist Card customized per role
  Widget _buildRoleVerificationChecklistCard(
    BuildContext context,
    String role,
    VerificationController verCtrl,
    UserController userCtrl,
  ) {
    final r = role.toUpperCase();
    final user = userCtrl.user;

    String title;
    bool isFullyVerified;
    List<Map<String, dynamic>> items;
    VoidCallback onVerifyTap;

    if (r.contains('COLLECT') || r.contains('PROCESS')) {
      title = 'Collector Profile Verification';
      final collVer = verCtrl.collectorVerification;
      isFullyVerified = collVer.isFullyVerified;
      items = [
        {'title': 'Facility Name & Location', 'done': collVer.isStep2BusinessComplete},
        {'title': 'License / Registration', 'done': collVer.isStep3KycComplete},
        {'title': 'Verified', 'done': isFullyVerified, 'final': true},
      ];
      onVerifyTap = () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CollectorVerificationScreen()),
          );
    } else if (r.contains('LAB')) {
      title = 'Lab Tester Profile Verification';
      final labVer = verCtrl.labVerification;
      isFullyVerified = labVer.isFullyVerified;
      items = [
        {'title': 'Laboratory Name & Address', 'done': labVer.isStep2LabDetailsComplete},
        {'title': 'Accreditation & Scope', 'done': labVer.isStep3KycComplete},
        {'title': 'Verified', 'done': isFullyVerified, 'final': true},
      ];
      onVerifyTap = () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LabVerificationScreen()),
          );
    } else if (r.contains('PKG') || r.contains('PACKAG')) {
      title = 'Packaging Profile Verification';
      final pkgVer = verCtrl.packagingVerification;
      isFullyVerified = pkgVer.isFullyVerified;
      items = [
        {'title': 'Packaging Unit & Address', 'done': pkgVer.isStep2FacilityComplete},
        {'title': 'FSSAI License & Scope', 'done': pkgVer.isStep3KycComplete},
        {'title': 'Verified', 'done': isFullyVerified, 'final': true},
      ];
      onVerifyTap = () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PackagingVerificationScreen()),
          );
    } else {
      title = 'Harvester Profile Verification';
      final harvVer = verCtrl.verification;
      isFullyVerified = harvVer.isFullyVerified;
      items = [
        {'title': 'Full Name', 'done': user.name.trim().isNotEmpty},
        {'title': 'Required Profile Details', 'done': harvVer.isStep2Complete && harvVer.isStep3Complete},
        {'title': 'Verified', 'done': isFullyVerified, 'final': true},
      ];
      onVerifyTap = () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HarvesterVerificationScreen()),
          );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFullyVerified ? context.successColor.withValues(alpha: 0.35) : context.borderColor,
          width: isFullyVerified ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFullyVerified ? context.successBgColor : context.primarySoftColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFullyVerified ? 'Verified ✓' : 'Action Required',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isFullyVerified ? context.successColor : context.primaryDarkColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) {
            final isDone = item['done'] as bool;
            final itemTitle = item['title'] as String;
            final isFinal = item['final'] == true;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(
                    isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: isDone
                        ? context.successColor
                        : (isFinal ? context.textMutedColor : context.warningColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      itemTitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isFinal ? FontWeight.w700 : FontWeight.w500,
                        color: isDone ? context.textPrimaryColor : (isFinal ? context.textMutedColor : context.textPrimaryColor),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDone
                          ? context.successBgColor
                          : (isFinal ? context.surfaceColor : context.warningBgColor),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDone
                            ? context.successColor.withValues(alpha: 0.3)
                            : (isFinal ? context.borderColor : context.warningColor.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Text(
                      isDone ? 'Done ✓' : 'Missing',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDone
                            ? context.successColor
                            : (isFinal ? context.textMutedColor : context.warningColor),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (!isFullyVerified) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onVerifyTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Complete Role Verification',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Prioritized Role Operations Card ordered by exact operational flow
  Widget _buildPrioritizedActionsCard(BuildContext context, String role) {
    final r = role.toUpperCase();

    if (r.contains('COLLECT') || r.contains('PROCESS')) {
      return _buildActionGroup(
        context,
        title: 'Collection & Processing Operations',
        actions: [
          _RoleActionItem(
            title: '1. New Requests',
            subtitle: 'Review & accept incoming harvester drop-offs',
            icon: Icons.inbox_rounded,
            primary: true,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CollectionDashboardScreen()));
            },
          ),
          _RoleActionItem(
            title: '2. Accepted Requests',
            subtitle: 'View accepted batches ready for intake & testing',
            icon: Icons.check_circle_outline_rounded,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CollectionDashboardScreen()));
            },
          ),
          _RoleActionItem(
            title: '3. Find Nearest Quality Lab',
            subtitle: 'Forward processed batch to nearest accredited lab',
            icon: Icons.science_outlined,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CollectionDashboardScreen()));
            },
          ),
          _RoleActionItem(
            title: '4. Completed Batches',
            subtitle: 'Audited log of successfully forwarded batches',
            icon: Icons.done_all_rounded,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CollectionDashboardScreen()));
            },
          ),
        ],
      );
    } else if (r.contains('LAB')) {
      return _buildActionGroup(
        context,
        title: 'Quality Testing Laboratory Operations',
        actions: [
          _RoleActionItem(
            title: '1. Requested Lab Tests',
            subtitle: 'Accept incoming honey samples for quality analysis',
            icon: Icons.science_rounded,
            primary: true,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LabDashboardScreen()));
            },
          ),
          _RoleActionItem(
            title: '2. Accepted Samples',
            subtitle: 'Conduct spectrometry & 6-parameter analysis',
            icon: Icons.biotech_rounded,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LabDashboardScreen()));
            },
          ),
          _RoleActionItem(
            title: '3. Enter Lab Results & Report',
            subtitle: 'Submit moisture, HMF, diastase, and purity scores',
            icon: Icons.post_add_rounded,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LabDashboardScreen()));
            },
          ),
          _RoleActionItem(
            title: '4. Send to Packaging Centre',
            subtitle: 'Forward passed batches to nearest certified packaging unit',
            icon: Icons.local_shipping_outlined,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LabDashboardScreen()));
            },
          ),
        ],
      );
    } else if (r.contains('PKG') || r.contains('PACKAG')) {
      return _buildActionGroup(
        context,
        title: 'Packaging & QR Operations',
        actions: [
          _RoleActionItem(
            title: '1. Requested Batches',
            subtitle: 'Intake tested honey batches from accredited labs',
            icon: Icons.inventory_2_rounded,
            primary: true,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PackagingDashboardScreen()));
            },
          ),
          _RoleActionItem(
            title: '2. Accepted Batches',
            subtitle: 'Queue cleanroom bottling line & jar sterilization',
            icon: Icons.task_alt_rounded,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PackagingDashboardScreen()));
            },
          ),
          _RoleActionItem(
            title: '3. Package Batch & Blockchain Seal',
            subtitle: 'Finalize packaging units and commit to ledger',
            icon: Icons.all_inbox_rounded,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PackagingDashboardScreen()));
            },
          ),
          _RoleActionItem(
            title: '4. View Final QR Traceability',
            subtitle: 'Generate customer-facing verified authenticity QR',
            icon: Icons.qr_code_rounded,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PackagingDashboardScreen()));
            },
          ),
        ],
      );
    } else {
      return _buildActionGroup(
        context,
        title: 'Harvester Operations',
        actions: [
          _RoleActionItem(
            title: '1. Add Hive',
            subtitle: 'Register new colony & automatically match nearest centre',
            icon: Icons.add_circle_outline_rounded,
            primary: true,
            onTap: () {
              // Open to any authenticated harvester — no verification gate.
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditHiveScreen()));
            },
          ),
          _RoleActionItem(
            title: '2. View My Hives',
            subtitle: 'Monitor hive health, flora sources, and production',
            icon: Icons.hive_rounded,
            onTap: () {
              // Hive tab / overview
            },
          ),
          _RoleActionItem(
            title: '3. Start Harvesting',
            subtitle: 'Record raw harvest weight & dispatch to collection hub',
            icon: Icons.agriculture_rounded,
            onTap: () {
              // Open to any authenticated harvester — no verification gate.
              final hives = context.read<HiveController>().hives;
              if (hives.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StartHarvestingScreen(hive: hives.first),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please add a hive before harvesting.')),
                );
              }
            },
          ),
          _RoleActionItem(
            title: '4. My Workflow Requests',
            subtitle: 'Track live 5-stage batch progress & audit timeline',
            icon: Icons.timeline_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    backgroundColor: context.scaffoldBg,
                    appBar: const GlobalAppBar(
                      titleText: 'My Workflow Requests',
                      showBackButton: true,
                    ),
                    body: const MyRequestsView(userRole: 'HARVESTER'),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }
  }

  Widget _buildActionGroup(
    BuildContext context, {
    required String title,
    required List<_RoleActionItem> actions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: AppConstants.space12),
        Container(
          padding: const EdgeInsets.all(AppConstants.space12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            children: actions.map((act) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Material(
                  color: act.primary ? context.primarySoftColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: act.onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: act.primary
                                  ? context.colors.primary.withValues(alpha: 0.15)
                                  : context.primarySoftColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              act.icon,
                              size: 20,
                              color: act.primary ? context.colors.primary : context.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  act.title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  act.subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: context.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMutedColor),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _RoleActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  _RoleActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });
}

/// Filled pill button used for primary profile actions.
class _PillAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  final Color? color;
  final Color? textColor;

  const _PillAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? (destructive ? AppConstants.error : context.primaryDarkColor);
    final bg = color ?? (destructive
        ? AppConstants.error.withValues(alpha: 0.1)
        : context.primarySoftColor);

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
