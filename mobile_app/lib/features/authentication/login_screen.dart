import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/localization_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_banner.dart';
import '../../core/widgets/social_icon_button.dart';
import 'auth_controller.dart';
import 'widgets/google_logo_icon.dart';

/// Senior Product Designer Login Screen for HoneyChain Business Owners
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
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Right Small Language Selector [ 🌐 EN ] (Rule #1 Compliant)
            Positioned(
              top: 8,
              right: 16,
              child: Consumer<LanguageController>(
                builder: (context, langCtrl, _) {
                  return InkWell(
                    onTap: () => _showLanguagePickerModal(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppConstants.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppConstants.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 16, color: AppConstants.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            langCtrl.currentLanguage.nativeName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.textPrimary,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppConstants.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.space24,
                  vertical: AppConstants.space32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Brand Logo
                      const Center(
                        child: AppLogo(
                          size: 40,
                          showWordmark: true,
                        ),
                      ),

                      const SizedBox(height: AppConstants.space32),

                      // Feedback Banners (Inline Alerts)
                      if (controller.status == AuthStateStatus.error &&
                          controller.errorMessage != null)
                        FeedbackBanner(
                          message: controller.errorMessage!,
                          type: FeedbackBannerType.error,
                          onClose: () => controller.resetError(),
                        ),

                      if (controller.infoMessage != null)
                        FeedbackBanner(
                          message: controller.infoMessage!,
                          type: FeedbackBannerType.info,
                        ),

                      // View Content based on AuthMode
                      switch (controller.mode) {
                        AuthMode.login => _buildLoginForm(context, controller),
                        AuthMode.register => _buildRegisterForm(context, controller),
                        AuthMode.phoneOtp => _buildPhoneOtpForm(context, controller),
                        AuthMode.forgotPassword =>
                          _buildForgotPasswordForm(context, controller),
                      },

                      const SizedBox(height: AppConstants.space32),

                      // Legal Terms Footer
                      const Text(
                        AppConstants.legalDisclaimer,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConstants.textMuted,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
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

  // ---------------------------------------------------------------------------
  // 1. Production Login Form
  // ---------------------------------------------------------------------------
  Widget _buildLoginForm(BuildContext context, AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('sign_in_account'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        Text(
          context.tr('manage_business_sub'),
          style: const TextStyle(
            fontSize: 14,
            color: AppConstants.textSecondary,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        // Email or Phone Field
        AppTextField(
          controller: _loginEmailOrPhoneController,
          labelText: context.tr('email_or_phone'),
          hintText: AppConstants.emailOrPhoneHint,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: AppConstants.textSecondary,
          ),
        ),

        const SizedBox(height: AppConstants.space16),

        // Password Field
        AppTextField(
          controller: _loginPasswordController,
          labelText: context.tr('password'),
          hintText: AppConstants.passwordHint,
          obscureText: !controller.isPasswordVisible,
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppConstants.textSecondary,
          ),
          suffixIcon: GestureDetector(
            onTap: () => controller.togglePasswordVisibility(),
            child: Icon(
              controller.isPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: AppConstants.textSecondary,
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
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.space12),
              child: Text(
                context.tr('or'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),

        const SizedBox(height: AppConstants.space24),

        // Provider Options in a single horizontal row (48x48 Icon Boxes)
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
              icon: const Icon(Icons.apple, size: 22, color: Colors.black),
              tooltip: context.tr('apple_sign_in'),
              isLoading: isLoading,
              onPressed: () => controller.signInWithApple(),
            ),
            const SizedBox(width: AppConstants.space16),
            SocialIconButton(
              icon: const Icon(Icons.smartphone_rounded,
                  size: 20, color: AppConstants.textPrimary),
              tooltip: context.tr('phone_sign_in'),
              isLoading: isLoading,
              onPressed: () => _showPhoneInputDialog(context, controller),
            ),
          ],
        ),

        const SizedBox(height: AppConstants.space32),

        // Switch to Create Business Account
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              context.tr('dont_have_account'),
              style: const TextStyle(
                fontSize: 14,
                color: AppConstants.textSecondary,
              ),
            ),
            GestureDetector(
              onTap: () => controller.switchMode(AuthMode.register),
              child: Text(
                context.tr('create_account'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.primaryDark,
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        Text(
          context.tr('get_started_sub'),
          style: const TextStyle(
            fontSize: 14,
            color: AppConstants.textSecondary,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppTextField(
          controller: _regBusinessNameController,
          labelText: context.tr('legal_business_name'),
          hintText: AppConstants.businessNameHint,
          prefixIcon: const Icon(
            Icons.domain_rounded,
            size: 18,
            color: AppConstants.textSecondary,
          ),
        ),
        const SizedBox(height: AppConstants.space16),

        AppTextField(
          controller: _regEmailOrPhoneController,
          labelText: context.tr('email_or_phone'),
          hintText: AppConstants.emailOrPhoneHint,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: AppConstants.textSecondary,
          ),
        ),
        const SizedBox(height: AppConstants.space16),

        AppTextField(
          controller: _regPasswordController,
          labelText: context.tr('password'),
          hintText: AppConstants.passwordHint,
          obscureText: !controller.isPasswordVisible,
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppConstants.textSecondary,
          ),
          suffixIcon: GestureDetector(
            onTap: () => controller.togglePasswordVisibility(),
            child: Icon(
              controller.isPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: AppConstants.textSecondary,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppConstants.primaryDark,
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        Text(
          'Sent to ${controller.phoneNumberForOtp}',
          style: const TextStyle(
            fontSize: 14,
            color: AppConstants.textSecondary,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppTextField(
          controller: _otpCodeController,
          labelText: context.tr('verification_code'),
          hintText: '• • • • • •',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(
            Icons.pin_rounded,
            size: 18,
            color: AppConstants.textSecondary,
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
                style: const TextStyle(
                  fontSize: 13,
                  color: AppConstants.textMuted,
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        Text(
          context.tr('reset_password_sub'),
          style: const TextStyle(
            fontSize: 14,
            color: AppConstants.textSecondary,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppTextField(
          controller: _resetIdentifierController,
          labelText: context.tr('email_or_phone'),
          hintText: AppConstants.emailOrPhoneHint,
          prefixIcon: const Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: AppConstants.textSecondary,
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
          title: Text(dialogContext.tr('phone_auth')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogContext.tr('enter_mobile_otp'),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppConstants.textSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.space16),
              AppTextField(
                controller: _phoneInputController,
                hintText: AppConstants.enterPhoneNumberHint,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_rounded, size: 18),
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
      backgroundColor: AppConstants.surface,
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
                      color: AppConstants.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppConstants.space16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.space24),
                    child: Row(
                      children: [
                        const Icon(Icons.language_rounded, size: 20, color: AppConstants.primaryDark),
                        const SizedBox(width: 8),
                        Text(
                          langController.tr('select_language'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.textPrimary,
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
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: langController.tr('search_language_hint'),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppConstants.textMuted),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        fillColor: AppConstants.background,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.space12),
                  const Divider(height: 1),

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
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppConstants.primaryDark : AppConstants.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            lang.nativeName,
                            style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded, color: AppConstants.primaryDark, size: 20)
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

