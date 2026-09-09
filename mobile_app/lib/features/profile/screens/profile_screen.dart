import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../../authentication/auth_controller.dart';
import '../controllers/user_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'language_setting_screen.dart';
import 'theme_setting_screen.dart';

/// Clean Minimal Harvester Profile Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(
            dialogContext.tr('logout'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Confirm logging out of your account?',
            style: GoogleFonts.inter(fontSize: 14, color: dialogContext.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('cancel'), style: GoogleFonts.inter(color: dialogContext.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<AuthController>().signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.error,
                foregroundColor: Colors.white,
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
    final langCtrl = context.watch<LanguageController>();
    final user = userCtrl.user;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: const GlobalAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Title
            Text(
              context.tr('profile'),
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
                letterSpacing: -0.4,
              ),
            ),

            const SizedBox(height: AppConstants.space16),

            // Account Section (User Info Card & Security Actions)
            Text(
              context.tr('account'),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                children: [
                  // User Info Header
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.space16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: context.primarySoftColor,
                          child: Text(
                            user.initials,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: context.primaryDarkColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              Text(
                                '${context.tr('role_operator')} · ${user.email}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: context.borderColor),
                  // Edit Profile Link
                  ListTile(
                    title: Text(
                      context.tr('edit_profile'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMutedColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: context.borderColor),
                  // Change Password Link
                  ListTile(
                    title: Text(
                      context.tr('change_password'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMutedColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.space20),

            // Preferences Section
            Text(
              context.tr('preferences'),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                children: [
                  // Language
                  ListTile(
                    title: Text(
                      context.tr('language'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          langCtrl.currentLanguage.nativeName,
                          style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMutedColor),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LanguageSettingScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: context.borderColor),
                  // Appearance
                  ListTile(
                    title: Text(
                      context.tr('appearance'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMutedColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ThemeSettingScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: context.borderColor),
                  // Notifications Toggle
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      context.tr('notifications'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    value: _notificationsEnabled,
                    activeColor: AppConstants.primary,
                    onChanged: (val) {
                      setState(() {
                        _notificationsEnabled = val;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.space20),

            // Account Action: Log out
            Container(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                border: Border.all(color: context.borderColor),
              ),
              child: ListTile(
                title: Text(
                  context.tr('logout'),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.error,
                  ),
                ),
                trailing: const Icon(Icons.logout_rounded, size: 18, color: AppConstants.error),
                onTap: () => _showLogoutDialog(context),
              ),
            ),

            const SizedBox(height: AppConstants.space32),
          ],
        ),
      ),
    );
  }
}
