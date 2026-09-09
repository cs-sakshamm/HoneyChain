import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';

class PackagingHistoryScreen extends StatelessWidget {
  const PackagingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkflowController>();
    final history = controller.packagingHistory;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Packaging History',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: context.surfaceColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: history.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.space16,
                vertical: AppConstants.space24,
              ),
              itemCount: history.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
              itemBuilder: (context, index) {
                final request = history[index];
                return _HistoryCard(request: request);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: context.textMutedColor,
          ),
          const SizedBox(height: AppConstants.space16),
          Text(
            'No History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.textPrimaryColor,
                ),
          ),
          const SizedBox(height: AppConstants.space8),
          Text(
            'Processed packaging requests will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.textSecondaryColor,
                ),
          ),
        ],
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
                style: Theme.of(context).textTheme.titleMedium,
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
                style: Theme.of(context).textTheme.bodyMedium,
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
