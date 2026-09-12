import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/controllers/user_controller.dart';
import '../controllers/verification_controller.dart';
import 'verification_certificate_screen.dart';

class HarvesterVerificationScreen extends StatefulWidget {
  const HarvesterVerificationScreen({super.key});

  @override
  State<HarvesterVerificationScreen> createState() => _HarvesterVerificationScreenState();
}

class _HarvesterVerificationScreenState extends State<HarvesterVerificationScreen> {
  // Step 1 Form (Aadhaar Card ONLY)
  final TextEditingController _aadhaarNumberController = TextEditingController();
  final TextEditingController _aadhaarOtpController = TextEditingController();

  // Step 2 Form
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // Step 3 Form (4 Exact Registration Authorities)
  final TextEditingController _registrationIdController = TextEditingController();
  String _selectedAuthority = 'STATE_AGRICULTURE';

  static const Map<String, String> _registrationAuthorities = {
    'STATE_AGRICULTURE': 'State Department of Agriculture',
    'NATIONAL_HONEY_PRODUCERS': 'National Honey Producers',
    'ORGANIC_CERTIFICATION_BOARD': 'Organic Certification Board',
    'OTHER_LOCAL': 'Other / Local Registration',
  };

  // Step 4 Form (Simple State, District, Village/City Location)
  String _selectedState = 'Uttar Pradesh';
  final TextEditingController _districtController = TextEditingController(text: 'Gautam Buddh Nagar');
  final TextEditingController _villageCityController = TextEditingController(text: 'Greater Noida');
  final TextEditingController _apiaryNameController = TextEditingController();
  final TextEditingController _coordinatesController = TextEditingController();

