import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import 'google_logo_icon.dart';

/// Clean Google Keep inspired Google Sign-In button widget
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? theme.colorScheme.surface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF3C4043);
    final borderColor = isDark ? theme.colorScheme.outline : const Color(0xFFDADCE0);

    return Container(
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 48),
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Google rounded pill shape
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? Colors.white : AppConstants.primary,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogoIcon(size: 20),
                  const SizedBox(width: 12),
                  Text(
                    AppConstants.googleSignInText,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
