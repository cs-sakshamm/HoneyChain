import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/widgets/pill_back_button.dart';

class CollectionHistoryScreen extends StatelessWidget {
  const CollectionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<WorkflowController>().collectionHistory;

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
                    context.tr('processing_history') == 'processing_history'
                        ? 'Processing History'
                        : context.tr('processing_history'),
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
              child: requests.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppConstants.space16, AppConstants.space16, AppConstants.space16, 120),
                      itemCount: requests.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        return _buildHistoryCard(context, req);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 64, color: context.textMutedColor.withValues(alpha: 0.5)),
          const SizedBox(height: AppConstants.space16),
          Text(
            context.tr('no_history') == 'no_history' ? 'No history yet' : context.tr('no_history'),
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
          ),
          const SizedBox(height: AppConstants.space8),
          Text(
            'Processed requests will appear here.',
            style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, WorkflowRequest req) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(status: req.status),
              Text(
                req.batchId,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textMutedColor),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Text(
            req.harvesterName,
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
          ),
          const SizedBox(height: AppConstants.space8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: context.textSecondaryColor),
              const SizedBox(width: AppConstants.space4),
              Expanded(
                child: Text(req.location, style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor)),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space4),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: context.textSecondaryColor),
              const SizedBox(width: AppConstants.space4),
              Expanded(
                child: Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(req.createdAt),
                  style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.space12, vertical: AppConstants.space8),
            decoration: BoxDecoration(
              color: context.scaffoldBg,
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Est. Quantity:',
                  style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor),
                ),
                const SizedBox(width: AppConstants.space8),
                Text(
                  '${req.estimatedQuantityKg.toStringAsFixed(1)} kg',
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

