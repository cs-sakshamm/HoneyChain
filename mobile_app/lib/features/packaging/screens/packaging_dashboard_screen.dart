import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import 'packaging_qr_screen.dart';

class PackagingDashboardScreen extends StatelessWidget {
  const PackagingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkflowController>();
    
    // Combining pending and those approved that need QR gen (from history)
    final pendingRequests = controller.packagingPendingRequests;
    final readyForQrRequests = controller.packagingHistory
        .where((req) => req.status == RequestStatus.packagingApproved)
        .toList();
    final qrGeneratedRequests = controller.packagingHistory
        .where((req) => req.status == RequestStatus.qrGenerated)
        .toList();

    final allDisplayRequests = [
      ...pendingRequests,
      ...readyForQrRequests,
      ...qrGeneratedRequests,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Packaging Dashboard',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: context.surfaceColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: allDisplayRequests.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.space16,
                vertical: AppConstants.space24,
              ),
              itemCount: allDisplayRequests.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
              itemBuilder: (context, index) {
                final request = allDisplayRequests[index];
                return _PackagingBatchCard(request: request);
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
            Icons.inventory_2_outlined,
            size: 64,
            color: context.textMutedColor,
          ),
          const SizedBox(height: AppConstants.space16),
          Text(
            'No Batches',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.textPrimaryColor,
                ),
          ),
          const SizedBox(height: AppConstants.space8),
          Text(
            'No batches currently require packaging action.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.textSecondaryColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _PackagingBatchCard extends StatelessWidget {
  final WorkflowRequest request;

  const _PackagingBatchCard({required this.request});

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
              Icon(Icons.person_outline, size: 16, color: context.textSecondaryColor),
              const SizedBox(width: AppConstants.space8),
              Expanded(
                child: Text(
                  request.harvesterName,
                  style: Theme.of(context).textTheme.bodyMedium,
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
                DateFormat('MMM dd, yyyy').format(request.createdAt),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space16),
          const Divider(),
          const SizedBox(height: AppConstants.space16),
          _buildActionRow(context),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    if (request.status == RequestStatus.labApproved) {
      return AppButton(
        text: 'Allow Packaging',
        onPressed: () => _showAllowPackagingDialog(context),
      );
    } else if (request.status == RequestStatus.packagingApproved) {
      return AppButton(
        text: 'Generate QR',
        variant: AppButtonVariant.primary,
        onPressed: () {
          context.read<WorkflowController>().generateQr(request.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PackagingQrScreen(request: request),
            ),
          );
        },
      );
    } else if (request.status == RequestStatus.qrGenerated) {
      return AppButton(
        text: 'View QR',
        variant: AppButtonVariant.outlined,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PackagingQrScreen(request: request),
            ),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  void _showAllowPackagingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Allow Packaging'),
          content: const Text('Allow this batch for packaging?'),
          actions: [
            AppButton(
              text: 'Cancel',
              variant: AppButtonVariant.text,
              width: 80,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppButton(
              text: 'Allow',
              width: 80,
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<WorkflowController>().allowPackaging(request.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Packaging allowed successfully')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
