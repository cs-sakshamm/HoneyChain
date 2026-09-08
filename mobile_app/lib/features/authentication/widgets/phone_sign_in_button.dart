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

    return Container(
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 48),
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF202124),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: Color(0xFFDADCE0), width: 1),
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppConstants.honeyAccent),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.smartphone_outlined,
                    size: 20,
                    color: Color(0xFF3C4043),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppConstants.phoneSignInText,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF202124),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
