import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';
import 'pill_back_button.dart';
import '../../features/hives/screens/add_edit_hive_screen.dart';
import '../../features/profile/screens/notifications_screen.dart';

/// Clean, Pinterest-Inspired Top Navigation / Header for HoneyChain Mobile
/// - Left: HoneyChain geometric logo + "HoneyChain" text (or Back button + Title on subpages)
/// - Right: Clickable Plus (+) Action Button + Inbox/Message Action Button (with unread badge)
/// - Theme-aware: Seamlessly adapts to Light & Dark themes with subtle frosted blur
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final String? titleText;
  final VoidCallback? onAddTap;
  final VoidCallback? onInboxTap;
  final VoidCallback? onNotificationTap;
  final bool hasUnreadNotifications;
  final bool showActions;
  final List<Widget>? extraActions;

  const GlobalAppBar({
    super.key,
    this.showBackButton = false,
    this.titleText,
    this.onAddTap,
    this.onInboxTap,
    this.onNotificationTap,
    this.hasUnreadNotifications = true,
    this.showActions = true,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final isSubPage = (showBackButton || canPop) && titleText != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final headerBg = isDark
        ? const Color(0xFF09090B).withValues(alpha: 0.90)
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
              // Left Section: Logo + Name OR Back Button + Title
              Expanded(
                child: isSubPage
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PillBackButton(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              titleText!,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimaryColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
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
                                  fontWeight: FontWeight.w500,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),

              // Right Section: Plus (+) Button + Inbox / Message Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (extraActions != null) ...extraActions!,
                  if (showActions) ...[
                    // 1. Plus (+) Action Button -> opens Add/Create Page
                    _TopNavActionButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Create / Add',
                      onTap: onAddTap ??
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
                    // 2. Inbox / Message Action Button -> opens Inbox / Messages Page
                    _TopNavActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      tooltip: 'Inbox / Messages',
                      hasBadge: hasUnreadNotifications,
                      onTap: onInboxTap ??
                          onNotificationTap ??
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accessible, Pinterest-inspired circular action button with theme-aware styling
class _TopNavActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool hasBadge;

  const _TopNavActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hasBadge = false,
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
          borderRadius: BorderRadius.circular(21),
          child: Container(
            width: 42,
            height: 42,
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
                        color: AppConstants.honeyAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF09090B) : Colors.white,
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
