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

/// Collector / Collection & Processing Profile Verification Screen (3/3)
/// 1. Identity Verification (Full Name + Mobile OTP)
/// 2. Business Verification (Organization / Center Name + Center Address)
/// 3. License & KYC (Government ID + Real KYC Verification)
class CollectorVerificationScreen extends StatefulWidget {
  const CollectorVerificationScreen({super.key});

  @override
  State<CollectorVerificationScreen> createState() => _CollectorVerificationScreenState();
}

class _CollectorVerificationScreenState extends State<CollectorVerificationScreen> {
  // Step 1: Identity Controllers
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _otpController;

  // Step 2: Business Controllers
  late TextEditingController _orgController;
  late TextEditingController _locationController;
  late TextEditingController _detailsController;

  // Step 3: License & KYC Controllers
  String _selectedGovIdType = 'AADHAAR';
  late TextEditingController _govIdController;
  late TextEditingController _licenseController;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserController>().user;
    final collectorVer = context.read<VerificationController>().collectorVerification;

    _nameController = TextEditingController(text: collectorVer.fullName ?? user.name);
    _mobileController = TextEditingController(text: collectorVer.mobileNumber ?? user.phone);
    _otpController = TextEditingController();

    _orgController = TextEditingController(text: collectorVer.organizationName ?? user.organizationName ?? '');
    _locationController = TextEditingController(text: collectorVer.facilityLocation ?? user.facilityLocation ?? '');
    _detailsController = TextEditingController(text: collectorVer.businessDetails ?? '');

