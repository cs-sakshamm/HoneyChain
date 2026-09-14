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
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    const _PillBackButton(),
                    const SizedBox(width: 14),
                  ],
                  Text(
                    'Lab History',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_outlined, size: 64, color: context.textMutedColor),
                          const SizedBox(height: AppConstants.space16),
                          Text(
                            'No lab history yet',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: AppConstants.space8),
                          Text(
                            'Completed lab reports will appear here.',
                            style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppConstants.space16, AppConstants.space16, AppConstants.space16, 120),
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
                                    style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
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
                                    style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                                  ),
                                ],
                              ),
                              if (req.qualityScore != null) ...[
                                const SizedBox(height: AppConstants.space8),
                                Row(
                                  children: [
                                    Icon(Icons.score_outlined, size: 16, color: context.successColor),
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
            ),
          ],
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
