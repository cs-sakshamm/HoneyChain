import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/localization_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_banner.dart';
import '../../core/widgets/social_icon_button.dart';
import 'auth_controller.dart';
import 'widgets/google_logo_icon.dart';

/// Production-Grade Responsive Login Screen for HoneyChain
/// Supports Desktop Split Layout & Mobile Layout with clean SaaS design principles
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginEmailOrPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regBusinessNameController = TextEditingController();
  final _regEmailOrPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();

  final _phoneInputController = TextEditingController();
  final _otpCodeController = TextEditingController();
  final _resetIdentifierController = TextEditingController();
  final _languageSearchController = TextEditingController();

  @override
  void dispose() {
    _loginEmailOrPhoneController.dispose();
    _loginPasswordController.dispose();
    _regBusinessNameController.dispose();
    _regEmailOrPhoneController.dispose();
    _regPasswordController.dispose();
    _phoneInputController.dispose();
    _otpCodeController.dispose();
    _resetIdentifierController.dispose();
    _languageSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 768;

            return Stack(
              children: [
                if (isDesktop)
                  _buildDesktopLayout(context, controller)
                else
                  _buildMobileLayout(context, controller),

                // Top Right Small Language Selector [ EN ]
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
                              Icon(Icons.arrow_drop_down_rounded, size: 18, color: context.textSecondaryColor),
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

  // ---------------------------------------------------------------------------
  // DESKTOP SPLIT LAYOUT (Left Side Branding + Right Side Auth Card)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(BuildContext context, AuthController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leftBg = isDark ? const Color(0xFF161E2E) : context.primarySoftColor.withValues(alpha: 0.4);

    return Row(
      children: [
        // Left Column: Tasteful Product Branding
        Expanded(
          flex: 5,
          child: Container(
            color: leftBg,
            padding: const EdgeInsets.all(AppConstants.space48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AppLogo(
                  size: 32,
                  showWordmark: true,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operational supply chain & field intelligence simplified.',
                        style: GoogleFonts.manrope(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimaryColor,
                          letterSpacing: -0.8,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space16),
                      Text(
                        'Manage field operations, track harvest metrics, and unify yield logistics in one calm, production-ready platform.',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: context.textSecondaryColor,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space32),
                      _buildFeatureBadge(context, Icons.analytics_outlined, 'Real-time Field Operations Tracking'),
                      const SizedBox(height: 12),
                      _buildFeatureBadge(context, Icons.translate_rounded, 'Multi-Language Support (22 Indian Languages)'),
                      const SizedBox(height: 12),
                      _buildFeatureBadge(context, Icons.security_rounded, 'Secure Enterprise Session Security'),
                    ],
                  ),
                ),
                Text(
                  'HoneyChain Operations Platform • v1.0',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.textMutedColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Column: Focused Auth Card
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.space48,
                vertical: AppConstants.space32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAuthContent(context, controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureBadge(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.borderColor),
          ),
          child: Icon(icon, size: 16, color: context.primaryDarkColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textPrimaryColor,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE SINGLE-COLUMN LAYOUT
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(BuildContext context, AuthController controller) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.space24,
          vertical: AppConstants.space32,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppConstants.space16),
              const Center(
                child: AppLogo(
                  size: 36,
                  showWordmark: true,
                ),
              ),
              const SizedBox(height: AppConstants.space32),
              _buildAuthContent(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED AUTH CONTENT ROUTER
  // ---------------------------------------------------------------------------
  Widget _buildAuthContent(BuildContext context, AuthController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Feedback Banners (Inline Error / Info Alerts)
        if (controller.status == AuthStateStatus.error && controller.errorMessage != null) ...[
          FeedbackBanner(
            message: controller.errorMessage!,
            type: FeedbackBannerType.error,
            onClose: () => controller.resetError(),
          ),
          const SizedBox(height: AppConstants.space16),
        ],

        if (controller.infoMessage != null) ...[
          FeedbackBanner(
            message: controller.infoMessage!,
            type: FeedbackBannerType.info,
          ),
          const SizedBox(height: AppConstants.space16),
        ],

        // Active Mode Form
        switch (controller.mode) {
          AuthMode.login => _buildLoginForm(context, controller),
          AuthMode.register => _buildRegisterForm(context, controller),
          AuthMode.phoneOtp => _buildPhoneOtpForm(context, controller),
          AuthMode.forgotPassword => _buildForgotPasswordForm(context, controller),
        },

        const SizedBox(height: AppConstants.space32),

        // Legal Terms Footer
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

  // ---------------------------------------------------------------------------
  // 1. Production Login Form
  // ---------------------------------------------------------------------------
  Widget _buildLoginForm(BuildContext context, AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('welcome_back'),
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        Text(
          context.tr('sign_in_sub'),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        // Email or Phone Field
        AppTextField(
          controller: _loginEmailOrPhoneController,
          labelText: context.tr('email_or_phone'),
          hintText: AppConstants.emailOrPhoneHint,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space16),

        // Password Field
        AppTextField(
          controller: _loginPasswordController,
          labelText: context.tr('password'),
          hintText: AppConstants.passwordHint,
          obscureText: !controller.isPasswordVisible,
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: context.textSecondaryColor,
          ),
          suffixIcon: GestureDetector(
            onTap: () => controller.togglePasswordVisibility(),
            child: Icon(
              controller.isPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: context.textSecondaryColor,
            ),
          ),
        ),

        const SizedBox(height: AppConstants.space8),

        // Forgot Password Action Link
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            text: context.tr('forgot_password'),
            variant: AppButtonVariant.text,
            onPressed: () => controller.switchMode(AuthMode.forgotPassword),
          ),
        ),

        const SizedBox(height: AppConstants.space16),

        // Log In Primary Action
        AppButton(
          text: context.tr('login'),
          isLoading: isLoading,
          onPressed: () => controller.loginWithEmailOrPhone(
            _loginEmailOrPhoneController.text,
            _loginPasswordController.text,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: context.borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.space12),
              child: Text(
                context.tr('or'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.textMutedColor,
                ),
              ),
            ),
            Expanded(child: Divider(color: context.borderColor)),
          ],
        ),

        const SizedBox(height: AppConstants.space24),

        // Provider Options Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SocialIconButton(
              icon: const GoogleLogoIcon(size: 20),
              tooltip: context.tr('google_sign_in'),
              isLoading: isLoading,
              onPressed: () => controller.signInWithGoogle(),
            ),
            const SizedBox(width: AppConstants.space16),
            SocialIconButton(
              icon: Icon(Icons.apple, size: 22, color: isDark ? Colors.white : Colors.black),
              tooltip: context.tr('apple_sign_in'),
              isLoading: isLoading,
              onPressed: () => controller.signInWithApple(),
            ),
            const SizedBox(width: AppConstants.space16),
            SocialIconButton(
              icon: Icon(Icons.smartphone_rounded,
                  size: 20, color: context.textPrimaryColor),
              tooltip: context.tr('phone_sign_in'),
              isLoading: isLoading,
              onPressed: () => _showPhoneInputDialog(context, controller),
            ),
          ],
        ),

        const SizedBox(height: AppConstants.space28),

        // Switch to Create Business Account
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.tr('dont_have_account'),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => controller.switchMode(AuthMode.register),
              child: Text(
                context.tr('create_account'),
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.primaryDarkColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Business Account Registration View
  // ---------------------------------------------------------------------------
  Widget _buildRegisterForm(BuildContext context, AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('create_business_account'),
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        Text(
          context.tr('get_started_sub'),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppTextField(
          controller: _regBusinessNameController,
          labelText: context.tr('legal_business_name'),
          hintText: AppConstants.businessNameHint,
          prefixIcon: Icon(
            Icons.domain_rounded,
            size: 18,
            color: context.textSecondaryColor,
          ),
        ),
        const SizedBox(height: AppConstants.space16),

        AppTextField(
          controller: _regEmailOrPhoneController,
          labelText: context.tr('email_or_phone'),
          hintText: AppConstants.emailOrPhoneHint,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: context.textSecondaryColor,
          ),
        ),
        const SizedBox(height: AppConstants.space16),

        AppTextField(
          controller: _regPasswordController,
          labelText: context.tr('password'),
          hintText: AppConstants.passwordHint,
          obscureText: !controller.isPasswordVisible,
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: context.textSecondaryColor,
          ),
          suffixIcon: GestureDetector(
            onTap: () => controller.togglePasswordVisibility(),
            child: Icon(
              controller.isPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: context.textSecondaryColor,
            ),
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppButton(
          text: context.tr('create_account'),
          isLoading: isLoading,
          onPressed: () => controller.registerBusinessAccount(
            businessName: _regBusinessNameController.text,
            emailOrPhone: _regEmailOrPhoneController.text,
            password: _regPasswordController.text,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        Center(
          child: GestureDetector(
            onTap: () => controller.switchMode(AuthMode.login),
            child: Text(
              context.tr('already_have_account'),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.primaryDarkColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Phone Verification (OTP) View
  // ---------------------------------------------------------------------------
  Widget _buildPhoneOtpForm(BuildContext context, AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('phone_auth'),
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        Text(
          'Sent to ${controller.phoneNumberForOtp}',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppTextField(
          controller: _otpCodeController,
          labelText: context.tr('verification_code'),
          hintText: '• • • • • •',
          keyboardType: TextInputType.number,
          prefixIcon: Icon(
            Icons.pin_rounded,
            size: 18,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppButton(
          text: context.tr('verify_otp'),
          isLoading: isLoading,
          onPressed: () => controller.verifyPhoneOtp(_otpCodeController.text),
        ),

        const SizedBox(height: AppConstants.space16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppButton(
              text: context.tr('back_to_sign_in'),
              variant: AppButtonVariant.text,
              onPressed: () => controller.switchMode(AuthMode.login),
            ),
            if (controller.otpCountdown > 0)
              Text(
                '${context.tr('resend_in')} ${controller.otpCountdown}s',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.textMutedColor,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              AppButton(
                text: context.tr('resend_otp'),
                variant: AppButtonVariant.text,
                onPressed: () =>
                    controller.startPhoneAuth(controller.phoneNumberForOtp),
              ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Forgot Password View
  // ---------------------------------------------------------------------------
  Widget _buildForgotPasswordForm(BuildContext context, AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('reset_password'),
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        Text(
          context.tr('reset_password_sub'),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppTextField(
          controller: _resetIdentifierController,
          labelText: context.tr('email_or_phone'),
          hintText: AppConstants.emailOrPhoneHint,
          prefixIcon: Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppButton(
          text: context.tr('send_reset_link'),
          isLoading: isLoading,
          onPressed: () => controller
              .sendPasswordReset(_resetIdentifierController.text),
        ),

        const SizedBox(height: AppConstants.space16),

        Center(
          child: AppButton(
            text: context.tr('back_to_sign_in'),
            variant: AppButtonVariant.text,
            onPressed: () => controller.switchMode(AuthMode.login),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Phone Input Modal Dialog
  // ---------------------------------------------------------------------------
  void _showPhoneInputDialog(BuildContext context, AuthController controller) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(
            dialogContext.tr('phone_auth'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: context.textPrimaryColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogContext.tr('enter_mobile_otp'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: AppConstants.space16),
              AppTextField(
                controller: _phoneInputController,
                hintText: AppConstants.enterPhoneNumberHint,
                keyboardType: TextInputType.phone,
                prefixIcon: Icon(Icons.phone_rounded, size: 18, color: context.textSecondaryColor),
              ),
            ],
          ),
          actions: [
            AppButton(
              text: dialogContext.tr('cancel'),
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppButton(
              text: dialogContext.tr('send_otp'),
              width: 160,
              onPressed: () {
                final phone = _phoneInputController.text;
                Navigator.pop(dialogContext);
                controller.startPhoneAuth(phone);
              },
            ),
          ],
        );
      },
    );
  }

  void _showLanguagePickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.borderRadiusLarge)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final langController = ctx.watch<LanguageController>();
            final searchQuery = _languageSearchController.text.trim().toLowerCase();

            final filteredLanguages = LanguageController.supportedLanguages.where((l) {
              if (searchQuery.isEmpty) return true;
              return l.name.toLowerCase().contains(searchQuery) ||
                  l.nativeName.toLowerCase().contains(searchQuery) ||
                  l.code.toLowerCase().contains(searchQuery);
            }).toList();

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
                        Icon(Icons.language_rounded, size: 20, color: context.primaryDarkColor),
                        const SizedBox(width: 8),
                        Text(
                          langController.tr('select_language'),
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

                  // Search Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16),
                    child: TextField(
                      controller: _languageSearchController,
                      onChanged: (_) => setModalState(() {}),
                      style: GoogleFonts.inter(fontSize: 14, color: context.textPrimaryColor),
                      decoration: InputDecoration(
                        hintText: langController.tr('search_language_hint'),
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: context.textMutedColor),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: context.textMutedColor),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        fillColor: context.scaffoldBg,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.space12),
                  Divider(height: 1, color: context.borderColor),

                  // Flag-free Language List
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = filteredLanguages[index];
                        final isSelected = lang.code == langController.currentLanguageCode;

                        return ListTile(
                          title: Text(
                            lang.name,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? context.primaryDarkColor : context.textPrimaryColor,
                            ),
                          ),
                          subtitle: Text(
                            lang.nativeName,
                            style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor, fontWeight: FontWeight.w600),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_rounded, color: context.primaryDarkColor, size: 20)
                              : null,
                          onTap: () {
                            langController.setLanguage(lang.code);
                            Navigator.pop(modalContext);
                          },
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