    _selectedGovIdType = collectorVer.governmentIdType ?? 'AADHAAR';
    _govIdController = TextEditingController();
    _licenseController = TextEditingController(text: collectorVer.licenseNumber ?? user.licenseNumber ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = user.id ?? user.email;
      if (userId.isNotEmpty) {
        context.read<VerificationController>().loadCollectorVerification(userId);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _orgController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
    _govIdController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verCtrl = context.watch<VerificationController>();
    final collectorVer = verCtrl.collectorVerification;
    final isFullyVerified = collectorVer.isFullyVerified;
    final completedCount = collectorVer.completedStepsCount;

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
              const PillPageHeader(title: 'Collector Verification'),
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

              // ── Step 1: Identity Verification ──
              _buildStep1IdentityCard(context, verCtrl),
              const SizedBox(height: AppConstants.space16),

              // ── Step 2: Business Verification ──
              _buildStep2BusinessCard(context, verCtrl),
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
                      'PROFILE VERIFICATION — $count/3',
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
                          ? 'Your collector profile is fully verified & active.'
                          : 'Complete all 3 parameters to accept harvester requests.',
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
                  '$count/3',
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
              value: count / 3.0,
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
            title: 'Identity Verification',
            subtitle: 'Full name & verified mobile OTP',
            isComplete: count >= 1 && context.watch<VerificationController>().collectorVerification.isStep1IdentityComplete,
          ),
          const SizedBox(height: 8),
          _buildChecklistItem(
            context,
            title: 'Business Verification',
            subtitle: 'Organization / Center name & address',
            isComplete: count >= 2 && context.watch<VerificationController>().collectorVerification.isStep2BusinessComplete,
          ),
          const SizedBox(height: 8),
          _buildChecklistItem(
            context,
            title: 'License & KYC',
            subtitle: 'Government ID & legitimate KYC verification',
            isComplete: count == 3 && context.watch<VerificationController>().collectorVerification.isStep3KycComplete,
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
                  text: ' — $subtitle',
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

  // ── Step 1: Identity Verification ──
  Widget _buildStep1IdentityCard(BuildContext context, VerificationController verCtrl) {
    final collectorVer = verCtrl.collectorVerification;
    final isDone = collectorVer.isStep1IdentityComplete;
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
                        'Identity Verification',
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
            'Provide your full legal name and verify your mobile number with real OTP.',
            style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 16),

          if (isDone) ...[
            _buildVerifiedDataTile(context, 'Full Name', collectorVer.fullName ?? user.name),
            const SizedBox(height: 8),
            _buildVerifiedDataTile(context, 'Mobile Number', collectorVer.mobileNumber ?? user.phone),
          ] else ...[
            AppTextField(
              controller: _nameController,
              labelText: 'Full Name of Collector',
              hintText: 'Enter your full name',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _mobileController,
                    labelText: 'Mobile Number',
                    hintText: '+91 9876543210',
                    prefixIcon: Icon(Icons.phone_android_rounded, size: 20, color: context.textSecondaryColor),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: verCtrl.isLoading
                        ? null
                        : () async {
                            final mob = _mobileController.text.trim();
                            if (mob.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter mobile number')),
                              );
                              return;
                            }
                            await verCtrl.sendCollectorMobileOtp(userId, mob);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: context.colors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      verCtrl.mobileOtpSent ? 'Resend' : 'Send OTP',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            if (verCtrl.mobileOtpSent) ...[
              const SizedBox(height: 14),
              if (verCtrl.devOtp != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.primarySoftColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Text(
                    'OTP Code: ${verCtrl.devOtp}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _otpController,
                      labelText: 'Enter 6-Digit OTP',
                      hintText: '123456',
                      prefixIcon: Icon(Icons.security_rounded, size: 20, color: context.textSecondaryColor),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: verCtrl.isLoading
                          ? null
                          : () async {
                              final otp = _otpController.text.trim();
                              final name = _nameController.text.trim();
                              final mob = _mobileController.text.trim();
                              if (otp.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter OTP')),
                                );
                                return;
                              }
                              final success = await verCtrl.verifyCollectorMobileOtp(
                                collectorId: userId,
                                mobile: mob,
                                otp: otp,
                                fullName: name,
                              );
                              if (success && context.mounted) {
                                context.read<UserController>().reloadProfile();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.successColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        'Verify OTP',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Step 2: Business Verification ──
  Widget _buildStep2BusinessCard(BuildContext context, VerificationController verCtrl) {
    final collectorVer = verCtrl.collectorVerification;
    final isDone = collectorVer.isStep2BusinessComplete;
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
                        'Business Verification',
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
            'Enter your registered Organization / Collection Center name & facility address.',
            style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 16),

          if (isDone) ...[
            _buildVerifiedDataTile(context, 'Organization / Center Name', collectorVer.organizationName ?? user.organizationName ?? 'N/A'),
            const SizedBox(height: 8),
            _buildVerifiedDataTile(context, 'Facility Address', collectorVer.facilityLocation ?? user.facilityLocation ?? 'N/A'),
          ] else ...[
            AppTextField(
              controller: _orgController,
              labelText: 'Organization / Collection Center Name',
              hintText: 'e.g. Apex Apiaries Collection Center',
              prefixIcon: Icon(Icons.business_rounded, size: 20, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _locationController,
              labelText: 'Collection Center Address / Facility Location',
              hintText: 'e.g. Sector 4, Industrial Area, Solan, HP',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _detailsController,
              labelText: 'Operational Details (Optional)',
              hintText: 'e.g. Storage capacity 5000 kg, cold storage facility',
              prefixIcon: Icon(Icons.info_outline_rounded, size: 20, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: verCtrl.isLoading
                    ? null
                    : () async {
                        final org = _orgController.text.trim();
                        final loc = _locationController.text.trim();
                        final det = _detailsController.text.trim();
                        if (org.isEmpty || loc.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill in organization name and location')),
                          );
                          return;
                        }
                        final success = await verCtrl.submitCollectorBusiness(
                          collectorId: userId,
                          organizationName: org,
                          facilityLocation: loc,
                          businessDetails: det,
                        );
                        if (success && context.mounted) {
                          context.read<UserController>().reloadProfile();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Submit Business Verification',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
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
    final collectorVer = verCtrl.collectorVerification;
    final isDone = collectorVer.isStep3KycComplete;
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
                        '3',
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
                        'License & KYC',
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
            'Authenticate government-issued identity & trade license through regulatory KYC API.',
            style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 16),

          if (isDone) ...[
            _buildVerifiedDataTile(context, 'Government ID Type', collectorVer.governmentIdType ?? 'AADHAAR'),
            const SizedBox(height: 8),
            _buildVerifiedDataTile(context, 'ID Reference', collectorVer.governmentIdReference ?? 'DOC-***4821'),
            const SizedBox(height: 8),
            _buildVerifiedDataTile(context, 'Trade / FSSAI License', collectorVer.licenseNumber ?? user.licenseNumber ?? 'N/A'),
            const SizedBox(height: 8),
            _buildVerifiedDataTile(context, 'KYC Gateway', collectorVer.kycProvider ?? 'SANDBOX_KYC'),
          ] else ...[
            // Document Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedGovIdType,
              decoration: InputDecoration(
                labelText: 'Document Type',
                filled: true,
                fillColor: context.surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'AADHAAR', child: Text('Aadhaar Card (12 digits)')),
                DropdownMenuItem(value: 'PAN', child: Text('PAN Card (Business / Personal)')),
                DropdownMenuItem(value: 'PASSPORT', child: Text('Passport')),
                DropdownMenuItem(value: 'DRIVERS_LICENSE', child: Text('Driver\'s License')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedGovIdType = val);
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _govIdController,
              labelText: 'Government ID / Document Number',
              hintText: _selectedGovIdType == 'AADHAAR' ? 'Enter 12-digit Aadhaar' : 'Enter ID / Document number',
              prefixIcon: Icon(Icons.badge_outlined, size: 20, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _licenseController,
              labelText: 'Processing / Trade License Number',
              hintText: 'e.g. FSSAI-2026-98124',
              prefixIcon: Icon(Icons.verified_user_outlined, size: 20, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: verCtrl.isLoading
                    ? null
                    : () async {
                        final govNum = _govIdController.text.trim();
                        final licNum = _licenseController.text.trim();
                        if (govNum.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter Government ID number')),
                          );
                          return;
                        }
                        final success = await verCtrl.submitCollectorKyc(
                          collectorId: userId,
                          governmentIdType: _selectedGovIdType,
                          governmentIdNumber: govNum,
                          licenseNumber: licNum,
                        );
                        if (success && context.mounted) {
                          context.read<UserController>().reloadProfile();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Verify via KYC Service',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
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
        color: isVerified ? context.successBgColor : context.warningBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? context.successColor.withValues(alpha: 0.4) : context.warningColor.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isVerified ? context.successColor : context.warningColor,
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor)),
          Text(
            value,
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
          ),
        ],
      ),
    );
  }
}
