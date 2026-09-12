import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import 'pill_back_button.dart';
import '../../features/hives/screens/add_edit_hive_screen.dart';
import '../../features/profile/screens/notifications_screen.dart';

/// Pinterest-Inspired Top Navigation Bar
/// - Left: Text Logo with modern bold typography
/// - Right: Add Icon (+) and Inbox Icon (Chat bubble with red notification dot)
/// - Layout: Sticky, full-width, frosted blur background with subtle bottom border
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final String? titleText;
  final String? logoText;
  final VoidCallback? onAddPressed;
  final VoidCallback? onInboxPressed;
  final bool hasUnreadInbox;
  final List<Widget>? extraActions;

  const GlobalAppBar({
    super.key,
    this.showBackButton = false,
    this.titleText,
    this.logoText,
    this.onAddPressed,
    this.onInboxPressed,
    this.hasUnreadInbox = true,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final isSubPage = (showBackButton || canPop) && titleText != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final headerBg = isDark
        ? const Color(0xFF121212).withValues(alpha: 0.85)
        : context.surfaceColor.withValues(alpha: 0.92);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16.0,
            right: 16.0,
          ),
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : context.borderColor.withValues(alpha: 0.7),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Section: Subpage title OR Text Logo
              isSubPage
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PillBackButton(),
                        const SizedBox(width: 12),
                        Text(
                          titleText!,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimaryColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          logoText ?? AppConstants.appName,
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: context.textPrimaryColor,
                            letterSpacing: -0.6,
                          ),
                        ),
                        if (titleText != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• $titleText',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),

              // Right Section: Add (+) and Inbox (Chat bubble) Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (extraActions != null) ...extraActions!,

                  // 1. Add / Create (+) Button
                  _NavIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Create / Add',
                    onTap: onAddPressed ??
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddEditHiveScreen(),
                            ),
                          );
                        },
                  ),

                  const SizedBox(width: 8),

                  // 2. Inbox / Messages Button with Red Notification Dot
                  _NavIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Inbox and Notifications',
                    hasBadge: hasUnreadInbox,
                    badgeColor: const Color(0xFFEF4444),
                    onTap: onInboxPressed ??
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool hasBadge;
  final Color badgeColor;

  const _NavIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hasBadge = false,
    this.badgeColor = const Color(0xFFEF4444),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF09090B).withValues(alpha: 0.05);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: btnBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : context.borderColor.withValues(alpha: 0.6),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: context.textPrimaryColor,
                ),
                if (hasBadge)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF121212) : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
