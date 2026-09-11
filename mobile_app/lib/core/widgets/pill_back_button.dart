import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular pill-style back button used on all secondary pages.
/// Theme-aware: surface background + outline border in both light and dark.
class PillBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const PillBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: context.textPrimaryColor,
          ),
        ),
      ),
    );
  }
}
