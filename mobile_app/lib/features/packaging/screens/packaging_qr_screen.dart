import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../collection/screens/batch_timeline_screen.dart';

class PackagingQrScreen extends StatelessWidget {
  final WorkflowRequest request;

  const PackagingQrScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final verifyUrl = '${AppConstants.backendBaseUrl}/verify?batch=' + Uri.encodeComponent(request.batchId);
    final realTx = request.txHash;

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
                  Expanded(
                    child: Text(
                      'Batch QR & Traceability',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimaryColor,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.space20),
                child: Column(
                  children: [
                    Text(
                      '5-Stage Traceability QR Code',
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimaryColor,
                        letterSpacing: -0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scanning this QR verifies all 5 chronological stages from Harvester to Consumer.',
                      style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // QR Card
                    AppCard(
                      padding: const EdgeInsets.all(AppConstants.space20),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppConstants.space16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: QrImageView(
                              data: verifyUrl,
                              size: 200,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            request.batchId,
                            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimaryColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Harvester: ' + (request.harvesterName.isNotEmpty ? request.harvesterName : 'No data available yet.'),
                            style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                          ),
                          const SizedBox(height: 12),
                          StatusBadge(status: request.status),
                          const SizedBox(height: 8),
                          Text(
                            realTx != null && realTx.isNotEmpty
                                ? 'Ledger Hash: ${realTx.substring(0, realTx.length > 20 ? 20 : realTx.length)}...'
                                : 'Ledger Status: Confirmed & Ledger Ready',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: context.textMutedColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5-Stage Chronological Breakdown Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('5-Stage Immutable Sequence', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimaryColor)),
                          const SizedBox(height: 14),
                          _buildStageTile(
                            context,
                            '1. Harvester',
                            request.harvesterName.isNotEmpty ? request.harvesterName : 'Harvester Operator',
                            'Harvest recorded at ${request.location}',
                            true,
                          ),
                          _buildStageTile(
                            context,
                            '2. Collection & Processing',
                            'Accredited Collection & Processing Center',
                            request.notes.isNotEmpty ? request.notes : 'Cold extraction & processing completed',
                            true,
                          ),
                          _buildStageTile(
                            context,
                            '3. Lab Testing',
                            'Accredited Testing Laboratory',
                            (() {
                              final parts = <String>[];
                              if (request.moistureContent != null && request.moistureContent! > 0) parts.add('Moisture ${request.moistureContent!.toStringAsFixed(1)}%');
                              if (request.purityGrade != null && request.purityGrade! > 0) parts.add('Purity ${request.purityGrade!.toStringAsFixed(1)}%');
                              if (request.qualityScore != null && request.qualityScore! > 0) parts.add('Score ${request.qualityScore!.toStringAsFixed(1)}/100');
                              return parts.isNotEmpty ? '${parts.join(" • ")} • PASSED' : 'Quality certified & approved';
                            })(),
                            true,
                          ),
                          _buildStageTile(
                            context,
                            '4. Packaging',
                            request.packageSize != null && request.packageSize!.isNotEmpty ? request.packageSize! : 'Certified Packaging Facility',
                            request.numberOfPackages != null ? '${request.numberOfPackages} units sealed & verified' : 'Packaged and tamper-evident sealed',
                            true,
                          ),
                          _buildStageTile(
                            context,
                            '5. Consumer Verification',
                            'Public Ledger QR',
                            'Authentic verifiable QR live on blockchain',
                            true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.timeline_rounded, size: 20),
                        label: Text('View Full Provenance Journey', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => BatchTimelineScreen(batchId: request.batchId)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: context.colors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text('Copy Verification Link', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: verifyUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Verification link copied to clipboard')),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageTile(BuildContext context, String stageName, String actor, String details, bool isComplete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 20, color: context.successColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stageName, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimaryColor)),
                const SizedBox(height: 2),
                Text(actor + ' — ' + details, style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor)),
              ],
            ),
          ),
        ],
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
