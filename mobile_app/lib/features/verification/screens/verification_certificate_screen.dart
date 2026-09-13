import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/controllers/user_controller.dart';
import '../controllers/verification_controller.dart';
import 'public_verification_lookup_screen.dart';

class VerificationCertificateScreen extends StatelessWidget {
  const VerificationCertificateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ver = context.watch<VerificationController>().verification;
    final user = context.watch<UserController>().user;
    final verificationId = ver.verificationId ?? (user.beekeeperId != null ? 'BKR-${user.beekeeperId}' : 'UNVERIFIED');
    final qrPayload = ver.verificationId != null
        ? 'https://honeychain.io/verify/harvester/${ver.verificationId}'
        : 'https://honeychain.io/verify/harvester/$verificationId';
    final harvesterName = user.name.isNotEmpty ? user.name : 'Licensed Harvester';

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppConstants.space12),

              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PillBackButton(onTap: () => Navigator.pop(context)),
                  Text(
                    'Verification Certificate',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.share_outlined, color: context.textPrimaryColor),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: qrPayload));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verification certificate URL copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.space20),

              // Main Certificate Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.space24),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: context.successColor.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: context.successColor.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Verified Harvester Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: ver.isFullyVerified ? context.successBgColor : context.primarySoftColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: (ver.isFullyVerified ? context.successColor : context.primaryDarkColor).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ver.isFullyVerified ? Icons.verified_rounded : Icons.pending_outlined,
                            size: 16,
                            color: ver.isFullyVerified ? context.successColor : context.primaryDarkColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ver.isFullyVerified ? 'Verified Harvester ✓' : 'Verification In Progress',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: ver.isFullyVerified ? context.successColor : context.primaryDarkColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.space16),

                    // Harvester Name
                    Text(
                      harvesterName,
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HoneyChain Authorized Apiary Operator',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                    ),

                    const SizedBox(height: AppConstants.space20),

                    // Real QR Code
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 180.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFFE58B00),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppConstants.space16),

                    // Harvester Verification ID with copy
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: verificationId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied ID: $verificationId')),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.primarySoftColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              verificationId,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.primaryDarkColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.copy_rounded, size: 14, color: context.primaryDarkColor),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppConstants.space20),
                    Divider(height: 1, color: context.borderColor),
                    const SizedBox(height: AppConstants.space16),

                    // Verification Metadata Rows
                    _metaRow(context, 'Status', ver.isFullyVerified ? 'Approved & Verified ✓' : ver.verificationStatus, isSuccess: ver.isFullyVerified),
                    _metaRow(context, 'Blockchain Network', ver.blockchainNetwork ?? 'HoneyChain Provenance Ledger'),
                    _metaRow(
                      context,
                      'Transaction Hash',
                      ver.transactionHash != null && ver.transactionHash!.length > 18
                          ? '${ver.transactionHash!.substring(0, 10)}...${ver.transactionHash!.substring(ver.transactionHash!.length - 8)}'
                          : ver.transactionHash ?? 'Pending Blockchain Submission',
                    ),
                    _metaRow(
                      context,
                      'Record Hash (SHA-256)',
                      ver.verificationHash != null && ver.verificationHash!.length > 18
                          ? '${ver.verificationHash!.substring(0, 10)}...${ver.verificationHash!.substring(ver.verificationHash!.length - 8)}'
                          : ver.verificationHash ?? 'Pending Generation',
                    ),
                    _metaRow(context, 'Integrity Status', ver.isFullyVerified ? 'Cryptographic Match Confirmed ✓' : 'Pending Verification', isSuccess: ver.isFullyVerified),
                    _metaRow(context, 'Apiary Region', ver.apiaryLocation ?? 'Not Registered'),
                    _metaRow(context, 'Government ID Ref', ver.governmentIdReference ?? 'Not Submitted'),
                    _metaRow(context, 'Accreditation ID', ver.registrationId ?? 'Not Submitted'),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.space20),

              // Public Verification Lookup Action
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicVerificationLookupScreen(
                          initialVerificationId: verificationId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: Text(
                    'Inspect Live Public Verifier View',
                    style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primarySoftColor,
                    foregroundColor: context.primaryDarkColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(BuildContext context, String label, String value, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSuccess ? context.successColor : context.textPrimaryColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PillBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
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
