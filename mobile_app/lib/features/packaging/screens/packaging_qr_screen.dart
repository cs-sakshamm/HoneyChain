import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';

class PackagingQrScreen extends StatelessWidget {
  final WorkflowRequest request;

  const PackagingQrScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final qrData = 'Batch: ${request.batchId}\n'
        'Harvester: ${request.harvesterName}\n'
        'Status: ${request.status.label}\n'
        'Date: ${DateFormat('MMM dd, yyyy').format(request.createdAt)}';

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Batch QR Code',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: context.surfaceColor,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Batch QR Code',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.space32),
              AppCard(
                padding: const EdgeInsets.all(AppConstants.space24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppConstants.space16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: QrImageView(
                        data: qrData,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppConstants.space24),
                    Text(
                      'Batch ID: ${request.batchId}',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.space8),
                    Text(
                      'Harvester: ${request.harvesterName}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    StatusBadge(status: request.status),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.space32),
              AppButton(
                text: 'Download QR',
                variant: AppButtonVariant.outlined,
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR saved to gallery')),
                  );
                },
              ),
              const SizedBox(height: AppConstants.space16),
              AppButton(
                text: 'Close',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
