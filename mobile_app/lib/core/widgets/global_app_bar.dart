import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../controllers/workflow_controller.dart';
import '../theme/app_theme.dart';
import '../../features/profile/controllers/user_controller.dart';
import '../../features/profile/screens/notifications_screen.dart';
import 'app_logo.dart';
import 'pill_back_button.dart';

/// Clean, Pinterest-Inspired Top Navigation / Header for HoneyChain Mobile
/// - Left: HoneyChain geometric logo + "HoneyChain" text (GoogleFonts.shareTech)
/// - Right: Inbox/Message Action Button (active only with real unread messages)
/// - Theme-aware: Seamlessly adapts to Light & Dark themes with subtle frosted blur
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final String? titleText;
  final VoidCallback? onAddTap;
  final VoidCallback? onInboxTap;
  final VoidCallback? onNotificationTap;
  final bool? hasUnreadNotifications;
  final bool showActions;
  final List<Widget>? extraActions;

  const GlobalAppBar({
    super.key,
    this.showBackButton = false,
    this.titleText,
    this.onAddTap,
    this.onInboxTap,
    this.onNotificationTap,
    this.hasUnreadNotifications,
    this.showActions = true,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
final canPop = ModalRoute.of(context)?.canPop ?? false;
    final shouldShowBack = showBackButton || canPop;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Real dynamic unread message / notification state
    bool unreadState = false;
    if (hasUnreadNotifications != null) {
      unreadState = hasUnreadNotifications!;
    } else {
      try {
        final workflow = context.watch<WorkflowController>();
        final user = context.watch<UserController>().user;
        final incoming = workflow.incomingRequests(user.role);
        unreadState = incoming.isNotEmpty;
      } catch (_) {
        unreadState = false;
      }
    }

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
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
// Left Section: Logo + Name OR Back Button + Title
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (shouldShowBack) ...[
                      const PillBackButton(),
                      const SizedBox(width: 12),
                    ],
                    if (titleText != null)
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
                      )
                    else if (!shouldShowBack)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppLogo(
                            size: 26,
                            showWordmark: true,
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Right Section: Inbox / Message Button (ONLY, "+" icon removed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (extraActions != null) ...extraActions!,
                  if (showActions)
                    _TopNavActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      tooltip: 'Inbox / Messages',
                      hasBadge: unreadState,
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
    final btnBg = hasBadge
        ? (isDark
            ? AppConstants.honeyAccent.withValues(alpha: 0.20)
            : context.primarySoftColor)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFF09090B).withValues(alpha: 0.05));

    final iconColor = hasBadge
        ? (isDark ? AppConstants.honeyAccent : context.primaryDarkColor)
        : context.textPrimaryColor;

    final borderColor = hasBadge
        ? (isDark
            ? AppConstants.honeyAccent.withValues(alpha: 0.40)
            : context.primaryColor.withValues(alpha: 0.35))
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : context.borderColor.withValues(alpha: 0.6));

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
                color: borderColor,
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
                  color: iconColor,
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
