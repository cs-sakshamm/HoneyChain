import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
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
          title: const Text('Delete this hive?'),
          content: Text(
            'Are you sure you want to delete "${hive.name}" (${hive.hiveCode})? This action cannot be undone.',
            style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
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
                        success ? 'Hive deleted' : 'Failed to delete hive',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context); // Exit details screen after deletion
                }
              },
              child: const Text(
                'Delete Hive',
                style: TextStyle(color: AppConstants.error, fontWeight: FontWeight.w600),
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
        appBar: AppBar(title: const Text('Hive Details')),
        body: const Center(child: Text('Hive not found or deleted.')),
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

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: GlobalAppBar(
        showBackButton: true,
        titleText: hive.name,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppConstants.primaryDark),
            tooltip: 'Edit Hive',
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
            tooltip: 'Delete Hive',
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
            _buildHeaderCard(hive),

            const SizedBox(height: AppConstants.space24),

            // Quick Insights Q&A Section
            _buildSectionTitle('Quick Insights'),
            const SizedBox(height: AppConstants.space8),
            _buildQuickInsightsSection(
              hive: hive,
              formattedLastInspection: formattedLastInspection,
              formattedNextInspection: formattedNextInspection,
              prodPctStr: prodPctStr,
              remProd: remProd,
            ),

            const SizedBox(height: AppConstants.space24),

            // Overview Card
            _buildSectionTitle('Overview'),
            const SizedBox(height: AppConstants.space8),
            _buildInfoCard([
              _buildDetailRow('Colony Strength', hive.colonyStrength),
              _buildDetailRow('Queen Status', hive.queenStatus),
              _buildDetailRow('Hive Type', hive.hiveType),
              _buildDetailRow('Frames (Brood / Total)', hive.occupiedFrameRatio),
              _buildDetailRow('Bee Breed', hive.beeBreed),
              _buildDetailRow('Overall Health', hive.overallHealth, isBadge: true, badgeColor: hive.statusColor),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Production Card
            _buildSectionTitle('Production'),
            const SizedBox(height: AppConstants.space8),
            _buildInfoCard([
              _buildDetailRow('Current Year Production', '${hive.currentYearProductionKg} kg'),
              _buildDetailRow('Previous Year Production', '${hive.previousYearProductionKg} kg'),
              _buildDetailRow('Expected Production', '${hive.expectedProductionKg} kg'),
              _buildDetailRow(
                'Production Trend',
                '$prodSign${prodDiff.toStringAsFixed(1)} kg ($prodPctStr)',
                highlightColor: prodDiff >= 0 ? AppConstants.success : AppConstants.error,
              ),
              _buildDetailRow('Honey Variety / Type', hive.honeyType),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Inspection Card
            _buildSectionTitle('Inspection'),
            const SizedBox(height: AppConstants.space8),
            _buildInfoCard([
              _buildDetailRow('Last Inspection Date', formattedLastInspection),
              _buildDetailRow('Next Inspection Due', formattedNextInspection),
              _buildDetailRow('Disease Status', hive.diseaseStatus),
              _buildDetailRow('Varroa / Mite Status', hive.miteStatus),
              _buildDetailRow(
                'Feeding Required',
                hive.feedingRequired ? 'Yes (Action Required)' : 'No',
                highlightColor: hive.feedingRequired ? AppConstants.warning : AppConstants.textPrimary,
              ),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Queen Card
            _buildSectionTitle('Queen Information'),
            const SizedBox(height: AppConstants.space8),
            _buildInfoCard([
              _buildDetailRow('Queen Status', hive.queenStatus),
              _buildDetailRow('Queen Age', '${hive.queenAgeMonths} months'),
              _buildDetailRow('Queen Condition', hive.queenCondition),
            ]),

            const SizedBox(height: AppConstants.space24),

            // Additional Notes Card
            _buildSectionTitle('Notes & Observations'),
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
                hive.notes.isNotEmpty ? hive.notes : 'No extra notes recorded for this hive.',
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

  Widget _buildHeaderCard(Hive hive) {
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
                  hive.overallHealth,
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
    required Hive hive,
    required String formattedLastInspection,
    required String formattedNextInspection,
    required String prodPctStr,
    required double remProd,
  }) {
    return Column(
      children: [
        QuickInsightCard(
          question: 'How much honey was produced this year?',
          answer: '${hive.currentYearProductionKg} kg',
          subtitle: 'Honey Type: ${hive.honeyType}',
          icon: Icons.scale_outlined,
        ),
        QuickInsightCard(
          question: 'How does this year\'s production compare with last year?',
          answer: prodPctStr,
          subtitle: '${hive.previousYearProductionKg} kg (last year) ➔ ${hive.currentYearProductionKg} kg (this year)',
          icon: Icons.trending_up_rounded,
          answerColor: hive.productionDifference >= 0 ? AppConstants.success : AppConstants.error,
        ),
        QuickInsightCard(
          question: 'Is the hive currently healthy?',
          answer: hive.isHealthy ? 'Yes — Healthy' : 'No — ${hive.overallHealth}',
          subtitle: 'Disease Status: ${hive.diseaseStatus} • Mite Status: ${hive.miteStatus}',
          icon: Icons.health_and_safety_outlined,
          answerColor: hive.isHealthy ? AppConstants.success : AppConstants.error,
        ),
        QuickInsightCard(
          question: 'When was the hive last inspected?',
          answer: formattedLastInspection,
          subtitle: 'Next inspection scheduled: $formattedNextInspection',
          icon: Icons.calendar_today_outlined,
        ),
        QuickInsightCard(
          question: 'Does this hive need feeding?',
          answer: hive.feedingRequired ? 'Yes — Syrup/Pollen Required' : 'No — Sufficient Stores',
          icon: Icons.cookie_outlined,
          answerColor: hive.feedingRequired ? AppConstants.warning : AppConstants.success,
        ),
        QuickInsightCard(
          question: 'What is the colony strength?',
          answer: hive.colonyStrength,
          subtitle: '${hive.broodFrames} brood frames active',
          icon: Icons.groups_outlined,
        ),
        QuickInsightCard(
          question: 'Is the queen healthy?',
          answer: hive.isQueenHealthy ? 'Yes (${hive.queenCondition})' : 'No (${hive.queenCondition})',
          subtitle: 'Status: ${hive.queenStatus} • Age: ${hive.queenAgeMonths} months',
          icon: Icons.workspace_premium_outlined,
          answerColor: hive.isQueenHealthy ? AppConstants.success : AppConstants.warning,
        ),
        QuickInsightCard(
          question: 'How many brood frames are present?',
          answer: '${hive.broodFrames} frames',
          icon: Icons.grid_on_outlined,
        ),
        QuickInsightCard(
          question: 'How many frames are currently occupied?',
          answer: '${hive.occupiedFrameRatio} occupied',
          subtitle: '${hive.occupiedFramePercentage.toStringAsFixed(0)}% frame occupancy rate',
          icon: Icons.view_compact_outlined,
        ),
        QuickInsightCard(
          question: 'What is the expected production this year?',
          answer: '${hive.expectedProductionKg} kg',
          icon: Icons.flag_outlined,
        ),
        QuickInsightCard(
          question: 'How much more production is expected?',
          answer: remProd > 0 ? '${remProd.toStringAsFixed(1)} kg remaining' : '0 kg (Target Achieved)',
          icon: Icons.hourglass_bottom_outlined,
          answerColor: remProd > 0 ? AppConstants.primaryDark : AppConstants.success,
        ),
        QuickInsightCard(
          question: 'When should the next inspection happen?',
          answer: formattedNextInspection,
          icon: Icons.event_available_outlined,
        ),
      ],
    );
  }
}