  static const List<String> _indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Jammu & Kashmir',
    'Ladakh',
    'Other / Outside India',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserController>().user;
      final harvesterId = (user.id != null && user.id!.isNotEmpty)
          ? user.id!
          : (user.beekeeperId ?? 'harvester');
      context.read<VerificationController>().loadVerification(harvesterId);
      if (user.phone.isNotEmpty) {
        String digits = user.phone.replaceAll(RegExp(r'\D'), '');
        if (digits.startsWith('91') && digits.length > 10) {
          digits = digits.substring(2);
        }
        if (digits.length == 10) {
          _phoneController.text = '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
        } else {
          _phoneController.text = user.phone;
        }
      }
      if (user.organizationName != null && user.organizationName!.isNotEmpty) {
        _apiaryNameController.text = user.organizationName!;
      }
      if (user.facilityLocation != null && user.facilityLocation!.isNotEmpty) {
        final parts = user.facilityLocation!.split(',').map((p) => p.trim()).toList();
        if (parts.length >= 3) {
          _villageCityController.text = parts[0];
          _districtController.text = parts[1];
          if (_indianStates.contains(parts[2])) {
            _selectedState = parts[2];
          }
        } else if (parts.length == 2) {
          _villageCityController.text = parts[0];
          if (_indianStates.contains(parts[1])) {
            _selectedState = parts[1];
          } else {
            _districtController.text = parts[1];
          }
        } else {
          _villageCityController.text = user.facilityLocation!;
        }
      }
    });
  }

  @override
  void dispose() {
    _aadhaarNumberController.dispose();
    _aadhaarOtpController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _registrationIdController.dispose();
    _districtController.dispose();
    _villageCityController.dispose();
    _apiaryNameController.dispose();
    _coordinatesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verCtrl = context.watch<VerificationController>();
    final ver = verCtrl.verification;
    final progress = ver.completedStepsCount / 5.0;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _PillBackButton(onTap: () => Navigator.pop(context)),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Harvester Verification',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.textPrimaryColor,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '5-Parameter Trust & Provenance Protocol',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.textSecondaryColor),
            tooltip: 'Refresh Verification Status',
            onPressed: () {
              final user = context.read<UserController>().user;
              final harvesterId = (user.id != null && user.id!.isNotEmpty)
                  ? user.id!
                  : (user.beekeeperId ?? 'harvester');
              verCtrl.loadVerification(harvesterId);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppConstants.space12),

              // Progress Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.space20),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Verification Progress',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ver.isFullyVerified ? context.successBgColor : context.primarySoftColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            ver.isFullyVerified
                                ? 'Verified ✓'
                                : '${ver.completedStepsCount} of 5 Completed',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ver.isFullyVerified ? context.successColor : context.primaryDarkColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: context.borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ver.isFullyVerified ? context.successColor : context.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Banners
              if (verCtrl.errorMessage != null) ...[
                const SizedBox(height: AppConstants.space12),
                _AlertBanner(
                  message: verCtrl.errorMessage!,
                  isError: true,
                  onDismiss: verCtrl.clearMessages,
                ),
              ],
              if (verCtrl.successMessage != null) ...[
                const SizedBox(height: AppConstants.space12),
                _AlertBanner(
                  message: verCtrl.successMessage!,
                  isError: false,
                  onDismiss: verCtrl.clearMessages,
                ),
              ],

              const SizedBox(height: AppConstants.space20),

              // ── STEP 1: Government ID Verification (Aadhaar Card ONLY) ──
              _buildStepCard(
                stepNumber: 1,
                title: 'Government ID Verification',
                subtitle: 'Aadhaar Card · Privacy-Preserving UIDAI OTP Protocol',
                icon: Icons.badge_outlined,
                isCompleted: ver.isStep1Complete,
                statusText: ver.governmentIdVerified == 'Verified' ? 'Aadhaar Verified ✓' : ver.governmentIdVerified,
                content: ver.isStep1Complete
                    ? _buildVerifiedStepInfo(
                        label: 'Masked Aadhaar Reference',
                        value: ver.governmentIdReference ?? 'AADHAAR-***XXXX',
                        subtext: 'Tamper-Evident SHA-256 Hash Stored Off-Chain',
                        verifiedBadgeText: 'Aadhaar Verified ✓',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Aadhaar Card Number',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.primarySoftColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '12-Digit UIDAI',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.primaryDarkColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _aadhaarNumberController,
                            keyboardType: TextInputType.number,
                            maxLength: 14,
                            enabled: !verCtrl.aadhaarOtpSent && !verCtrl.isLoading,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                              _AadhaarNumberFormatter(),
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'XXXX  XXXX  XXXX',
                              prefixIcon: Icon(Icons.fingerprint_rounded, size: 20, color: context.textSecondaryColor),
                              hintStyle: GoogleFonts.inter(
                                color: context.textMutedColor,
                                letterSpacing: 2.0,
                              ),
                              filled: true,
                              fillColor: context.scaffoldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.primaryColor, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          if (!verCtrl.aadhaarOtpSent) ...[
                            const SizedBox(height: 12),
                            _ActionButton(
                              label: 'Get Aadhaar OTP',
                              icon: Icons.send_rounded,
                              isLoading: verCtrl.isLoading,
                              onTap: () {
                                final raw = _aadhaarNumberController.text.replaceAll(' ', '').trim();
                                if (raw.length != 12 || !RegExp(r'^\d{12}$').hasMatch(raw)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid 12-digit Aadhaar number.')),
                                  );
                                  return;
                                }
                                verCtrl.sendAadhaarOtp(raw);
                              },
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            // OTP Sent Info Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.primarySoftColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: context.primaryColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.mark_email_read_outlined, size: 20, color: context.primaryDarkColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'OTP sent to your Aadhaar-linked mobile number.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.textPrimaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '6-Digit Aadhaar OTP',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimaryColor,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: verCtrl.isLoading ? null : () => verCtrl.resetAadhaarState(),
                                  child: Text(
                                    'Change Number',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.primaryDarkColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _aadhaarOtpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    autofocus: true,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: 'Enter 6-digit OTP',
                                      prefixIcon: Icon(Icons.shield_outlined, size: 20, color: context.textSecondaryColor),
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
                                  onPressed: verCtrl.canResendAadhaarOtp && !verCtrl.isLoading
                                      ? () {
                                          final raw = _aadhaarNumberController.text.replaceAll(' ', '').trim();
                                          verCtrl.sendAadhaarOtp(raw);
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.primarySoftColor,
                                    foregroundColor: context.primaryDarkColor,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text(
                                    verCtrl.aadhaarCooldown > 0 ? '${verCtrl.aadhaarCooldown}s' : 'Resend',
                                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _ActionButton(
                              label: 'Verify Aadhaar OTP',
                              icon: Icons.check_circle_outline_rounded,
                              isLoading: verCtrl.isLoading,
                              onTap: () {
                                final code = _aadhaarOtpController.text.trim();
                                if (code.length != 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter the complete 6-digit Aadhaar OTP.')),
                                  );
                                  return;
                                }
                                verCtrl.verifyAadhaarOtp(code);
                              },
                            ),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: AppConstants.space16),

              // ── STEP 2: Mobile Number + OTP ──
              _buildStepCard(
                stepNumber: 2,
                title: 'Mobile Number Verification',
                subtitle: '2Factor SMS Gateway · India DLT Compliant OTP',
                icon: Icons.phone_android_rounded,
                isCompleted: ver.isStep2Complete,
                statusText: ver.mobileVerified == 'Verified' ? 'Mobile Verified ✓' : ver.mobileVerified,
                content: ver.isStep2Complete
                    ? _buildVerifiedStepInfo(
                        label: 'Verified Phone Number',
                        value: ver.mobileNumber ?? '+91 XXXXX XXXXX',
                        subtext: 'Mobile identity confirmed with 2FA OTP Gateway',
                        verifiedBadgeText: 'Mobile Number — Verified ✓',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mobile Number',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.primarySoftColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+91 India Mobile',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.primaryDarkColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 15,
                            enabled: !verCtrl.mobileOtpSent && !verCtrl.isLoading,
                            inputFormatters: [
                              _IndianPhoneNumberFormatter(),
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '+91 XXXXX XXXXX',
                              prefixIcon: Icon(Icons.phone_outlined, size: 20, color: context.textSecondaryColor),
                              hintStyle: GoogleFonts.inter(color: context.textMutedColor),
                              filled: true,
                              fillColor: context.scaffoldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.primaryColor, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          if (!verCtrl.mobileOtpSent) ...[
                            const SizedBox(height: 12),
                            _ActionButton(
                              label: 'Send OTP',
                              icon: Icons.send_rounded,
                              isLoading: verCtrl.isLoading,
                              onTap: () {
                                final phone = _phoneController.text.trim();
                                final digits = phone.replaceAll(RegExp(r'\D'), '');
                                if (digits.length < 10) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid 10-digit mobile number.')),
                                  );
                                  return;
                                }
                                verCtrl.sendMobileOtp(phone);
                              },
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            // OTP Sent Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.primarySoftColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: context.primaryColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.sms_outlined, size: 20, color: context.primaryDarkColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'OTP sent to ${verCtrl.pendingMobileNumber}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.textPrimaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Enter OTP',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                                ),
                                GestureDetector(
                                  onTap: verCtrl.isLoading ? null : () => verCtrl.resetMobileOtpState(),
                                  child: Text(
                                    'Change Number',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.primaryDarkColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    autofocus: true,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: '_ _ _ _ _ _',
                                      prefixIcon: Icon(Icons.pin_outlined, size: 20, color: context.textSecondaryColor),
                                      hintStyle: GoogleFonts.inter(color: context.textMutedColor, letterSpacing: 3.0),
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
                                  onPressed: verCtrl.canResendOtp && !verCtrl.isLoading
                                      ? () {
                                          final phone = _phoneController.text.trim();
                                          verCtrl.sendMobileOtp(phone);
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.primarySoftColor,
                                    foregroundColor: context.primaryDarkColor,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text(
                                    verCtrl.otpCooldown > 0 ? '${verCtrl.otpCooldown}s' : 'Resend OTP',
                                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                              _ActionButton(
                                label: 'Verify OTP',
                                icon: Icons.verified_user_outlined,
                                isLoading: verCtrl.isLoading,
                                onTap: () async {
                                  final code = _otpController.text.trim();
                                  if (code.length != 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter 6-digit OTP.')),
                                    );
                                    return;
                                  }
                                  final ok = await verCtrl.verifyMobileOtp(code);
                                  if (ok && context.mounted) {
                                    final userCtrl = context.read<UserController>();
                                    userCtrl.reloadProfile();
                                  }
                                },
                              ),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: AppConstants.space16),

              // ── STEP 3: Beekeeper Registration ──
              _buildStepCard(
                stepNumber: 3,
                title: 'Beekeeper Registration',
                subtitle: 'Authority Accreditation & HoneyChain Beekeeper ID',
                icon: Icons.workspace_premium_outlined,
                isCompleted: ver.isStep3Complete,
                statusText: ver.step3DisplayStatus,
                content: ver.isStep3Complete
                    ? _buildVerifiedStepInfo(
                        label: 'Registration ID',
                        value: ver.registrationId ?? 'Verified',
                        subtext: 'Authority: ${_registrationAuthorities[ver.registrationType] ?? ver.registrationType ?? 'State Agriculture'}',
                        verifiedBadgeText: 'Beekeeper Registration — Verified ✓',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Unique HoneyChain Beekeeper ID Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.primarySoftColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: context.primaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.badge_outlined, size: 20, color: context.primaryDarkColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'HoneyChain Beekeeper ID',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: context.textSecondaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.watch<UserController>().user.beekeeperId ?? 'HC-BK-PENDING',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: context.textPrimaryColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'HoneyChain internal ID (distinct from external authority ID)',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: context.textMutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Manual Verification Alert if previously submitted with manual authority
                          if (ver.isStep3ManualReview) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Verification unavailable — manual verification required.',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Registration ID "${ver.registrationId}" with ${_registrationAuthorities[ver.registrationType] ?? ver.registrationType} has been submitted for manual authority review.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: context.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Registration Authority Selection (Exactly 4 Options)
                          Text(
                            'Registration Authority',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: context.scaffoldBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedAuthority,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondaryColor),
                                dropdownColor: context.surfaceColor,
                                items: _registrationAuthorities.entries.map((entry) {
                                  return DropdownMenuItem<String>(
                                    value: entry.key,
                                    child: Text(
                                      entry.value,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedAuthority = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Registration ID input
                          Text(
                            'Registration ID',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _registrationIdController,
                            decoration: InputDecoration(
                              hintText: 'Enter your registration ID',
                              hintStyle: GoogleFonts.inter(color: context.textMutedColor),
                              prefixIcon: Icon(Icons.badge_outlined, size: 20, color: context.textSecondaryColor),
                              filled: true,
                              fillColor: context.scaffoldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.primaryColor, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ActionButton(
                            label: 'Verify Registration',
                            icon: Icons.verified_outlined,
                            isLoading: verCtrl.isLoading,
                            onTap: () {
                              final id = _registrationIdController.text.trim();
                              if (id.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter registration ID.')));
                                return;
                              }
                              verCtrl.submitRegistrationId(registrationId: id, registrationType: _selectedAuthority);
                            },
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: AppConstants.space16),

              // ── STEP 4: Location (State, District, Village/City) ──
              _buildStepCard(
                stepNumber: 4,
                title: 'Location',
                subtitle: 'State, District & Village / City Registry',
                icon: Icons.pin_drop_outlined,
                isCompleted: ver.isStep4Complete,
                statusText: ver.locationVerified == 'Verified' ? 'Location — Completed ✓' : ver.locationVerified,
                content: ver.isStep4Complete
                    ? _buildVerifiedStepInfo(
                        label: 'Location',
                        value: ver.apiaryLocation ?? 'Registered Apiary',
                        subtext: 'State, District & Village registry confirmed',
                        verifiedBadgeText: 'Location — Completed ✓',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // State Dropdown
                          Text(
                            'State',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: context.scaffoldBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _indianStates.contains(_selectedState) ? _selectedState : _indianStates.first,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondaryColor),
                                dropdownColor: context.surfaceColor,
                                items: _indianStates.map((state) {
                                  return DropdownMenuItem<String>(
                                    value: state,
                                    child: Text(
                                      state,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedState = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // District Input
                          Text(
                            'District',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _districtController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Gautam Buddh Nagar',
                              hintStyle: GoogleFonts.inter(color: context.textMutedColor),
                              prefixIcon: Icon(Icons.location_city_outlined, size: 20, color: context.textSecondaryColor),
                              filled: true,
                              fillColor: context.scaffoldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.primaryColor, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Village / City Input
                          Text(
                            'Village / City',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _villageCityController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Greater Noida',
                              hintStyle: GoogleFonts.inter(color: context.textMutedColor),
                              prefixIcon: Icon(Icons.home_work_outlined, size: 20, color: context.textSecondaryColor),
                              filled: true,
                              fillColor: context.scaffoldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.primaryColor, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Apiary / Farm Name (Optional)
                          Text(
                            'Apiary / Farm Name (Optional)',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _apiaryNameController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Primary Apiary',
                              hintStyle: GoogleFonts.inter(color: context.textMutedColor),
                              prefixIcon: Icon(Icons.hive_outlined, size: 20, color: context.textSecondaryColor),
                              filled: true,
                              fillColor: context.scaffoldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.primaryColor, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Optional GPS Coordinates
                          Text(
                            'Private GPS Coordinates (Optional)',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _coordinatesController,
                            decoration: InputDecoration(
                              hintText: 'e.g. 28.4744, 77.5040 (Optional)',
                              hintStyle: GoogleFonts.inter(color: context.textMutedColor),
                              prefixIcon: Icon(Icons.gps_fixed_rounded, size: 20, color: context.textSecondaryColor),
                              filled: true,
                              fillColor: context.scaffoldBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.primaryColor, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ActionButton(
                            label: 'Save & Complete Location',
                            icon: Icons.location_on_outlined,
                            isLoading: verCtrl.isLoading,
                            onTap: () {
                              final village = _villageCityController.text.trim();
                              final district = _districtController.text.trim();
                              final state = _selectedState;
                              if (village.isEmpty && district.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter village/city or district.')));
                                return;
                              }
                              final formattedLoc = [village, district, state]
                                  .where((s) => s.isNotEmpty)
                                  .join(', ');
                              final name = _apiaryNameController.text.trim().isNotEmpty
                                  ? _apiaryNameController.text.trim()
                                  : 'Primary Apiary';
                              verCtrl.submitApiaryLocation(
                                apiaryName: name,
                                apiaryLocation: formattedLoc,
                                apiaryCoordinates: _coordinatesController.text.trim(),
                              );
                            },
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: AppConstants.space16),

              // ── STEP 5: Blockchain Verification Record ──
              _buildStepCard(
                stepNumber: 5,
                title: 'Blockchain Verification ID',
                subtitle: 'Tamper-Evident Provenance Ledger Record',
                icon: Icons.link_rounded,
                isCompleted: ver.isFullyVerified,
                statusText: ver.isFullyVerified ? 'Verified' : ver.canSubmitBlockchain ? 'Ready' : 'Locked',
                content: ver.isFullyVerified
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVerifiedStepInfo(
                            label: 'Harvester Verification ID',
                            value: ver.verificationId ?? 'Pending Sync',
                            subtext: 'Network: ${ver.blockchainNetwork ?? 'HoneyChain Provenance Ledger'}',
                          ),
                          const SizedBox(height: 14),
                          _ActionButton(
                            label: 'View Verification Certificate & QR',
                            icon: Icons.qr_code_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const VerificationCertificateScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ver.canSubmitBlockchain
                                ? 'All 4 verification checks passed! You can now commit this harvester profile to the HoneyChain provenance blockchain ledger.'
                                : 'Complete Steps 1-4 above to unlock on-chain blockchain verification and generate your Harvester Verification ID.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.textSecondaryColor,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ActionButton(
                            label: 'Record on Blockchain Ledger',
                            icon: Icons.lock_outline_rounded,
                            disabled: !ver.canSubmitBlockchain,
                            isLoading: verCtrl.isLoading,
                            onTap: () {
                              verCtrl.submitBlockchainVerification();
                            },
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required String statusText,
    required Widget content,
  }) {
    final statusColor = isCompleted
        ? context.successColor
        : statusText == 'Ready'
            ? context.primaryColor
            : context.textMutedColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCompleted ? context.successColor.withValues(alpha: 0.35) : context.borderColor,
          width: isCompleted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCompleted ? context.successBgColor : context.primarySoftColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check_rounded, size: 20, color: context.successColor)
                      : Text(
                          '$stepNumber',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.primaryDarkColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppConstants.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: context.textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space16),
          Divider(height: 1, color: context.borderColor),
          const SizedBox(height: AppConstants.space16),
          content,
        ],
      ),
    );
  }

  Widget _buildVerifiedStepInfo({
    required String label,
    required String value,
    required String subtext,
    String? verifiedBadgeText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.successBgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.successColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondaryColor,
                ),
              ),
              if (verifiedBadgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.successBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.successColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    verifiedBadgeText,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.successColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 14, color: context.successColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subtext,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: context.successColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AadhaarNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 12) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _IndianPhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length > 10) {
      digits = digits.substring(2);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final buffer = StringBuffer();
    buffer.write('+91 ');
    for (int i = 0; i < digits.length; i++) {
      if (i == 5) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;
  final bool isLoading;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.disabled = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: disabled || isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.primary,
          foregroundColor: context.colors.onPrimary,
          disabledBackgroundColor: context.textMutedColor.withValues(alpha: 0.2),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _AlertBanner({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isError ? AppConstants.error.withValues(alpha: 0.1) : context.successBgColor;
    final fg = isError ? AppConstants.error : context.successColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: fg, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 13, color: fg, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, color: fg, size: 18),
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
