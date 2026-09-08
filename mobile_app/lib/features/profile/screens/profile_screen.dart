import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../authentication/auth_controller.dart';
import '../controllers/user_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'language_setting_screen.dart';
import 'theme_setting_screen.dart';

import '../../../core/widgets/global_app_bar.dart';

/// Clean Google Notes-inspired Profile & Settings Screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppConstants.logoutTitle),
          content: const Text(
            AppConstants.logoutSubtitle,
            style: TextStyle(fontSize: 14, color: AppConstants.textSecondary),
          ),
          actions: [
            AppButton(
              text: AppConstants.logoutCancel,
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppButton(
              text: AppConstants.logoutConfirm,
              variant: AppButtonVariant.primary,
              width: 110,
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<AuthController>().signOut();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('About HoneyChain'),
          content: const Text(
            'HoneyChain v1.0.0\n\nSupply chain management & apiary operations tracking simplified for commercial and artisanal turn-key beekeepers.',
            style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
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
      backgroundColor: AppConstants.background,
      appBar: const GlobalAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.space24),
        child: Column(
          children: [
            // User Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.space24),
              decoration: BoxDecoration(
                color: AppConstants.surface,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                border: Border.all(color: AppConstants.border),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppConstants.primarySoft,
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.space12),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.space24),

            // Account Section
            _buildSectionHeader(langCtrl.tr('account')),
            _buildMenuCard([
              _buildMenuItem(
                icon: Icons.person_outline_rounded,
                title: langCtrl.tr('edit_profile'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _buildMenuItem(
                icon: Icons.lock_outline_rounded,
                title: langCtrl.tr('change_password'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Appearance Section
            _buildSectionHeader(langCtrl.tr('appearance')),
            _buildMenuCard([
              _buildMenuItem(
                icon: Icons.palette_outlined,
                title: langCtrl.tr('theme'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ThemeSettingScreen(),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Language Section
            _buildSectionHeader(langCtrl.tr('language')),
            _buildMenuCard([
              _buildMenuItem(
                icon: Icons.language_rounded,
                title: langCtrl.tr('language'),
                trailingText: langCtrl.currentLanguage.name,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LanguageSettingScreen(),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Preferences Section
            _buildSectionHeader(langCtrl.tr('preferences')),
            _buildMenuCard([
              _buildMenuItem(
                icon: Icons.info_outline_rounded,
                title: langCtrl.tr('about'),
                onTap: () => _showAboutDialog(context),
              ),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Security Section
            _buildSectionHeader(langCtrl.tr('security')),
            _buildMenuCard([
              _buildMenuItem(
                icon: Icons.logout_rounded,
                title: langCtrl.tr('logout'),
                textColor: AppConstants.error,
                iconColor: AppConstants.error,
                onTap: () => _showLogoutDialog(context),
              ),
            ]),

            const SizedBox(height: AppConstants.space32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.space8, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppConstants.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppConstants.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? trailingText,
    Color? textColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20, color: iconColor ?? AppConstants.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppConstants.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary),
            ),
            const SizedBox(width: 6),
          ],
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppConstants.textMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}
