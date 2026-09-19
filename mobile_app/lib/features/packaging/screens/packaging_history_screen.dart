import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/pill_back_button.dart';

class PackagingHistoryScreen extends StatelessWidget {
  const PackagingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkflowController>();
    final history = controller.packagingHistory;

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
                    const PillBackButton(),
                    const SizedBox(width: 14),
                  ],
                  Text(
                    'Packaging History',
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
                          Icon(Icons.inventory_2_outlined, size: 64, color: context.textMutedColor),
                          const SizedBox(height: AppConstants.space16),
                          Text(
                            'No Packaging History',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: AppConstants.space8),
                          Text(
                            'Processed packaging requests will appear here.',
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
                        final request = history[index];
                        return _HistoryCard(request: request);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final WorkflowRequest request;

  const _HistoryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                request.batchId,
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
              ),
              StatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: context.textSecondaryColor),
              const SizedBox(width: AppConstants.space8),
              Text(
                'Approved: ${request.packagingApprovedDate != null ? DateFormat('MMM dd, yyyy').format(request.packagingApprovedDate!) : 'N/A'}',
                style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
              ),
            ],
          ),
          if (request.qrGenerated) ...[
            const SizedBox(height: AppConstants.space8),
            Row(
              children: [
                Icon(Icons.qr_code_2, size: 16, color: context.primaryDarkColor),
                const SizedBox(width: AppConstants.space8),
                Text(
                  'QR Code Generated',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.primaryDarkColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

