import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';

/// Prominent, minimal Google Keep-inspired "Add Hive" card
class AddHiveCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddHiveCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(
          color: AppConstants.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.textPrimaryColor.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space24,
              vertical: AppConstants.space24,
            ),
            child: Row(
              children: [
                // Prominent + Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.primarySoftColor,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                    border: Border.all(
                      color: AppConstants.primary.withValues(alpha: 0.2),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: context.primaryDarkColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppConstants.space16),
                // Text Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('add_hive'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr('create_manage_hive'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: context.textMutedColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

