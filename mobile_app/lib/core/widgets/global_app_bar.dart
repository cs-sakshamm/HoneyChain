import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../localization/localization_service.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// Reusable Global Top App Bar for authenticated screens
/// Renders: [ (←) Logo App Name                        🔔 ]
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final String? titleText;
  final List<Widget>? extraActions;
  final bool hasUnreadNotifications;

  const GlobalAppBar({
    super.key,
    this.showBackButton = false,
    this.titleText,
    this.extraActions,
    this.hasUnreadNotifications = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  /// Helper modal sheet to display notifications
  static void showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppConstants.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    modalContext.tr('notifications'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.primarySoftColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '1 New',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.primaryDarkColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.precision_manufacturing_rounded, size: 18, color: AppConstants.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maintenance due',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        Text(
                          'Service recommended soon.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.textMutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

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
                style: GoogleFonts.inter(
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
        // Notification Bell Icon with Unread Badge Indicator
        InkWell(
          onTap: () => showNotificationsSheet(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 24,
                  color: context.textPrimaryColor,
                ),
                if (hasUnreadNotifications)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppConstants.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.surfaceColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppConstants.space16),
      ],
    );
  }
}
