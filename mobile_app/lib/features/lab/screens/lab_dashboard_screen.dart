import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import 'lab_report_screen.dart';

class LabDashboardScreen extends StatelessWidget {
  const LabDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<WorkflowController>().labPendingRequests;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Lab Testing',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: context.borderColor,
            height: 1.0,
          ),
        ),
      ),
      body: requests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 64,
                    color: context.textMutedColor,
                  ),
                  const SizedBox(height: AppConstants.space16),
                  Text(
                    'No pending samples',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: AppConstants.space8),
                  Text(
                    'New requests will appear here once approved.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: context.textMutedColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppConstants.space16),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
              itemBuilder: (context, index) {
                final req = requests[index];
                final formattedDate = DateFormat('MMM dd, yyyy').format(req.createdAt);

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Sample: ${req.labSampleId}',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppConstants.space8),
                          StatusBadge(status: req.status),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space12),
                      Row(
                        children: [
                          Icon(Icons.tag_rounded, size: 16, color: context.textSecondaryColor),
                          const SizedBox(width: AppConstants.space8),
                          Text(
                            'Batch: ${req.batchId}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space8),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 16, color: context.textSecondaryColor),
                          const SizedBox(width: AppConstants.space8),
                          Text(
                            req.harvesterName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 16, color: context.textSecondaryColor),
                          const SizedBox(width: AppConstants.space8),
                          Text(
                            formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space16),
                      AppButton(
                        text: 'Open Request',
                        variant: AppButtonVariant.primary,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LabReportScreen(request: req),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
