import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';
import '../../hives/controllers/hive_controller.dart';
import '../../hives/screens/hive_details_screen.dart';
import '../../verification/controllers/verification_controller.dart';
import '../../verification/screens/collector_verification_screen.dart';

class HarvesterDetailScreen extends StatelessWidget {
  final WorkflowRequest request;

  const HarvesterDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final hiveCtrl = context.watch<HiveController>();
    final workflowCtrl = context.watch<WorkflowController>();
    
    // Connected Hives
    final connectedHives = hiveCtrl.hives.where((h) => h.apiaryLocation == request.location).toList();

    // 7-Day History (Recent requests from this harvester)
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final historyEvents = workflowCtrl.allRequests.where((req) => 
      req.harvesterName == request.harvesterName && 
      req.createdAt.isAfter(sevenDaysAgo)
    ).toList();
    historyEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const _PillBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Harvester Details',
                      style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimaryColor, letterSpacing: -0.3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.space20),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Harvester Info Card
            Container(
              padding: const EdgeInsets.all(AppConstants.space16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: context.primarySoftColor,
                    child: Text(
                      request.harvesterName.isNotEmpty ? request.harvesterName[0].toUpperCase() : 'H',
                      style: GoogleFonts.manrope(

                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.harvesterName,
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Role: Harvester',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: context.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 14, color: context.successColor),
                            const SizedBox(width: 4),
                            Text(
                              'Verified • Profile Complete',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: context.successColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppConstants.space24),
            
            // 7-DAY HISTORY SECTION
            Text(
              '7-Day History',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: AppConstants.space12),
            
            if (historyEvents.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.space20),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 32, color: context.textMutedColor),
                    const SizedBox(height: 12),
                    Text(
                      'No historical data available.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: historyEvents.length,
                itemBuilder: (context, index) {
                  final event = historyEvents[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppConstants.space12),
                    padding: const EdgeInsets.all(AppConstants.space16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StatusBadge(status: event.status),
                            Text(
                              DateFormat('MMM d, h:mm a').format(event.createdAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: context.textMutedColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.space8),
                        Text(
                          'Harvest Event: ${event.batchId}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimated Production: ${event.estimatedQuantityKg.toStringAsFixed(1)} kg',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: AppConstants.space24),

            // CONNECTED HIVES SECTION
            Text(
              'Connected Hives',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: AppConstants.space12),
            
            if (connectedHives.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.space20),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.hive_outlined, size: 32, color: context.textMutedColor),
                    const SizedBox(height: 12),
                    Text(
                      'No connected hives found.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: connectedHives.length,
                itemBuilder: (context, index) {
                  final hive = connectedHives[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppConstants.space12),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        tileColor: context.surfaceColor,
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                        side: BorderSide(color: context.borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        hive.name,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('ID: ${hive.id}', style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor)),
                          Text('Location: ${hive.location}', style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor)),
                          Text('Updated: ${hive.updatedAt.toString().substring(0, 16)}', style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: hive.statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hive.overallHealth,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: hive.statusColor,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HiveDetailsScreen(hiveId: hive.id),
                          ),
                        );
                      },
                    ),
                  ),
                  );
                },
              ),

            if (request.status == RequestStatus.pending) ...[
              const SizedBox(height: AppConstants.space24),
              Text(
                'Request Actions',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: AppConstants.space12),

              Builder(
                builder: (context) {
                  final verCtrl = context.watch<VerificationController>();
                  final isCollectorVerified = verCtrl.collectorVerification.isFullyVerified;

                  return Column(
                    children: [
                      if (!isCollectorVerified) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: AppConstants.space12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.warningBgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.warningColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_person_outlined, size: 18, color: context.warningColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Complete your profile verification to accept requests.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.warningColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                context.read<WorkflowController>().rejectRequest(
                                  request.id,
                                  actorRole: 'COLLECTOR_PROCESSOR',
                                  reason: 'Rejected by collection center',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Request rejected & recorded.'), backgroundColor: AppConstants.error),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppConstants.error,
                                side: const BorderSide(color: AppConstants.error),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium)),
                              ),
                              child: Text('Reject Batch', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isCollectorVerified
                                  ? () async {
                                      await context.read<WorkflowController>().acceptRequest(request.id);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Harvest batch accepted! You can now extract and send to Lab.')),
                                        );
                                      }
                                    }
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CollectorVerificationScreen()),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Complete your profile verification to accept requests.'),
                                          backgroundColor: AppConstants.warning,
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCollectorVerified ? context.colors.primary : context.borderColor,
                                foregroundColor: isCollectorVerified ? context.colors.onPrimary : context.textMutedColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium)),
                              ),
                              child: Text(
                                'Accept Request',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: isCollectorVerified ? context.colors.onPrimary : context.textMutedColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _PillBackButton extends StatelessWidget {
  const _PillBackButton();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: context.textPrimaryColor),
        ),
      ),
    );
  }
}
