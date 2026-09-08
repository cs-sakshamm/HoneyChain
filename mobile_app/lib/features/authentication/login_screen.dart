import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Center(
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
                    AuthMode.login => _buildLoginForm(controller),
                    AuthMode.register => _buildRegisterForm(controller),
                    AuthMode.phoneOtp => _buildPhoneOtpForm(controller),
                    AuthMode.forgotPassword =>
                      _buildForgotPasswordForm(controller),
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Production Login Form
  // ---------------------------------------------------------------------------
  Widget _buildLoginForm(AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sign in to your account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        const Text(
          'Manage your business supply chain operations.',
          style: TextStyle(
            fontSize: 14,
            color: AppConstants.textSecondary,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        // Email or Phone Field
        AppTextField(
          controller: _loginEmailOrPhoneController,
          labelText: 'Business Email or Phone',
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
          labelText: 'Password',
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
            text: AppConstants.forgotPasswordText,
            variant: AppButtonVariant.text,
            onPressed: () => controller.switchMode(AuthMode.forgotPassword),
          ),
        ),

        const SizedBox(height: AppConstants.space16),

        // Log In Primary Action
        AppButton(
          text: AppConstants.loginButtonText,
          isLoading: isLoading,
          onPressed: () => controller.loginWithEmailOrPhone(
            _loginEmailOrPhoneController.text,
            _loginPasswordController.text,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        // Divider
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppConstants.space12),
              child: Text(
                AppConstants.orDividerText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),

        const SizedBox(height: AppConstants.space24),

        // Provider Options in a single horizontal row (48x48 Icon Boxes)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SocialIconButton(
              icon: const GoogleLogoIcon(size: 20),
              tooltip: AppConstants.googleSignInText,
              isLoading: isLoading,
              onPressed: () => controller.signInWithGoogle(),
            ),
            const SizedBox(width: AppConstants.space16),
            SocialIconButton(
              icon: const Icon(Icons.apple, size: 22, color: Colors.black),
              tooltip: AppConstants.appleSignInText,
              isLoading: isLoading,
              onPressed: () => controller.signInWithApple(),
            ),
            const SizedBox(width: AppConstants.space16),
            SocialIconButton(
              icon: const Icon(Icons.smartphone_rounded,
                  size: 20, color: AppConstants.textPrimary),
              tooltip: AppConstants.phoneSignInText,
              isLoading: isLoading,
              onPressed: () => _showPhoneInputDialog(context, controller),
            ),
          ],
        ),

        const SizedBox(height: AppConstants.space32),

        // Switch to Create Business Account
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              AppConstants.dontHaveAccountText,
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.textSecondary,
              ),
            ),
            GestureDetector(
              onTap: () => controller.switchMode(AuthMode.register),
              child: const Text(
                AppConstants.createAccountLinkText,
                style: TextStyle(
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
  Widget _buildRegisterForm(AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create Business Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        const Text(
          'Get started with HoneyChain for your enterprise.',
          style: TextStyle(
            fontSize: 14,
            color: AppConstants.textSecondary,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppTextField(
          controller: _regBusinessNameController,
          labelText: 'Legal Business Name',
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
          labelText: 'Business Email or Phone',
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
          labelText: 'Password',
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
          text: AppConstants.createAccountButtonText,
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
            child: const Text(
              AppConstants.alreadyHaveAccountText,
              style: TextStyle(
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
  Widget _buildPhoneOtpForm(AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          AppConstants.phoneOtpTitle,
          style: TextStyle(
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
          labelText: '6-Digit Verification Code',
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
          text: AppConstants.verifyOtpButtonText,
          isLoading: isLoading,
          onPressed: () => controller.verifyPhoneOtp(_otpCodeController.text),
        ),

        const SizedBox(height: AppConstants.space16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppButton(
              text: 'Back to Sign In',
              variant: AppButtonVariant.text,
              onPressed: () => controller.switchMode(AuthMode.login),
            ),
            if (controller.otpCountdown > 0)
              Text(
                'Resend in ${controller.otpCountdown}s',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppConstants.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              AppButton(
                text: AppConstants.resendOtpText,
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
  Widget _buildForgotPasswordForm(AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          AppConstants.resetPasswordTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        const Text(
          AppConstants.resetPasswordSubtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppConstants.textSecondary,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppTextField(
          controller: _resetIdentifierController,
          labelText: 'Business Email or Phone',
          hintText: AppConstants.emailOrPhoneHint,
          prefixIcon: const Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: AppConstants.textSecondary,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppButton(
          text: AppConstants.sendResetLinkText,
          isLoading: isLoading,
          onPressed: () => controller
              .sendPasswordReset(_resetIdentifierController.text),
        ),

        const SizedBox(height: AppConstants.space16),

        Center(
          child: AppButton(
            text: 'Back to Sign In',
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
          title: const Text('Phone Authentication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your mobile number to receive a 6-digit OTP code.',
                style: TextStyle(
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
              text: 'Cancel',
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppButton(
              text: AppConstants.sendOtpButtonText,
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
}
