import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../controllers/user_controller.dart';

/// Form screen to Change Password
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final userCtrl = context.read<UserController>();
    final success = await userCtrl.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('password_updated'), style: GoogleFonts.inter()),
          backgroundColor: AppConstants.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _PillBackButton(),
                  const SizedBox(width: 14),
                  Text(
                    context.tr('change_password') == 'change_password' ? 'Change Password' : context.tr('change_password'),
                    style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimaryColor, letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.space16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  children: [
                    _buildPasswordField(
                      context: context,
                      label: '${context.tr('current_password')} *',
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      onToggleVisibility: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                      validator: (val) =>
                          (val == null || val.isEmpty) ? context.tr('current_password') : null,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    _buildPasswordField(
                      context: context,
                      label: '${context.tr('new_password')} *',
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      onToggleVisibility: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      validator: (val) {
                        if (val == null || val.isEmpty) return context.tr('new_password');
                        if (val.length < 6) return context.tr('new_password');
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.space16),
                    _buildPasswordField(
                      context: context,
                      label: '${context.tr('confirm_password')} *',
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      onToggleVisibility: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (val) {
                        if (val == null || val.isEmpty) return context.tr('confirm_password');
                        if (val != _newPasswordController.text) return context.tr('confirm_password');
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.space32),
              AppButton(
                text: context.tr('update_password'),
                isLoading: _isLoading,
                variant: AppButtonVariant.primary,
                onPressed: _updatePassword,
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


  Widget _buildPasswordField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: GoogleFonts.inter(fontSize: 14, color: context.textPrimaryColor),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: GoogleFonts.inter(color: context.textMutedColor),
            fillColor: context.surfaceColor,
            filled: true,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              borderSide: const BorderSide(color: AppConstants.primary, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: context.textMutedColor,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _PillBackButton extends StatelessWidget {
  const _PillBackButton();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => Navigator.pop(context),
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
