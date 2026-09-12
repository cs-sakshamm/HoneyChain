import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';
import 'pill_back_button.dart';
import '../../features/profile/screens/notifications_screen.dart';

/// Clean, Reusable Top Navigation / Header for HoneyChain Mobile
/// - Left: HoneyChain geometric logo + "HoneyChain" text (or Back button + Title on subpages)
/// - Right: ONLY the Notification / Bell icon with unread indicator badge
/// - Theme-aware: Automatically adapts to Light & Dark themes
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final String? titleText;
  final VoidCallback? onNotificationTap;
  final bool hasUnreadNotifications;
  final List<Widget>? extraActions;

  const GlobalAppBar({
    super.key,
    this.showBackButton = false,
    this.titleText,
    this.onNotificationTap,
    this.hasUnreadNotifications = true,
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

              // Right Section: ONLY Notification / Bell Icon
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (extraActions != null) ...extraActions!,
                  _NotificationBellButton(
                    hasUnread: hasUnreadNotifications,
                    onTap: onNotificationTap ??
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

class _NotificationBellButton extends StatelessWidget {
  final bool hasUnread;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.hasUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF09090B).withValues(alpha: 0.05);

    return Tooltip(
      message: 'Notifications',
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
                  Icons.notifications_outlined,
                  size: 21,
                  color: context.textPrimaryColor,
                ),
                if (hasUnread)
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
