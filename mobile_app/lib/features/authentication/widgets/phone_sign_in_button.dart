import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Clean Google Keep inspired Phone Sign-In button widget with phone icon
class PhoneSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const PhoneSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Brand-accurate white in light mode; theme surface in dark mode.
    final bgColor = isDark ? theme.colorScheme.surface : Colors.white;
    final textColor = isDark ? theme.colorScheme.onSurface : const Color(0xFF202124);
    final iconColor = isDark ? theme.colorScheme.onSurface : const Color(0xFF3C4043);
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
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppConstants.honeyAccent),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.smartphone_outlined,
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppConstants.phoneSignInText,
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
