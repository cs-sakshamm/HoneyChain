import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../../features/authentication/auth_controller.dart';
import '../../features/profile/controllers/user_controller.dart';

/// Dynamic HoneyChain Profile Avatar Component
///
/// Priority:
/// 1. Actual Profile Photo (Google Auth / UserProfile photoUrl)
/// 2. First letter of Name (e.g., 'Prabhakar Gupta' -> 'P')
/// 3. First letter of Email (e.g., 'rahul@gmail.com' -> 'R')
/// 4. Generic HoneyChain Hive/Honey Icon
class UserAvatar extends StatelessWidget {
  final double size;
  final String? photoUrl;
  final String? name;
  final String? email;
  final VoidCallback? onTap;
  final bool showBorder;

  const UserAvatar({
    super.key,
    this.size = 38.0,
    this.photoUrl,
    this.name,
    this.email,
    this.onTap,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve details from controllers if not provided
    final authCtrl = context.watch<AuthController>();
    final userCtrl = context.watch<UserController>();

    final effectivePhotoUrl = photoUrl ??
        userCtrl.user.photoUrl ??
        authCtrl.currentUser?.photoURL;

    final effectiveName = name ??
        (userCtrl.user.name.isNotEmpty
            ? userCtrl.user.name
            : (authCtrl.currentUser?.displayName ?? ''));

    final effectiveEmail = email ??
        (userCtrl.user.email.isNotEmpty
            ? userCtrl.user.email
            : (authCtrl.currentUser?.email ?? ''));

    // Determine initial letter
    String? initialLetter;
    if (effectiveName.trim().isNotEmpty) {
      initialLetter = effectiveName.trim()[0].toUpperCase();
    } else if (effectiveEmail.trim().isNotEmpty) {
      initialLetter = effectiveEmail.trim()[0].toUpperCase();
    }

    final avatarWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF27272A) : context.primarySoftColor,
        border: showBorder
            ? Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : context.borderColor,
                width: 1.2,
              )
            : null,
      ),
      child: ClipOval(
        child: _buildAvatarContent(context, effectivePhotoUrl, initialLetter, isDark),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildAvatarContent(
    BuildContext context,
    String? photoUrl,
    String? initial,
    bool isDark,
  ) {
    // 1. Photo URL (Google photo or custom profile photo)
    if (photoUrl != null && photoUrl.trim().isNotEmpty && photoUrl.startsWith('http')) {
      return Image.network(
        photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialOrIcon(context, initial, isDark);
        },
      );
    }

    return _buildInitialOrIcon(context, initial, isDark);
  }

  Widget _buildInitialOrIcon(BuildContext context, String? initial, bool isDark) {
    // 2. Initial (Name or Email)
    if (initial != null && initial.isNotEmpty) {
      return Container(
        color: isDark
            ? AppConstants.honeyAccent.withValues(alpha: 0.20)
            : context.primarySoftColor,
        alignment: Alignment.center,
        child: Text(
          initial,
          style: GoogleFonts.manrope(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w800,
            color: context.textPrimaryColor,
            height: 1.0,
          ),
        ),
      );
    }

    // 3. Generic HoneyChain Icon
    return Container(
      color: context.primarySoftColor,
      alignment: Alignment.center,
      child: Icon(
        Icons.hive_rounded,
        size: size * 0.52,
        color: context.primaryDarkColor,
      ),
    );
  }
}
