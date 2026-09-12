import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
    // Real, verifiable payload: a deep link resolving to this batch's
    // on-chain traceability record (scanners open it; it is not decorative).
    final verifyUrl =
        '${AppConstants.backendBaseUrl}/verify?batch=${Uri.encodeComponent(request.batchId)}';
    final latestTx = request.txHash;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const _PillBackButton(),
                  const SizedBox(width: 14),
                  Text(
                    'Batch QR Code',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.space24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Scan to Verify Batch',
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimaryColor,
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppConstants.space8),
                      Text(
                        'This QR encodes real traceability data for this honey batch.',
                        style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
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
                                data: verifyUrl,
                                size: 220,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppConstants.space24),
                            Text(
                              request.batchId,
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppConstants.space8),
                            Text(
                              request.harvesterName,
                              style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppConstants.space16),
                            StatusBadge(status: request.status),
                            if (latestTx != null && latestTx.isNotEmpty) ...[
                              const SizedBox(height: AppConstants.space12),
                              Text(
                                'Ledger tx: ${latestTx.substring(0, latestTx.length > 18 ? 18 : latestTx.length)}…',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: context.textMutedColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.space32),
                      AppButton(
                        text: 'Copy verification link',
                        variant: AppButtonVariant.outlined,
                        icon: const Icon(Icons.link_rounded, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: verifyUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Verification link copied')),
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
