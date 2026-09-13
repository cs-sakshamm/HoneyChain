import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
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
    String orgLabel = 'Organization / Business Name *';
    String orgHint = 'e.g. Cascade Processing Facility';
    String locLabel = 'Processing Location *';
    String locHint = 'e.g. Bend Industrial Park, OR';
    String licLabel = 'FSSAI Registration / License Number *';
    String licHint = 'e.g. FSSAI-PROC-2026-9812';

    if (isLb) {
      nameLabel = 'Authorized Person Name *';
      nameHint = 'e.g. Dr. Evelyn Vance';
      orgLabel = 'Laboratory Name *';
      orgHint = 'e.g. Pacific Pure Apiculture Labs';
      locLabel = 'Laboratory Address *';
      locHint = 'e.g. Corvallis Tech Campus, OR';
      licLabel = 'Laboratory Registration / Accreditation Number *';
      licHint = 'e.g. LAB-ACCRED-2026-4402';
    } else if (isPkg) {
      nameLabel = 'Authorized Person Name *';
      nameHint = 'e.g. Marcus Sterling';
      orgLabel = 'Company / Packaging Unit Name *';
      orgHint = 'e.g. Artisan Honey Packaging Co.';
      locLabel = 'Packaging Facility Location *';
      locHint = 'e.g. Portland Logistics Hub, OR';
      licLabel = 'FSSAI Registration / License Number *';
      licHint = 'e.g. FSSAI-PKG-2026-1184';
    } else if (isCol) {
      nameLabel = 'Full Name *';
      nameHint = 'e.g. Cascade Facility Manager';
      orgLabel = 'Organization / Business Name *';
      orgHint = 'e.g. Cascade Processing Ltd.';
      locLabel = 'Collection / Processing Location *';
      locHint = 'e.g. Bend Industrial Park, OR';
      licLabel = 'FSSAI Registration / License Number *';
      licHint = 'e.g. FSSAI-PROC-2026-9812';
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
                              hint: 'email@example.com',
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
                              hint: '+1 (555) 234-5678',
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
