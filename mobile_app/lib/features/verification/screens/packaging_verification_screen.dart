import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/pill_page_header.dart';
import '../../profile/controllers/user_controller.dart';
import '../controllers/verification_controller.dart';

/// Packaging Manager Profile Verification (2/2)
/// 1. Packaging Facility Details (Facility/Company Name + Address & License)
/// 2. License & KYC (Government ID + Regulatory Compliance)
class PackagingVerificationScreen extends StatefulWidget {
  const PackagingVerificationScreen({super.key});

  @override
  State<PackagingVerificationScreen> createState() => _PackagingVerificationScreenState();
}

class _PackagingVerificationScreenState extends State<PackagingVerificationScreen> {


  // Step 2: Facility Details Controllers
  late TextEditingController _orgController;
  late TextEditingController _locationController;
  late TextEditingController _licenseController;

  // Step 3: License & KYC Controllers
  String _selectedGovIdType = 'AADHAAR';
  late TextEditingController _govIdController;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserController>().user;
    final packagingVer = context.read<VerificationController>().packagingVerification;



    _orgController = TextEditingController(text: packagingVer.organizationName ?? user.organizationName ?? '');
    _locationController = TextEditingController(text: packagingVer.facilityLocation ?? user.facilityLocation ?? '');
    _licenseController = TextEditingController(text: packagingVer.packagingLicenseNumber ?? user.licenseNumber ?? '');

