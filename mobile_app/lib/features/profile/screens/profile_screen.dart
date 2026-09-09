import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../../authentication/auth_controller.dart';
import '../controllers/user_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'language_setting_screen.dart';
import 'theme_setting_screen.dart';

/// Clean Google Notes-inspired Profile & Settings Screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr('logout_title')),
          content: Text(
            dialogContext.tr('logout_subtitle'),
            style: TextStyle(fontSize: 14, color: dialogContext.textSecondaryColor),
          ),
          actions: [
            AppButton(
              text: dialogContext.tr('logout_cancel'),
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppButton(
              text: dialogContext.tr('logout_confirm'),
              variant: AppButtonVariant.primary,
              width: 130,
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
          title: Text(dialogContext.tr('about')),
          content: Text(
            'HoneyChain v1.0.0\n\n${dialogContext.tr('manage_business_sub')}',
            style: TextStyle(fontSize: 14, color: dialogContext.textSecondaryColor, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('close')),
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
        padding: const EdgeInsets.all(AppConstants.space24),
        child: Column(
          children: [
            // User Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.space24),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: context.primarySoftColor,
                    child: Text(
                      user.initials,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: context.primaryDarkColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.space12),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.space24),

            // Account Section
            _buildSectionHeader(context, context.tr('account')),
            _buildMenuCard(context, [
              _buildMenuItem(
                context,
                icon: Icons.person_outline_rounded,
                title: context.tr('edit_profile'),
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
              _buildMenuItem(
                context,
                icon: Icons.lock_outline_rounded,
                title: context.tr('change_password'),
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
            _buildSectionHeader(context, context.tr('appearance')),
            _buildMenuCard(context, [
              _buildMenuItem(
                context,
                icon: Icons.palette_outlined,
                title: context.tr('theme'),
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
            _buildSectionHeader(context, context.tr('language')),
            _buildMenuCard(context, [
              _buildMenuItem(
                context,
                icon: Icons.language_rounded,
                title: context.tr('language'),
                trailingText: '${langCtrl.currentLanguage.name} (${langCtrl.currentLanguage.nativeName})',
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
            _buildSectionHeader(context, context.tr('preferences')),
            _buildMenuCard(context, [
              _buildMenuItem(
                context,
                icon: Icons.info_outline_rounded,
                title: context.tr('about'),
                onTap: () => _showAboutDialog(context),
              ),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Security Section
            _buildSectionHeader(context, context.tr('security')),
            _buildMenuCard(context, [
              _buildMenuItem(
                context,
                icon: Icons.logout_rounded,
                title: context.tr('logout'),
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.space8, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.textSecondaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailingText,
    Color? textColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20, color: iconColor ?? context.textSecondaryColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor ?? context.textPrimaryColor,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
            ),
            const SizedBox(width: 6),
          ],
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMutedColor),
        ],
      ),
      onTap: onTap,
    );
  }
}

