import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

enum FeedbackBannerType {
  error,
  info,
  success,
}

/// Production Inline Feedback Banner Component
class FeedbackBanner extends StatelessWidget {
  final String message;
  final FeedbackBannerType type;
  final VoidCallback? onClose;

  const FeedbackBanner({
    super.key,
    required this.message,
    this.type = FeedbackBannerType.error,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color iconColor;
    IconData icon;

    switch (type) {
      case FeedbackBannerType.error:
        iconColor = context.errorColor;
        icon = Icons.error_outline_rounded;
        break;
      case FeedbackBannerType.info:
        iconColor = context.textPrimaryColor;
        icon = Icons.info_outline_rounded;
        break;
      case FeedbackBannerType.success:
        iconColor = context.successColor;
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    bg = iconColor.withValues(alpha: 0.1);
    border = iconColor.withValues(alpha: 0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.space16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: AppConstants.space12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: iconColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close_rounded, color: iconColor, size: 16),
            ),
        ],
      ),
    );
  }
}