    _selectedGovIdType = packagingVer.governmentIdType ?? 'AADHAAR';
    _govIdController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = user.id ?? user.email;
      if (userId.isNotEmpty) {
        context.read<VerificationController>().loadPackagingVerification(userId);
      }
    });
  }

  @override
  void dispose() {

    _orgController.dispose();
    _locationController.dispose();
    _licenseController.dispose();
    _govIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verCtrl = context.watch<VerificationController>();
    final packagingVer = verCtrl.packagingVerification;
    final isFullyVerified = packagingVer.isFullyVerified;
    final completedCount = packagingVer.completedStepsCount;

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
              const PillPageHeader(title: 'Packaging Verification'),
              const SizedBox(height: AppConstants.space16),

              // ── Top Summary Card ──
              _buildProgressCard(context, completedCount, isFullyVerified),
              const SizedBox(height: AppConstants.space20),

              // Feedback messages
              if (verCtrl.errorMessage != null) ...[
                _buildFeedbackBanner(context, verCtrl.errorMessage!, isError: true),
                const SizedBox(height: AppConstants.space16),
              ],
              if (verCtrl.successMessage != null) ...[
                _buildFeedbackBanner(context, verCtrl.successMessage!, isError: false),
                const SizedBox(height: AppConstants.space16),
              ],



              // ── Step 2: Packaging Facility Details ──
              _buildStep2FacilityCard(context, verCtrl),
              const SizedBox(height: AppConstants.space16),

              // ── Step 3: License & KYC ──
              _buildStep3KycCard(context, verCtrl),
              const SizedBox(height: AppConstants.space32),

              // ── Bottom Safe Area Spacer ──
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, int count, bool isVerified) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVerified
              ? context.successColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white.withValues(alpha: 0.1) : context.borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: isVerified
                ? context.successColor.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROFILE VERIFICATION — ' + count.toString() + '/2',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isVerified ? context.successColor : context.textPrimaryColor,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isVerified
                          ? 'Your packaging manager profile is 100% verified & active.'
                          : 'Complete all 2 parameters to accept packaging requests.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isVerified ? context.successBgColor : context.primarySoftColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isVerified ? context.successColor.withValues(alpha: 0.4) : context.borderColor,
                  ),
                ),
                child: Text(
                  count.toString() + '/2',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isVerified ? context.successColor : context.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: count / 2.0,
              minHeight: 8,
              backgroundColor: context.scaffoldBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                isVerified ? context.successColor : context.colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Checklist

          _buildChecklistItem(
            context,
            title: 'Packaging Facility Details',
            subtitle: 'Facility name, address & packaging license',
            isComplete: count >= 1 && context.watch<VerificationController>().packagingVerification.isStep2FacilityComplete,
          ),
          const SizedBox(height: 8),
          _buildChecklistItem(
            context,
            title: 'License & KYC',
            subtitle: 'Government ID & regulatory compliance check',
            isComplete: count == 2 && context.watch<VerificationController>().packagingVerification.isStep3KycComplete,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isComplete,
  }) {
    return Row(
      children: [
        Icon(
          isComplete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 18,
          color: isComplete ? context.successColor : context.textMutedColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: isComplete ? '✓ ' : '• ',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isComplete ? context.successColor : context.textSecondaryColor,
              ),
              children: [
                TextSpan(
                  text: title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: isComplete ? context.successColor : context.textPrimaryColor,
                  ),
                ),
                TextSpan(
                  text: ' — ' + subtitle,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackBanner(BuildContext context, String msg, {required bool isError}) {
    final bgColor = isError ? AppConstants.error.withValues(alpha: 0.12) : context.successBgColor;
    final fgColor = isError ? AppConstants.error : context.successColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, size: 18, color: fgColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.inter(fontSize: 13, color: fgColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }



  // ── Step 2: Packaging Facility Details ──
  Widget _buildStep2FacilityCard(BuildContext context, VerificationController verCtrl) {
    final packagingVer = verCtrl.packagingVerification;
    final isDone = packagingVer.isStep2FacilityComplete;
    final user = context.read<UserController>().user;
    final userId = user.id ?? user.email;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone ? context.successBgColor : context.primarySoftColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '1',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDone ? context.successColor : context.textPrimaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Facility Details',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(context, isDone ? 'Verified ✓' : 'Pending', isDone),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Enter registered packaging plant location, facility details and operational license.',
            style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 16),

          if (isDone) ...[
            _buildVerifiedDataTile(context, 'Facility Name', packagingVer.organizationName ?? 'HoneyChain Eco Packaging Facility'),
            const SizedBox(height: 8),
            _buildVerifiedDataTile(context, 'Facility Location', packagingVer.facilityLocation ?? 'Unit 8, Organic Food Processing Park'),
            const SizedBox(height: 8),
            _buildVerifiedDataTile(context, 'Packaging License No.', packagingVer.packagingLicenseNumber ?? 'PKG-FSSAI-2026-B99'),
          ] else ...[
            AppTextField(
              controller: _orgController,
              labelText: 'Facility / Plant Name',
              hintText: 'e.g. HoneyChain Eco Packaging Facility',
              prefixIcon: Icon(Icons.inventory_2_outlined, size: 20, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _locationController,
              labelText: 'Packaging Plant Address',
              hintText: 'Enter your complete address',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _licenseController,
              labelText: 'Packaging License Number',
              hintText: 'e.g. PKG-FSSAI-2026-B99',
              prefixIcon: Icon(Icons.badge_outlined, size: 20, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: verCtrl.isLoading
                    ? null
                    : () async {
                        final org = _orgController.text.trim();
                        final loc = _locationController.text.trim();
                        final lic = _licenseController.text.trim();

                        if (org.isEmpty || loc.isEmpty || lic.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill all facility details')),
                          );
                          return;
                        }

                        await verCtrl.submitPackagingDetails(
                          packagerId: userId,
                          organizationName: org,
                          facilityLocation: loc,
                          packagingLicenseNumber: lic,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Save & Verify Facility Details',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 3: License & KYC ──
  Widget _buildStep3KycCard(BuildContext context, VerificationController verCtrl) {
    final packagingVer = verCtrl.packagingVerification;
    final isDone = packagingVer.isStep3KycComplete;
    final user = context.read<UserController>().user;
    final userId = user.id ?? user.email;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone ? context.successBgColor : context.primarySoftColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '2',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDone ? context.successColor : context.textPrimaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'License & KYC Verification',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(context, isDone ? 'Verified ✓' : 'Pending', isDone),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Authenticate government ID and packaging authority certification.',
            style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 16),

          if (isDone) ...[
            _buildVerifiedDataTile(context, 'Government ID Ref', packagingVer.governmentIdReference ?? 'AADHAAR-***5432'),
            const SizedBox(height: 8),
            _buildVerifiedDataTile(context, 'KYC Status', (packagingVer.kycStatus) + ' via ' + (packagingVer.kycProvider ?? 'AADHAAR_KYC_GATEWAY')),
          ] else ...[
            // Document Type Selector
            DropdownButtonFormField<String>(
              value: _selectedGovIdType,
              dropdownColor: context.surfaceColor,
              style: GoogleFonts.inter(color: context.textPrimaryColor, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Government ID Type',
                labelStyle: GoogleFonts.inter(color: context.textSecondaryColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'AADHAAR', child: Text('Aadhaar Card (UIDAI)')),
                DropdownMenuItem(value: 'PAN', child: Text('Permanent Account Number (PAN)')),
                DropdownMenuItem(value: 'PASSPORT', child: Text('Passport')),
                DropdownMenuItem(value: 'VOTER_ID', child: Text('Voter ID')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedGovIdType = val);
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _govIdController,
              labelText: 'Government ID Number',
              hintText: _selectedGovIdType == 'AADHAAR' ? '12-digit Aadhaar Number' : 'Enter ID number',
              prefixIcon: Icon(Icons.badge_rounded, size: 20, color: context.textSecondaryColor),
              keyboardType: _selectedGovIdType == 'AADHAAR' ? TextInputType.number : TextInputType.text,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: verCtrl.isLoading
                    ? null
                    : () async {
                        final idNum = _govIdController.text.trim();

                        if (idNum.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter Government ID number')),
                          );
                          return;
                        }

                        await verCtrl.submitPackagingKyc(
                          packagerId: userId,
                          governmentIdType: _selectedGovIdType,
                          governmentIdNumber: idNum,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Submit & Verify KYC',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, String text, bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified ? context.successBgColor : context.primarySoftColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? context.successColor.withValues(alpha: 0.4) : context.borderColor,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isVerified ? context.successColor : context.textSecondaryColor,
        ),
      ),
    );
  }

  Widget _buildVerifiedDataTile(BuildContext context, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
          ),
        ],
      ),
    );
  }
}
