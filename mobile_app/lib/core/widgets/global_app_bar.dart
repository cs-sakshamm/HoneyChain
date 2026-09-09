import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../localization/localization_service.dart';
import '../theme/app_theme.dart';
import '../../features/profile/screens/language_setting_screen.dart';
import 'app_logo.dart';

/// Reusable Global App Bar for authenticated screens
/// Renders: [ (←) Logo App Name                        EN ▾ ]
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final String? titleText;
  final List<Widget>? extraActions;

  const GlobalAppBar({
    super.key,
    this.showBackButton = false,
    this.titleText,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.surfaceColor,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: context.textPrimaryColor),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      titleSpacing: showBackButton ? 0 : AppConstants.space24,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(
            size: 26,
            showWordmark: true,
          ),
          if (titleText != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '• $titleText',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (extraActions != null) ...extraActions!,
        // Global Flag-Free Language Selector Chip
        Consumer<LanguageController>(
          builder: (context, langCtrl, _) {
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LanguageSettingScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.primarySoftColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      langCtrl.currentLanguageCode.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.primaryDarkColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down_rounded, size: 18, color: context.primaryDarkColor),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: AppConstants.space16),
      ],
    );
  }
}
