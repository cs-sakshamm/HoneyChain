import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';

class LabHistoryScreen extends StatelessWidget {
  const LabHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<WorkflowController>().labHistory;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Lab History',
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
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: context.textMutedColor,
                  ),
                  const SizedBox(height: AppConstants.space16),
                  Text(
                    'No history found',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppConstants.space16),
              itemCount: history.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
              itemBuilder: (context, index) {
                final req = history[index];
                final formattedDate = req.labReportDate != null
                    ? DateFormat('MMM dd, yyyy').format(req.labReportDate!)
                    : 'Unknown Date';

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Sample: ${req.labSampleId ?? 'N/A'}',
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
                          Icon(Icons.calendar_today_outlined, size: 16, color: context.textSecondaryColor),
                          const SizedBox(width: AppConstants.space8),
                          Text(
                            'Tested: $formattedDate',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      if (req.qualityScore != null) ...[
                        const SizedBox(height: AppConstants.space8),
                        Row(
                          children: [
                            Icon(Icons.score_outlined, size: 16, color: context.textSecondaryColor),
                            const SizedBox(width: AppConstants.space8),
                            Text(
                              'Quality Score: ${req.qualityScore}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
