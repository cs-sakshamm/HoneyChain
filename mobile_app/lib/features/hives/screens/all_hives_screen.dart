import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import '../widgets/failed_hive_card.dart';
import 'add_edit_hive_screen.dart';
import 'hive_details_screen.dart';

/// Hives list screen — in-body header (no top navbar) with pill Add Hive.
class AllHivesScreen extends StatelessWidget {
  const AllHivesScreen({super.key});

  void _openAddHive(BuildContext context) {
    // Open to any authenticated harvester — no profile-verification gate.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditHiveScreen()),
    );
  }

  /// Real backend status of the collection request attached to a hive.
  String _requestStatusLabel(BuildContext context, String? hiveId) {
    if (hiveId == null || hiveId.isEmpty) return 'Request Not Sent';
    final workflowCtrl = context.read<WorkflowController>();
    final requests = workflowCtrl.harvesterRequests
        .where((r) => r.hiveId == hiveId)
        .toList();
    if (requests.isEmpty) return 'Request Not Sent';
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests.first.status.label;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HiveController>();
    final hives = controller.hives;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // In-body header: title + pill Add Hive action
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('hives'),
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Material(
                    color: context.primarySoftColor,
                    borderRadius: BorderRadius.circular(30),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openAddHive(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: context.primaryDarkColor),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('add_hive'),
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.primaryDarkColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('your_active_fields'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),

              const SizedBox(height: AppConstants.space20),

              Expanded(
                child: (hives.isEmpty && controller.failedSubmissions.isEmpty)
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: controller.failedSubmissions.length + hives.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index < controller.failedSubmissions.length) {
                            final failed =
                                controller.failedSubmissions.values.elementAt(index);
                            return FailedHiveCard(
                              failed: failed,
                              onRetry: () =>
                                  controller.retryFailedSubmission(failed.localKey),
                              onDismiss: () =>
                                  controller.dismissFailedSubmission(failed.localKey),
                            );
                          }
                          final hive = hives[index - controller.failedSubmissions.length];
                          return _buildFieldCard(context, hive, _requestStatusLabel(context, hive.id));
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard(BuildContext context, Hive hive, String requestStatusLabel) {
    final healthy = hive.isHealthy;
    final statusColor = _requestStatusColor(context, requestStatusLabel);

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HiveDetailsScreen(hiveId: hive.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppConstants.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      hive.name,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Real workflow status for this hive from the backend.
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          requestStatusLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: healthy ? context.successBgColor : context.warningBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          hive.overallHealth,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: healthy ? context.successColor : context.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${hive.hiveCode} · ${hive.apiaryLocation} · ${hive.hiveType}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${hive.currentYearProductionKg.toStringAsFixed(1)} kg this year',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  Text(
                    'Target ${hive.expectedProductionKg.toStringAsFixed(0)} kg',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: context.textMutedColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: hive.expectedProductionKg > 0
                      ? (hive.currentYearProductionKg / hive.expectedProductionKg).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 5,
                  backgroundColor: context.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _requestStatusColor(BuildContext context, String label) {
    switch (label) {
      case 'Request Not Sent':
        return context.textMutedColor;
      case 'Pending':
        return context.warningColor;
      case 'Accepted':
      case 'Processing':
      case 'Lab Verified':
      case 'Completed':
        return context.successColor;
      case 'Denied':
      case 'Lab Rejected':
        return context.errorColor;
      default:
        return context.colors.primary;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hive_outlined, size: 56, color: context.textMutedColor),
          const SizedBox(height: AppConstants.space16),
          Text(
            context.tr('no_hives_yet'),
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('no_hives_subtitle'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(30),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openAddHive(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                child: Text(
                  context.tr('add_first_hive'),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
