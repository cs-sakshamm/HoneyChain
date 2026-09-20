import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/localization_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/bee_loader.dart';
import '../../core/widgets/feedback_banner.dart';
import 'auth_controller.dart';
import 'widgets/google_logo_icon.dart';
import 'widgets/phone_field.dart';

/// HoneyChain Phone OTP authentication.
///
/// Stage 1: pick a country, enter mobile number → Firebase sends the SMS code.
/// Stage 2: enter the 6-digit code → Firebase verifies → HoneyChain session.
///
/// The old email/password flow was removed entirely; this is the single
/// authentication path (Google sign-in remains as the secondary provider).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpFocusNode = FocusNode();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  CountryInfo _selectedCountry = kDefaultCountry;

  @override
  void initState() {
    super.initState();
    // Recompute the live E.164 preview on every keystroke; listening directly
    // to the controller (instead of only onChanged callbacks) keeps the
    // preview correct even when text changes programmatically (e.g. paste).
    _phoneController.addListener(_handlePhoneChanged);
  }

  Timer? _resendTimer;
  int _resendCountdown = 0;

  void _handlePhoneChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneController.removeListener(_handlePhoneChanged);
    _phoneController.dispose();
    _otpFocusNode.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown -= 1;
        if (_resendCountdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _handleSendOtp(AuthController controller) async {
    await controller.requestOtp(
      _phoneController.text,
      null,
      _selectedCountry,
    );
    if (!mounted) return;
    if (controller.status == AuthStateStatus.codeSent) {
      _startResendCountdown();
    }
  }

  Future<void> _handleVerifyOtp(AuthController controller) async {
    final code = _otpControllers.map((c) => c.text.trim()).join();
    await controller.verifyOtp(code);
    if (mounted &&
        controller.status != AuthStateStatus.authenticated &&
        controller.status != AuthStateStatus.error) {
      _otpFocusNode.requestFocus();
    }
  }

  void _handleBackToPhone(AuthController controller) {
    _resendTimer?.cancel();
    for (final c in _otpControllers) {
      c.clear();
    }
    controller.switchMode(AuthMode.phoneEntry);
  }

  String _getRoleTitle(BuildContext context, UserRole? role) {
    switch (role) {
      case UserRole.harvester:
        return context.tr('harvester_login');
      case UserRole.collectionProcessing:
        return context.tr('collection_login');
      case UserRole.labTesting:
        return context.tr('lab_login');
      case UserRole.packaging:
        return context.tr('packaging_login');
      default:
        return 'Sign in to HoneyChain';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final isBusy = controller.status == AuthStateStatus.authenticating;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 840;

            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? AppConstants.space24 : AppConstants.space20,
                      vertical: AppConstants.space32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: AppLogo(size: 36, showWordmark: true)),
                          const SizedBox(height: AppConstants.space32),
                          _buildAuthCard(context, controller, isBusy),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Left Back Button
                Positioned(
                  top: 16,
                  left: 20,
                  child: InkWell(
                    onTap: () {
                      if (controller.mode == AuthMode.otpEntry) {
                        _handleBackToPhone(controller);
                      } else {
                        controller.clearRole();
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 16, color: context.textSecondaryColor),
                          const SizedBox(width: 6),
                          Text(
                            controller.mode == AuthMode.otpEntry
                                ? 'Change number'
                                : context.tr('back_to_roles'),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Right Compact Language Switcher
                Positioned(
                  top: 16,
                  right: 20,
                  child: Consumer<LanguageController>(
                    builder: (context, langCtrl, _) {
                      return InkWell(
                        onTap: () => _showLanguagePickerModal(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.language_rounded, size: 16, color: context.textSecondaryColor),
                              const SizedBox(width: 6),
                              Text(
                                langCtrl.currentLanguage.nativeName,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context, AuthController controller, bool isBusy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.status == AuthStateStatus.error && controller.errorMessage != null) ...[
          FeedbackBanner(
            message: controller.errorMessage!,
            type: FeedbackBannerType.error,
            onClose: () => controller.resetError(),
          ),
          const SizedBox(height: AppConstants.space16),
        ],
        if (controller.infoMessage != null &&
            controller.mode == AuthMode.otpEntry &&
            controller.status != AuthStateStatus.error) ...[
          FeedbackBanner(
            message: controller.infoMessage!,
            type: FeedbackBannerType.info,
          ),
          const SizedBox(height: AppConstants.space16),
        ],

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: controller.mode == AuthMode.phoneEntry
              ? _buildPhoneEntry(context, controller, isBusy)
              : _buildOtpEntry(context, controller, isBusy),
        ),
      ],
    );
  }

  // ── Stage 1: Phone number entry ──
  Widget _buildPhoneEntry(BuildContext context, AuthController controller, bool isBusy) {
    final normalized =
        normalizePhoneForCountry(_phoneController.text, _selectedCountry);

    return Column(
      key: const ValueKey('phone-entry'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _getRoleTitle(context, controller.selectedRole),
          style: GoogleFonts.manrope(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: context.textPrimaryColor,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: AppConstants.space6),
        Text(
          'Enter your mobile number and we will send you a verification code.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space28),

        // Country selector + number field: one fused, perfectly aligned row.
        PhoneField(
          controller: _phoneController,
          country: _selectedCountry,
          enabled: !isBusy && !controller.isRequestingOtp,
          onCountryChanged: (country) => setState(() => _selectedCountry = country),
          onSubmitted: (_) => _handleSendOtp(controller),
        ),

        // Live E.164 preview so the user sees exactly what will be verified.
        // Sits on its own line so the row above never reflows or jumps.
        const SizedBox(height: AppConstants.space6),
        Text(
          normalized.e164,
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: normalized.isValid
                ? context.textMutedColor
                : context.errorColor,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppButton(
          text: 'Send OTP',
          isLoading: isBusy,
          onPressed: () => _handleSendOtp(controller),
        ),

        const SizedBox(height: AppConstants.space24),

        // Clean OR Divider
        Row(
          children: [
            Expanded(child: Divider(color: context.borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16),
              child: Text(
                AppConstants.orDividerText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textMutedColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(child: Divider(color: context.borderColor)),
          ],
        ),

        const SizedBox(height: AppConstants.space16),

        // Google option (existing provider, preserved)
        OutlinedButton(
          onPressed: isBusy ? null : () => controller.signInWithGoogle(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
            side: BorderSide(color: context.borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            ),
            backgroundColor: context.surfaceColor,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GoogleLogoIcon(size: 18),
              const SizedBox(width: AppConstants.space12),
              Text(
                AppConstants.continueWithGoogleText,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.space32),

        Text(
          AppConstants.legalDisclaimer,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: context.textMutedColor,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Stage 2: OTP entry ──
  Widget _buildOtpEntry(BuildContext context, AuthController controller, bool isBusy) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      key: const ValueKey('otp-entry'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter verification code',
          style: GoogleFonts.manrope(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: context.textPrimaryColor,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: AppConstants.space6),
        Text(
          'Sent to ${controller.pendingPhone}. Never share this code.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space28),

        // 6 OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 6; i++) _buildOtpBox(context, i, isBusy, isDark),
          ],
        ),

        const SizedBox(height: AppConstants.space24),

        AppButton(
          text: 'Verify & Continue',
          isLoading: isBusy,
          onPressed: () => _handleVerifyOtp(controller),
        ),

        const SizedBox(height: AppConstants.space20),

        // Resend with countdown; the controller's re-entrancy guard
        // additionally blocks overlapping send requests.
        Center(
          child: _resendCountdown > 0
              ? Text(
                  'Resend code in ${_resendCountdown}s',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textMutedColor,
                  ),
                )
              : TextButton.icon(
                  onPressed: isBusy ? null : () => _handleSendOtp(controller),
                  icon: Icon(Icons.refresh_rounded, size: 18, color: context.honeyAccent),
                  label: Text(
                    'Resend OTP',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.honeyAccent,
                    ),
                  ),
                ),
        ),

        const SizedBox(height: AppConstants.space12),

        // Inline bee loader while verifying
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isBusy
              ? const BeeTopLoader(height: 36)
              : const SizedBox.shrink(key: ValueKey('no-loader')),
        ),
      ],
    );
  }

  Widget _buildOtpBox(BuildContext context, int index, bool isBusy, bool isDark) {
    return SizedBox(
      width: 46,
      height: 54,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: index == 0 ? _otpFocusNode : null,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enabled: !isBusy,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: context.textPrimaryColor,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: context.surfaceColor,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            borderSide: BorderSide(color: context.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            borderSide: BorderSide(color: context.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            borderSide: const BorderSide(color: AppConstants.honeyAccent, width: 1.5),
          ),
        ),
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
            FocusScope.of(context).nextFocus();
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).previousFocus();
          }
          // Auto-verify as soon as the 6th digit lands.
          if (index == 5 && value.isNotEmpty && !isBusy) {
            final code = _otpControllers.map((c) => c.text.trim()).join();
            if (code.length == 6) {
              _handleVerifyOtp(context.read<AuthController>());
            }
          }
        },
      ),
    );
  }

  // ── Language Picker Bottom Sheet (existing pattern) ──
  void _showLanguagePickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.borderRadiusLarge)),
      ),
      builder: (modalContext) {
        return Consumer<LanguageController>(
          builder: (ctx, langCtrl, _) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.75,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppConstants.space16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppConstants.space16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.space24),
                    child: Row(
                      children: [
                        Icon(Icons.language_rounded, size: 20, color: context.honeyAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Select language',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.space12),
                  Divider(height: 1, color: context.borderColor),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: LanguageController.supportedLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = LanguageController.supportedLanguages[index];
                        final isSelected = lang.code == langCtrl.currentLanguageCode;

                        return Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            title: Text(
                              lang.name,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? context.honeyAccent : context.textPrimaryColor,
                              ),
                            ),
                            subtitle: Text(
                              lang.nativeName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: context.textSecondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_rounded, color: context.honeyAccent, size: 20)
                                : null,
                            onTap: () {
                              langCtrl.setLanguage(lang.code);
                              Navigator.pop(modalContext);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
