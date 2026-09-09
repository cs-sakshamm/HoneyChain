import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Production Square Icon Button for Social / Provider Auth
class SocialIconButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;

  const SocialIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
    this.size = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              border: Border.all(color: context.borderColor, width: 1.0),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primary),
                    ),
                  )
                : icon,
          ),
        ),
      ),
    );
  }
}
