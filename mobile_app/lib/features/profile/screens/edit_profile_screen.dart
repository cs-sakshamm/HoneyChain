import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../controllers/user_controller.dart';

/// Form screen to Edit User Profile
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserController>().user;
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final userCtrl = context.read<UserController>();
    await userCtrl.updateProfile(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile updated successfully'),
        backgroundColor: AppConstants.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: const GlobalAppBar(
        showBackButton: true,
        titleText: 'Edit Profile',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    _buildInputField(
                      label: 'Full Name *',
                      hint: 'Enter full legal name',
                      controller: _nameController,
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    _buildInputField(
                      label: 'Business Email *',
                      hint: 'email@example.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email is required';
                        if (!val.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.space16),
                    _buildInputField(
                      label: 'Phone Number *',
                      hint: '+1 (555) 000-0000',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Phone is required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.space32),
              AppButton(
                text: 'Save Changes',
                isLoading: _isSaving,
                variant: AppButtonVariant.primary,
                onPressed: _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: AppConstants.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
          ),
          validator: validator,
        ),
      ],
    );
  }
}
