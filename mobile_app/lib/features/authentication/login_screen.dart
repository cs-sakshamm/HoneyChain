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
import 'auth_controller.dart';
import 'widgets/google_logo_icon.dart';

/// Redesigned Production-Ready Login Screen for HoneyChain
/// Clean, minimal, human-designed SaaS authentication experience
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  final _resetIdentifierController = TextEditingController();
  final _languageSearchController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  String? _emailErrorText;
  String? _passwordErrorText;
  String? _regNameErrorText;
  String? _regEmailErrorText;
  String? _regPasswordErrorText;
  String? _regConfirmPasswordErrorText;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _resetIdentifierController.dispose();
    _languageSearchController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleLogin(AuthController controller) {
    setState(() {
      _emailErrorText = null;
      _passwordErrorText = null;
    });

    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    bool hasError = false;

    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _emailErrorText = 'Please enter a valid email address.';
      });
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() {
        _passwordErrorText = 'Please enter your password.';
      });
      hasError = true;
    }

    if (!hasError) {
      controller.loginWithEmail(email, password);
    }
  }

  void _handleRegister(AuthController controller) {
    setState(() {
      _regNameErrorText = null;
      _regEmailErrorText = null;
      _regPasswordErrorText = null;
      _regConfirmPasswordErrorText = null;
    });

    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;
    final confirmPassword = _regConfirmPasswordController.text;

    bool hasError = false;

    if (name.isEmpty) {
      setState(() {
        _regNameErrorText = 'Please enter your full name.';
      });
      hasError = true;
    }

    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _regEmailErrorText = 'Please enter a valid email address.';
      });
      hasError = true;
    }

    if (password.length < 6) {
      setState(() {
        _regPasswordErrorText = 'Password must be at least 6 characters.';
      });
      hasError = true;
    }

    if (password != confirmPassword) {
      setState(() {
        _regConfirmPasswordErrorText = 'Passwords do not match.';
      });
      hasError = true;
    }

    if (!hasError) {
      controller.registerAccount(
        name: name,
        email: email,
        password: password,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 840;

            return Stack(
              children: [
                if (isDesktop)
                  _buildDesktopLayout(context, controller, constraints)
                else
                  _buildMobileLayout(context, controller),

                
                // Top Left Back Button
                Positioned(
                  top: 16,
                  left: 20,
                  child: InkWell(
                    onTap: () => controller.clearRole(),
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
                            context.tr('back_to_roles'),
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
  // DESKTOP SPLIT LAYOUT (Calm Brand Section Left + Focused Auth Right)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(
    BuildContext context,
    AuthController controller,
    BoxConstraints constraints,
  ) {
    final leftBg = context.textPrimaryColor.withValues(alpha: 0.02);

    return Row(
      children: [
        // Left Column: Calm HoneyChain Brand Atmosphere
        Expanded(
          flex: 5,
          child: Container(
            color: leftBg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.space48),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (AppConstants.space48 * 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppLogo(
                      size: 32,
                      showWordmark: true,
                    ),
                    const SizedBox(height: AppConstants.space48),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.brandHeadline,
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
                            AppConstants.brandSubtitle,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: context.textSecondaryColor,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: AppConstants.space32),

                          // Subtle Clean Brand Identity Panel
                          Container(
                            padding: const EdgeInsets.all(AppConstants.space20),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                              border: Border.all(color: context.borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: context.textPrimaryColor.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildOperationalBadge(
                                  context,
                                  Icons.hub_outlined,
                                  'Real-time Supply Chain Network',
                                  'Unified logistics and node monitoring',
                                ),
                                const SizedBox(height: AppConstants.space16),
                                Divider(height: 1, color: context.borderColor),
                                const SizedBox(height: AppConstants.space16),
                                _buildOperationalBadge(
                                  context,
                                  Icons.lock_outline_rounded,
                                  'Enterprise-Grade Security',
                                  'Encrypted session verification & auditing',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppConstants.space48),
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
          ),
        ),

        // Right Column: Focused Authentication Container (Max-width ~440px)
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.space32,
                vertical: AppConstants.space32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildAuthContent(context, controller),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalBadge(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.primarySoftColor,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
          child: Icon(icon, size: 20, color: context.honeyAccent),
        ),
        const SizedBox(width: AppConstants.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
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
          constraints: const BoxConstraints(maxWidth: 440),
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
        // Feedback Banners for Global State Errors / Info
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

        // Active View Switch
        switch (controller.mode) {
          AuthMode.login => _buildLoginForm(context, controller),
          AuthMode.register => _buildRegisterForm(context, controller),
          AuthMode.forgotPassword => _buildForgotPasswordForm(context, controller),
        },

        const SizedBox(height: AppConstants.space32),

        // Legal Terms Disclaimer
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
  // 1. Refined Login Form
  // ---------------------------------------------------------------------------
  
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
        return AppConstants.loginTitle;
    }
  }

  String _getRoleSubtitle(BuildContext context, UserRole? role) {
    if (role != null) return AppConstants.loginSubtitle;
    return AppConstants.loginSubtitle;
  }

  String _getRoleRegisterTitle(BuildContext context, UserRole? role) {
    switch (role) {
      case UserRole.harvester:
        return 'Create Harvester Account';
      case UserRole.collectionProcessing:
        return 'Create Collection & Processing Account';
      case UserRole.labTesting:
        return 'Create Lab Tester Account';
      case UserRole.packaging:
        return 'Create Packaging Manager Account';
      default:
        return 'Create Account';
    }
  }

  String _getRoleRegisterSubtitle(BuildContext context, UserRole? role) {
    switch (role) {
      case UserRole.harvester:
        return 'Register your apiary and start hive honey logging.';
      case UserRole.collectionProcessing:
        return 'Register your collection center and intake batches.';
      case UserRole.labTesting:
        return 'Register your testing laboratory for sample analysis.';
      case UserRole.packaging:
        return 'Register your packaging facility for batch serialization.';
      default:
        return 'Start managing your supply chain with HoneyChain.';
    }
  }

  Widget _buildLoginForm(BuildContext context, AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Form(
      key: _formKey,
      child: Column(
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
            _getRoleSubtitle(context, controller.selectedRole),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),

          const SizedBox(height: AppConstants.space28),

          // Email Address Input
          AppTextField(
            controller: _loginEmailController,
            focusNode: _emailFocusNode,
            labelText: AppConstants.emailLabel,
            hintText: AppConstants.emailHint,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            errorText: _emailErrorText,
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: context.textSecondaryColor,
            ),
            onChanged: (_) {
              if (_emailErrorText != null) {
                setState(() => _emailErrorText = null);
              }
            },
          ),

          const SizedBox(height: AppConstants.space16),

          // Password Input
          AppTextField(
            controller: _loginPasswordController,
            focusNode: _passwordFocusNode,
            labelText: AppConstants.passwordLabel,
            hintText: AppConstants.passwordHint,
            obscureText: !controller.isPasswordVisible,
            textInputAction: TextInputAction.done,
            errorText: _passwordErrorText,
            onFieldSubmitted: (_) => _handleLogin(controller),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: context.textSecondaryColor,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                controller.isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: context.textSecondaryColor,
              ),
              onPressed: () => controller.togglePasswordVisibility(),
              tooltip: controller.isPasswordVisible ? 'Hide password' : 'Show password',
            ),
            onChanged: (_) {
              if (_passwordErrorText != null) {
                setState(() => _passwordErrorText = null);
              }
            },
          ),

          const SizedBox(height: AppConstants.space12),

          // Forgot Password Secondary Link
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => controller.switchMode(AuthMode.forgotPassword),
              child: Text(
                AppConstants.forgotPasswordText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.honeyAccent,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.space24),

          // Primary Sign In Button
          AppButton(
            text: AppConstants.loginButtonText,
            isLoading: isLoading,
            onPressed: () => _handleLogin(controller),
          ),

          const SizedBox(height: AppConstants.space20),

          // Registration Prompt Footer
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),
              GestureDetector(
                onTap: () => controller.switchMode(AuthMode.register),
                child: Text(
                  AppConstants.createAccountButtonText,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.honeyAccent,
                  ),
                ),
              ),
            ],
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

          // Recommendation text above Google button
          Center(
            child: Text(
              AppConstants.googleRecommendationText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.textSecondaryColor,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.space8),

          // Secondary Google Option
          OutlinedButton(
            onPressed: isLoading ? null : () => controller.signInWithGoogle(),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Account Registration View
  // ---------------------------------------------------------------------------
  Widget _buildRegisterForm(BuildContext context, AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _getRoleRegisterTitle(context, controller.selectedRole),
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.textPrimaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppConstants.space6),
          Text(
            _getRoleRegisterSubtitle(context, controller.selectedRole),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),

          const SizedBox(height: AppConstants.space24),

          // Full Name
          AppTextField(
            controller: _regNameController,
            labelText: 'Full Name',
            hintText: 'Enter your full name or business name',
            textInputAction: TextInputAction.next,
            errorText: _regNameErrorText,
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: context.textSecondaryColor,
            ),
            onChanged: (_) {
              if (_regNameErrorText != null) {
                setState(() => _regNameErrorText = null);
              }
            },
          ),
          const SizedBox(height: AppConstants.space16),

          // Email
          AppTextField(
            controller: _regEmailController,
            labelText: AppConstants.emailLabel,
            hintText: AppConstants.emailHint,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            errorText: _regEmailErrorText,
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: context.textSecondaryColor,
            ),
            onChanged: (_) {
              if (_regEmailErrorText != null) {
                setState(() => _regEmailErrorText = null);
              }
            },
          ),
          const SizedBox(height: AppConstants.space16),

          // Password
          AppTextField(
            controller: _regPasswordController,
            labelText: AppConstants.passwordLabel,
            hintText: AppConstants.passwordHint,
            obscureText: !controller.isPasswordVisible,
            textInputAction: TextInputAction.next,
            errorText: _regPasswordErrorText,
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: context.textSecondaryColor,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                controller.isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: context.textSecondaryColor,
              ),
              onPressed: () => controller.togglePasswordVisibility(),
            ),
            onChanged: (_) {
              if (_regPasswordErrorText != null) {
                setState(() => _regPasswordErrorText = null);
              }
            },
          ),
          const SizedBox(height: AppConstants.space16),

          // Confirm Password
          AppTextField(
            controller: _regConfirmPasswordController,
            labelText: 'Confirm Password',
            hintText: 'Re-enter your password',
            obscureText: !controller.isPasswordVisible,
            textInputAction: TextInputAction.done,
            errorText: _regConfirmPasswordErrorText,
            onFieldSubmitted: (_) => _handleRegister(controller),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: context.textSecondaryColor,
            ),
            onChanged: (_) {
              if (_regConfirmPasswordErrorText != null) {
                setState(() => _regConfirmPasswordErrorText = null);
              }
            },
          ),

          const SizedBox(height: AppConstants.space24),

          // Create Account Button
          AppButton(
            text: 'Create account',
            isLoading: isLoading,
            onPressed: () => _handleRegister(controller),
          ),

          const SizedBox(height: AppConstants.space20),

          // Already have account Link
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),
              GestureDetector(
                onTap: () => controller.switchMode(AuthMode.login),
                child: Text(
                  'Sign in',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.honeyAccent,
                  ),
                ),
              ),
            ],
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

          // Recommendation text above Google button
          Center(
            child: Text(
              AppConstants.googleRecommendationText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.textSecondaryColor,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.space8),

          // Secondary Google Option
          OutlinedButton(
            onPressed: isLoading ? null : () => controller.signInWithGoogle(),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Forgot Password View
  // ---------------------------------------------------------------------------
  Widget _buildForgotPasswordForm(BuildContext context, AuthController controller) {
    final isLoading = controller.status == AuthStateStatus.authenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset password',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: context.textPrimaryColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppConstants.space6),
        Text(
          'Enter your email address and we will send you password reset instructions.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppTextField(
          controller: _resetIdentifierController,
          labelText: AppConstants.emailLabel,
          hintText: AppConstants.emailHint,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: context.textSecondaryColor,
          ),
        ),

        const SizedBox(height: AppConstants.space24),

        AppButton(
          text: 'Send reset link',
          isLoading: isLoading,
          onPressed: () => controller.sendPasswordReset(_resetIdentifierController.text),
        ),

        const SizedBox(height: AppConstants.space20),

        Center(
          child: GestureDetector(
            onTap: () => controller.switchMode(AuthMode.login),
            child: Text(
              'Back to sign in',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.honeyAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Language Picker Bottom Sheet
  // ---------------------------------------------------------------------------
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

                  // Search Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16),
                    child: TextField(
                      controller: _languageSearchController,
                      onChanged: (_) => setModalState(() {}),
                      style: GoogleFonts.inter(fontSize: 14, color: context.textPrimaryColor),
                      decoration: InputDecoration(
                        hintText: 'Search language...',
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

                  // Language List
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = filteredLanguages[index];
                        final isSelected = lang.code == langController.currentLanguageCode;

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
                            langController.setLanguage(lang.code);
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
