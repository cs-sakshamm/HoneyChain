import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

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
        bg = AppConstants.errorBackground;
        border = const Color(0xFF374151); // Gray-700
        iconColor = AppConstants.error;
        icon = Icons.error_outline_rounded;
        break;
      case FeedbackBannerType.info:
        bg = AppConstants.primarySoft;
        border = const Color(0xFFD1D5DB); // Gray-300
        iconColor = AppConstants.primaryDark;
        icon = Icons.info_outline_rounded;
        break;
      case FeedbackBannerType.success:
        bg = AppConstants.successBackground;
        border = const Color(0xFFD1D5DB); // Gray-300
        iconColor = AppConstants.success;
        icon = Icons.check_circle_outline_rounded;
        break;
    }

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
