import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import '../widgets/quick_insight_card.dart';
import '../../../core/widgets/global_app_bar.dart';
import 'add_edit_hive_screen.dart';

/// Detailed Hive Information Dashboard Screen
class HiveDetailsScreen extends StatelessWidget {
  final String hiveId;

  const HiveDetailsScreen({
    super.key,
    required this.hiveId,
  });

  void _showDeleteDialog(BuildContext context, Hive hive) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr('delete_confirm_title')),
          content: Text(
            '${dialogContext.tr('delete_confirm_msg')} ("${hive.name}")',
            style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('cancel'), style: const TextStyle(color: AppConstants.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final controller = context.read<HiveController>();
                final success = await controller.deleteHive(hive.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? context.tr('hive_deleted') : context.tr('failed_to_delete_hive'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context); // Exit details screen after deletion
                }
              },
              child: Text(
                dialogContext.tr('delete_hive'),
                style: const TextStyle(color: AppConstants.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HiveController>();
    final hive = controller.getHiveById(hiveId);

    if (hive == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('hive_details'))),
        body: Center(child: Text(context.tr('no_matching_hives'))),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy');
    final formattedLastInspection = dateFormat.format(hive.lastInspectionDate);
    final formattedNextInspection = dateFormat.format(hive.nextInspectionDate);

    // Dynamic calculations
    final prodDiff = hive.productionDifference;
    final prodPct = hive.productionChangePercentage;
    final remProd = hive.remainingExpectedProductionKg;
    final prodSign = prodDiff >= 0 ? '+' : '';
    final prodPctStr = '$prodSign${prodPct.toStringAsFixed(1)}%';

    String translatedHealth = hive.overallHealth;
    if (hive.overallHealth.toLowerCase() == 'healthy') {
      translatedHealth = context.tr('healthy');
    } else if (hive.overallHealth.toLowerCase() == 'needs attention') {
      translatedHealth = context.tr('needs_attention');
    } else if (hive.overallHealth.toLowerCase() == 'critical') {
      translatedHealth = context.tr('critical');
    }

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: GlobalAppBar(
        showBackButton: true,
        titleText: hive.name,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppConstants.primaryDark),
            tooltip: context.tr('edit_hive'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditHiveScreen(hive: hive),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppConstants.error),
            tooltip: context.tr('delete_hive'),
            onPressed: () => _showDeleteDialog(context, hive),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            _buildHeaderCard(context, hive, translatedHealth),

            const SizedBox(height: AppConstants.space24),

            // Quick Insights Q&A Section
            _buildSectionTitle(context.tr('quick_insights')),
            const SizedBox(height: AppConstants.space8),
            _buildQuickInsightsSection(
              context: context,
              hive: hive,
              formattedLastInspection: formattedLastInspection,
              formattedNextInspection: formattedNextInspection,
              prodPctStr: prodPctStr,
              remProd: remProd,
            ),

            const SizedBox(height: AppConstants.space24),

            // Overview Card
            _buildSectionTitle(context.tr('overview')),
            const SizedBox(height: AppConstants.space8),
            _buildInfoCard([
              _buildDetailRow(context.tr('colony_strength'), hive.colonyStrength),
              _buildDetailRow(context.tr('queen_status'), hive.queenStatus),
              _buildDetailRow(context.tr('hive_type'), hive.hiveType),
              _buildDetailRow('${context.tr('brood_frames')} / ${context.tr('total_frames')}', hive.occupiedFrameRatio),
              _buildDetailRow(context.tr('bee_breed'), hive.beeBreed),
              _buildDetailRow(context.tr('overall_health'), translatedHealth, isBadge: true, badgeColor: hive.statusColor),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Production Card
            _buildSectionTitle(context.tr('production')),
            const SizedBox(height: AppConstants.space8),
            _buildInfoCard([
              _buildDetailRow(context.tr('current_production'), '${hive.currentYearProductionKg} kg'),
              _buildDetailRow(context.tr('previous_production'), '${hive.previousYearProductionKg} kg'),
              _buildDetailRow(context.tr('expected_production'), '${hive.expectedProductionKg} kg'),
              _buildDetailRow(
                context.tr('production_trend'),
                '$prodSign${prodDiff.toStringAsFixed(1)} kg ($prodPctStr)',
                highlightColor: prodDiff >= 0 ? AppConstants.success : AppConstants.error,
              ),
              _buildDetailRow(context.tr('honey_variety'), hive.honeyType),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Inspection Card
            _buildSectionTitle(context.tr('inspection')),
            const SizedBox(height: AppConstants.space8),
            _buildInfoCard([
              _buildDetailRow(context.tr('last_inspected'), formattedLastInspection),
              _buildDetailRow(context.tr('next_inspection'), formattedNextInspection),
              _buildDetailRow(context.tr('disease_status'), hive.diseaseStatus),
              _buildDetailRow(context.tr('mite_status'), hive.miteStatus),
              _buildDetailRow(
                context.tr('feeding_required'),
                hive.feedingRequired ? context.tr('yes_action_req') : context.tr('no'),
                highlightColor: hive.feedingRequired ? AppConstants.warning : AppConstants.textPrimary,
              ),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Queen Card
            _buildSectionTitle(context.tr('queen')),
            const SizedBox(height: AppConstants.space8),
            _buildInfoCard([
              _buildDetailRow(context.tr('queen_status'), hive.queenStatus),
              _buildDetailRow(context.tr('queen_age'), '${hive.queenAgeMonths} months'),
              _buildDetailRow(context.tr('queen_condition'), hive.queenCondition),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Additional Notes Card
            _buildSectionTitle(context.tr('notes')),
            const SizedBox(height: AppConstants.space8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.space16),
              decoration: BoxDecoration(
                color: AppConstants.surface,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                border: Border.all(color: AppConstants.border),
              ),
              child: Text(
                hive.notes.isNotEmpty ? hive.notes : context.tr('no_notes'),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppConstants.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: AppConstants.space32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Hive hive, String translatedHealth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppConstants.primarySoft,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                ),
                child: const Icon(
                  Icons.hive_rounded,
                  color: AppConstants.primaryDark,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppConstants.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hive.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${hive.hiveCode} • ${hive.apiaryLocation}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppConstants.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: hive.isHealthy
                      ? AppConstants.successBackground
                      : AppConstants.errorBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hive.isHealthy
                        ? AppConstants.success.withValues(alpha: 0.3)
                        : AppConstants.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  translatedHealth,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: hive.isHealthy ? AppConstants.success : AppConstants.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppConstants.textPrimary,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppConstants.border),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBadge = false,
    Color? badgeColor,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppConstants.textSecondary,
            ),
          ),
          if (isBadge && badgeColor != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: highlightColor ?? AppConstants.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickInsightsSection({
    required BuildContext context,
    required Hive hive,
    required String formattedLastInspection,
    required String formattedNextInspection,
    required String prodPctStr,
    required double remProd,
  }) {
    return Column(
      children: [
        QuickInsightCard(
          question: context.tr('qi_q1'),
          answer: '${hive.currentYearProductionKg} kg',
          subtitle: '${context.tr('honey_type')}: ${hive.honeyType}',
          icon: Icons.scale_outlined,
        ),
        QuickInsightCard(
          question: context.tr('qi_q2'),
          answer: prodPctStr,
          subtitle: '${hive.previousYearProductionKg} kg (${context.tr('previous_year')}) ➔ ${hive.currentYearProductionKg} kg (${context.tr('current_year')})',
          icon: Icons.trending_up_rounded,
          answerColor: hive.productionDifference >= 0 ? AppConstants.success : AppConstants.error,
        ),
        QuickInsightCard(
          question: context.tr('qi_q3'),
          answer: hive.isHealthy ? '${context.tr('yes')} — ${context.tr('healthy')}' : '${context.tr('no')} — ${hive.overallHealth}',
          subtitle: '${context.tr('disease_status')}: ${hive.diseaseStatus} • ${context.tr('mite_status')}: ${hive.miteStatus}',
          icon: Icons.health_and_safety_outlined,
          answerColor: hive.isHealthy ? AppConstants.success : AppConstants.error,
        ),
        QuickInsightCard(
          question: context.tr('qi_q4'),
          answer: formattedLastInspection,
          subtitle: '${context.tr('next_inspection')}: $formattedNextInspection',
          icon: Icons.calendar_today_outlined,
        ),
        QuickInsightCard(
          question: context.tr('qi_q5'),
          answer: hive.feedingRequired ? context.tr('yes_action_req') : context.tr('no'),
          icon: Icons.cookie_outlined,
          answerColor: hive.feedingRequired ? AppConstants.warning : AppConstants.success,
        ),
        QuickInsightCard(
          question: context.tr('qi_q6'),
          answer: hive.colonyStrength,
          subtitle: '${hive.broodFrames} ${context.tr('brood_frames')}',
          icon: Icons.groups_outlined,
        ),
        QuickInsightCard(
          question: context.tr('qi_q7'),
          answer: hive.isQueenHealthy ? '${context.tr('yes')} (${hive.queenCondition})' : '${context.tr('no')} (${hive.queenCondition})',
          subtitle: '${context.tr('queen_status')}: ${hive.queenStatus} • ${context.tr('queen_age')}: ${hive.queenAgeMonths} months',
          icon: Icons.workspace_premium_outlined,
          answerColor: hive.isQueenHealthy ? AppConstants.success : AppConstants.warning,
        ),
        QuickInsightCard(
          question: context.tr('qi_q8'),
          answer: '${hive.broodFrames} ${context.tr('brood_frames')}',
          icon: Icons.grid_on_outlined,
        ),
        QuickInsightCard(
          question: context.tr('qi_q9'),
          answer: '${hive.occupiedFrameRatio}',
          subtitle: '${hive.occupiedFramePercentage.toStringAsFixed(0)}% occupancy',
          icon: Icons.view_compact_outlined,
        ),
        QuickInsightCard(
          question: context.tr('qi_q10'),
          answer: '${hive.expectedProductionKg} kg',
          icon: Icons.flag_outlined,
        ),
        QuickInsightCard(
          question: context.tr('qi_q11'),
          answer: remProd > 0 ? '${remProd.toStringAsFixed(1)} kg' : '0 kg',
          icon: Icons.hourglass_bottom_outlined,
          answerColor: remProd > 0 ? AppConstants.primaryDark : AppConstants.success,
        ),
        QuickInsightCard(
          question: context.tr('qi_q12'),
          answer: formattedNextInspection,
          icon: Icons.event_available_outlined,
        ),
      ],
    );
  }
}

