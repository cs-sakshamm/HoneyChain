import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/hive_model.dart';

/// Clean Google Notes / Google Keep-inspired Hive Card
class HiveNoteCard extends StatelessWidget {
  final Hive hive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HiveNoteCard({
    super.key,
    required this.hive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final formattedDate = dateFormat.format(hive.lastInspectionDate);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.space12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(
          color: context.borderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.textPrimaryColor.withValues(alpha: 0.04),
            blurRadius: 4,
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
            padding: const EdgeInsets.all(AppConstants.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title, Code/Apiary, & Overflow Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hive Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.primarySoftColor,
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                      ),
                      child: Icon(
                        Icons.hive_outlined,
                        color: context.primaryDarkColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    // Hive Name and Code • Apiary
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hive.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${hive.hiveCode} • ${hive.apiaryLocation}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.textSecondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Health Badge
                    _buildHealthBadge(context, hive),
                    const SizedBox(width: AppConstants.space4),
                    // Options Popup Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: context.textMutedColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 120),
                      onSelected: (value) {
                        if (value == 'view') {
                          onTap();
                        } else if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (popupContext) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18, color: popupContext.textPrimaryColor),
                              const SizedBox(width: 8),
                              Text(context.tr('view_details'), style: TextStyle(fontSize: 13, color: popupContext.textPrimaryColor)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: popupContext.textPrimaryColor),
                              const SizedBox(width: 8),
                              Text(context.tr('edit'), style: TextStyle(fontSize: 13, color: popupContext.textPrimaryColor)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded, size: 18, color: AppConstants.error),
                              const SizedBox(width: 8),
                              Text(context.tr('delete'), style: const TextStyle(fontSize: 13, color: AppConstants.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space12),
                const Divider(height: 1),
                const SizedBox(height: AppConstants.space12),
                // Bottom Row: Production & Last Inspected Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Production Metric
                    Row(
                      children: [
                        Icon(
                          Icons.scale_outlined,
                          size: 15,
                          color: context.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${context.tr('production')}: ${hive.currentYearProductionKg.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    // Last Inspected Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: context.textMutedColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${context.tr('last_inspected')}: $formattedDate',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthBadge(BuildContext context, Hive hive) {
    final isHealthy = hive.isHealthy;
    final bgColor = isHealthy ? context.successBgColor : context.errorBgColor;
    final fgColor = isHealthy ? context.successColor : context.errorColor;

    String translatedHealth = hive.overallHealth;
    if (hive.overallHealth.toLowerCase() == 'healthy') {
      translatedHealth = context.tr('healthy');
    } else if (hive.overallHealth.toLowerCase() == 'needs attention') {
      translatedHealth = context.tr('needs_attention');
    } else if (hive.overallHealth.toLowerCase() == 'critical') {
      translatedHealth = context.tr('critical');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fgColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        translatedHealth,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fgColor,
        ),
      ),
    );
  }
}

