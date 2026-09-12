import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Production Card Container for HoneyChain with Pinterest-inspired subtle depth & clean borders
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final double? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? AppConstants.borderRadiusMedium;
    final effectiveBg = backgroundColor ?? context.surfaceColor;

    final boxDecoration = BoxDecoration(
      color: effectiveBg,
      borderRadius: BorderRadius.circular(effectiveRadius),
      border: border ?? Border.all(color: context.borderColor, width: 1.0),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: const Color(0xFF09090B).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );

    if (onTap != null) {
      return Container(
        decoration: boxDecoration,
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(AppConstants.space16),
              child: child,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(AppConstants.space16),
      decoration: boxDecoration,
      child: child,
    );
  }
}
