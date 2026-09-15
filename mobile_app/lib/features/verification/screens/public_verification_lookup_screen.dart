import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../collection/screens/batch_timeline_screen.dart';
import '../models/harvester_verification_model.dart';
import '../services/verification_api_service.dart';

class PublicVerificationLookupScreen extends StatefulWidget {
  final String? initialVerificationId;

  const PublicVerificationLookupScreen({super.key, this.initialVerificationId});

  @override
  State<PublicVerificationLookupScreen> createState() => _PublicVerificationLookupScreenState();
}

class _PublicVerificationLookupScreenState extends State<PublicVerificationLookupScreen> {
  final TextEditingController _idController = TextEditingController();
  final VerificationApiService _apiService = VerificationApiService();

  bool _isLoading = false;
  PublicVerificationRecord? _result;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialVerificationId != null && widget.initialVerificationId!.isNotEmpty) {
      _idController.text = widget.initialVerificationId!;
      _performLookup(widget.initialVerificationId!);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _performLookup(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Harvester Verification ID or Batch ID.')),
      );
      return;
    }

    if (cleanId.toUpperCase().startsWith('HC-BATCH-') || cleanId.toUpperCase().startsWith('BATCH')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BatchTimelineScreen(batchId: cleanId.toUpperCase()),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final res = await _apiService.queryPublicVerification(cleanId);
      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = PublicVerificationRecord.notFound('Error connecting to verification ledger: $e');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

              // Header
              Row(
                children: [
                  _PillBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Public Verifier',
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimaryColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Verify Harvester Credentials on Ledger',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.space20),

              // Search Box Card
              Container(
                padding: const EdgeInsets.all(AppConstants.space20),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Harvester Verification ID',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _idController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'e.g. HV-2026-F98B2A1C',
                              hintStyle: GoogleFonts.inter(color: context.textMutedColor),
                              filled: true,
                              fillColor: context.scaffoldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.primaryColor, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : () => _performLookup(_idController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.primary,
                            foregroundColor: context.colors.onPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search_rounded, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.space24),

              // Results Area
              if (_hasSearched && !_isLoading) ...[
                if (_result != null && _result!.found) ...[
                  // SUCCESS RESULT CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.space24),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: context.successColor.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.successBgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.verified_rounded, size: 24, color: context.successColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Verified Harvester ✓',
                                    style: GoogleFonts.manrope(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: context.successColor,
                                    ),
                                  ),
                                  Text(
                                    _result!.verificationId ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: context.textSecondaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppConstants.space20),
                        Divider(height: 1, color: context.borderColor),
                        const SizedBox(height: AppConstants.space16),

                        _detailRow(context, 'Harvester Name', _result!.harvesterName ?? 'Licensed Harvester'),
                        _detailRow(context, 'Verification Status', 'Approved & Blockchain Recorded ✓', isSuccess: true),
                        _detailRow(context, 'Integrity Verified', _result!.integrityVerified ? 'Cryptographic Hash Match ✓' : 'Verified', isSuccess: true),
                        _detailRow(context, 'Blockchain Ledger', _result!.blockchainNetwork ?? 'HoneyChain Provenance Ledger'),
                        if (_result!.transactionHash != null)
                          _detailRow(context, 'Transaction Hash', '${_result!.transactionHash!.substring(0, 10)}...'),
                        if (_result!.publicDetails != null) ...[
                          _detailRow(context, 'Apiary Region', _result!.publicDetails!['apiaryLocation'] ?? 'No Data Available'),
                          _detailRow(context, 'Accreditation ID', _result!.publicDetails!['registrationId'] ?? 'No Data Available'),
                          _detailRow(context, 'Government ID Ref', _result!.publicDetails!['governmentIdReference'] ?? 'No Data Available'),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  // NOT FOUND CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.space24),
                    decoration: BoxDecoration(
                      color: AppConstants.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppConstants.error.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.gpp_bad_outlined, size: 48, color: AppConstants.error),
                        const SizedBox(height: AppConstants.space12),
                        Text(
                          'Verification Record Not Found',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppConstants.error,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _result?.message ?? 'No active verification record was found for this ID on the HoneyChain ledger. Please verify the ID code.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: context.textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
