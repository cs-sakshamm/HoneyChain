import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../controllers/user_controller.dart';

/// Form screen to Edit User Profile
/// Adapts dynamically based on the active role while maintaining
/// the exact existing Harvester profile structure for Harvesters.
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
  late TextEditingController _avatarUrlController;

  // Role-specific controllers
  late TextEditingController _organizationController;
  late TextEditingController _locationController;
  late TextEditingController _licenseController;
  late TextEditingController _designationController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserController>().user;
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phone);
    _avatarUrlController = TextEditingController(text: user.avatarUrl ?? '');
    _organizationController = TextEditingController(text: user.organizationName ?? '');
    _locationController = TextEditingController(text: user.facilityLocation ?? '');
    _licenseController = TextEditingController(text: user.licenseNumber ?? '');
    _designationController = TextEditingController(text: user.designation ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    _organizationController.dispose();
    _locationController.dispose();
    _licenseController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  bool _isHarvester(String role) {
    final r = role.toUpperCase().trim();
    return r.isEmpty || r == 'HARVESTER';
  }

  bool _isCollection(String role) {
    final r = role.toUpperCase().trim();
    return r.contains('COLLECT') || r.contains('PROCESS');
  }

  bool _isLab(String role) {
    final r = role.toUpperCase().trim();
    return r.contains('LAB');
  }

  bool _isPackaging(String role) {
    final r = role.toUpperCase().trim();
    return r.contains('PKG') || r.contains('PACKAG');
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final userCtrl = context.read<UserController>();
    final user = userCtrl.user;
    final isHarv = _isHarvester(user.role);

    await userCtrl.updateProfile(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      role: user.role,
      avatarUrl: _avatarUrlController.text,
      organizationName: !isHarv ? _organizationController.text : null,
      facilityLocation: !isHarv ? _locationController.text : null,
      licenseNumber: !isHarv ? _licenseController.text : null,
      designation: !isHarv && _designationController.text.isNotEmpty ? _designationController.text : null,
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
    final userCtrl = context.watch<UserController>();
    final user = userCtrl.user;
    final role = user.role;

    final isHarv = _isHarvester(role);
    final isCol = _isCollection(role);
    final isLb = _isLab(role);
    final isPkg = _isPackaging(role);

    String nameLabel = 'Full Name *';
    String nameHint = 'Enter your full name';
    String orgLabel = 'Organization / Collection Centre Name *';
    String orgHint = 'Enter collection centre name';
    String locLabel = 'Processing Location / Address *';
    String locHint = 'Enter your complete address';
    String licLabel = 'FSSAI Registration / License Number *';
    String licHint = 'e.g. FSSAI-2026-98124';

    if (isLb) {
      nameLabel = 'Authorized Person Name *';
      nameHint = 'Enter your full name';
      orgLabel = 'Laboratory Name *';
      orgHint = 'e.g. Apex Quality Food Testing Lab';
      locLabel = 'Laboratory Complete Address *';
      locHint = 'Enter your complete address';
      licLabel = 'Laboratory Registration / Accreditation Number *';
      licHint = 'e.g. NABL-LAB-2026-HQ88';
    } else if (isPkg) {
      nameLabel = 'Authorized Person Name *';
      nameHint = 'Enter your full name';
      orgLabel = 'Company / Packaging Facility Name *';
      orgHint = 'e.g. HoneyChain Eco Packaging Facility';
      locLabel = 'Packaging Facility Complete Address *';
      locHint = 'Enter your complete address';
      licLabel = 'FSSAI Registration / License Number *';
      licHint = 'e.g. PKG-FSSAI-2026-B99';
    } else if (isCol) {
      nameLabel = 'Full Name *';
      nameHint = 'Enter your full name';
      orgLabel = 'Organization / Collection Centre Name *';
      orgHint = 'Enter collection centre name';
      locLabel = 'Collection / Processing Location Address *';
      locHint = 'Enter your complete address';
      licLabel = 'FSSAI Registration / License Number *';
      licHint = 'e.g. FSSAI-2026-98124';
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const _PillBackButton(),
                  const SizedBox(width: 14),
                  Text(
                    context.tr('edit_profile') == 'edit_profile' ? 'Edit Profile' : context.tr('edit_profile'),
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.space20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppConstants.space8),

                      // Avatar Management Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppConstants.space16),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Row(
                          children: [
                            const UserAvatar(size: 64),
                            const SizedBox(width: AppConstants.space16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                        ? 'Custom Avatar'
                                        : (user.googlePhotoUrl != null && user.googlePhotoUrl!.isNotEmpty
                                            ? 'Google Profile Picture'
                                            : 'Default Initials'),
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                        ? 'Custom photo takes priority over Google profile.'
                                        : (user.googlePhotoUrl != null && user.googlePhotoUrl!.isNotEmpty
                                            ? 'Synced automatically from your Google account.'
                                            : 'Add a custom photo URL or sign in with Google.'),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                  if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _avatarUrlController.clear();
                                        });
                                      },
                                      child: Text(
                                        'Revert to Google Photo',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppConstants.honeyAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.space16),

                      // Section 1: Personal & Contact Information
                      Container(
                        padding: const EdgeInsets.all(AppConstants.space16),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact Information',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: AppConstants.space16),
                            _buildInputField(
                              context,
                              label: nameLabel,
                              hint: nameHint,
                              controller: _nameController,
                              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter name' : null,
                            ),
                            const SizedBox(height: AppConstants.space16),
                            _buildInputField(
                              context,
                              label: 'Email *',
                              hint: 'Enter your email address',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter email';
                                if (!val.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppConstants.space16),
                            _buildInputField(
                              context,
                              label: 'Mobile Number *',
                              hint: 'e.g. 98765 43210',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter phone number' : null,
                            ),
                          ],
                        ),
                      ),

                      // Section 2: Role-specific Business / Facility Information (Non-Harvester)
                      if (!isHarv) ...[
                        const SizedBox(height: AppConstants.space16),
                        Container(
                          padding: const EdgeInsets.all(AppConstants.space16),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Facility & Accreditation Information',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: AppConstants.space16),
                              _buildInputField(
                                context,
                                label: orgLabel,
                                hint: orgHint,
                                controller: _organizationController,
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'This field is required' : null,
                              ),
                              const SizedBox(height: AppConstants.space16),
                              _buildInputField(
                                context,
                                label: locLabel,
                                hint: locHint,
                                controller: _locationController,
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'This field is required' : null,
                              ),
                              const SizedBox(height: AppConstants.space16),
                              _buildInputField(
                                context,
                                label: licLabel,
                                hint: licHint,
                                controller: _licenseController,
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'This field is required' : null,
                              ),
                              const SizedBox(height: AppConstants.space16),
                              _buildInputField(
                                context,
                                label: 'Designation / Title (Optional)',
                                hint: 'e.g. Operations Director / Quality Inspector',
                                controller: _designationController,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppConstants.space24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                            ),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                                )
                              : Text(
                                  'Save Changes',
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.onPrimary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),
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

  Widget _buildInputField(
    BuildContext context, {
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
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 14, color: context.textPrimaryColor),
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
