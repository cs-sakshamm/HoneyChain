import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/global_app_bar.dart';
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
          content: const Text('Password updated successfully'),
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
      backgroundColor: AppConstants.background,
      appBar: const GlobalAppBar(
        showBackButton: true,
        titleText: 'Change Password',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.space16),
                decoration: BoxDecoration(
                  color: AppConstants.surface,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: AppConstants.border),
                ),
                child: Column(
                  children: [
                    _buildPasswordField(
                      label: 'Current Password *',
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      onToggleVisibility: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                      validator: (val) =>
                          (val == null || val.isEmpty) ? 'Enter current password' : null,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    _buildPasswordField(
                      label: 'New Password *',
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      onToggleVisibility: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter new password';
                        if (val.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.space16),
                    _buildPasswordField(
                      label: 'Confirm New Password *',
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      onToggleVisibility: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Confirm password';
                        if (val != _newPasswordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.space32),
              AppButton(
                text: 'Update Password',
                isLoading: _isLoading,
                variant: AppButtonVariant.primary,
                onPressed: _updatePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 14, color: AppConstants.textPrimary),
          decoration: InputDecoration(
            hintText: '••••••••',
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: AppConstants.textMuted,
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
