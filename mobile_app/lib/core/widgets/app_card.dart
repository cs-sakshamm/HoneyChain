import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Production Card Container for HoneyChain
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding ?? const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: border ?? Border.all(color: context.borderColor, width: 1.0),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: backgroundColor ?? context.surfaceColor,
        shape: RoundedRectangleBorder(
          side: border?.top ?? BorderSide(color: context.borderColor, width: 1.0),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppConstants.space16),
            child: child,
          ),
        ),
      );
    }

    return cardContent;
  }
}
