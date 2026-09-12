import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/utils/profile_guard.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/controllers/user_controller.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';

/// Form screen for creating or editing a Hive
class AddEditHiveScreen extends StatefulWidget {
  final Hive? hive;

  const AddEditHiveScreen({super.key, this.hive});

  @override
  State<AddEditHiveScreen> createState() => _AddEditHiveScreenState();
}

class _AddEditHiveScreenState extends State<AddEditHiveScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _hiveCodeController;
  late TextEditingController _apiaryLocationController;
  late TextEditingController _totalFramesController;
  late TextEditingController _broodFramesController;
  late TextEditingController _queenAgeMonthsController;
  late TextEditingController _expectedProductionController;
  late TextEditingController _previousYearProductionController;
  late TextEditingController _currentYearProductionController;
  late TextEditingController _notesController;

  // Selected Values
  late String _hiveType;
  late String _queenStatus;
  late String _colonyStrength;
  late String _beeBreed;
  late String _honeyType;
  late String _miteStatus;
  late String _diseaseStatus;
  late String _queenCondition;
  late String _overallHealth;
  late bool _feedingRequired;
  late DateTime _dateAdded;
  late DateTime _lastInspectionDate;

  // Dropdown Options
  final List<String> _hiveTypeOptions = [
    'Langstroth',
    'Top-Bar',
    'Warre',
    'Flow Hive',
    'Dadant',
    'Hexagon',
  ];

  final List<String> _queenStatusOptions = [
    'Mated',
    'Virgin',
    'Missing',
    'Marked',
    'Unmarked',
    'Re-queened',
  ];

  final List<String> _colonyStrengthOptions = [
    'Strong',
    'Moderate',
    'Weak',
    'Very Weak',
  ];

  final List<String> _beeBreedOptions = [
    'Italian',
    'Carniolan',
    'Caucasian',
    'Buckfast',
    'Russian',
    'Local Hybrid',
  ];

  final List<String> _honeyTypeOptions = [
    'Wildflower',
    'Clover',
    'Acacia',
    'Orange Blossom',
    'Manuka',
    'Eucalyptus',
    'Polyfloral',
  ];

  final List<String> _miteStatusOptions = [
    'Low',
    'Medium',
    'High',
    'Treated',
  ];

  final List<String> _diseaseStatusOptions = [
    'None',
    'AFB',
    'EFB',
    'Nosema',
    'Chalkbrood',
  ];

  final List<String> _queenConditionOptions = [
    'Excellent',
    'Good',
    'Fair',
    'Poor',
  ];

  final List<String> _overallHealthOptions = [
    'Healthy',
    'Needs Attention',
    'Critical',
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.hive;

    _nameController = TextEditingController(text: h?.name ?? '');
    _hiveCodeController = TextEditingController(text: h?.hiveCode ?? '');
    _apiaryLocationController = TextEditingController(text: h?.apiaryLocation ?? '');
    _totalFramesController = TextEditingController(text: h != null ? h.totalFrames.toString() : '10');
    _broodFramesController = TextEditingController(text: h != null ? h.broodFrames.toString() : '');
    _queenAgeMonthsController = TextEditingController(text: h != null ? h.queenAgeMonths.toString() : '');
    _expectedProductionController =
        TextEditingController(text: h != null ? h.expectedProductionKg.toString() : '');
    _previousYearProductionController =
        TextEditingController(text: h != null ? h.previousYearProductionKg.toString() : '');
    _currentYearProductionController =
        TextEditingController(text: h != null ? h.currentYearProductionKg.toString() : '');
    _notesController = TextEditingController(text: h?.notes ?? '');

    _hiveType = h?.hiveType ?? _hiveTypeOptions.first;
    _queenStatus = h?.queenStatus ?? _queenStatusOptions.first;
    _colonyStrength = h?.colonyStrength ?? _colonyStrengthOptions.first;
    _beeBreed = h?.beeBreed ?? _beeBreedOptions.first;
    _honeyType = h?.honeyType ?? _honeyTypeOptions.first;
    _miteStatus = h?.miteStatus ?? _miteStatusOptions.first;
    _diseaseStatus = h?.diseaseStatus ?? _diseaseStatusOptions.first;
    _queenCondition = h?.queenCondition ?? _queenConditionOptions.first;
    _overallHealth = h?.overallHealth ?? _overallHealthOptions.first;
    _feedingRequired = h?.feedingRequired ?? false;
    _dateAdded = h?.dateAdded ?? DateTime.now();
    _lastInspectionDate = h?.lastInspectionDate ?? DateTime.now();

    // Fetch authoritative unique hive code from backend if adding new hive
    if (h == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final code = await context.read<HiveController>().fetchAuthoritativeHiveCode();
        if (mounted && code != null && _hiveCodeController.text.trim().isEmpty) {
          setState(() {
            _hiveCodeController.text = code;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hiveCodeController.dispose();
    _apiaryLocationController.dispose();
    _totalFramesController.dispose();
    _broodFramesController.dispose();
    _queenAgeMonthsController.dispose();
    _expectedProductionController.dispose();
    _previousYearProductionController.dispose();
    _currentYearProductionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isDateAdded) async {
    final initial = isDateAdded ? _dateAdded : _lastInspectionDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: context.textPrimaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isDateAdded) {
          _dateAdded = picked;
        } else {
          _lastInspectionDate = picked;
        }
      });
    }
  }

  Future<void> _saveHive() async {
    if (!ProfileGuard.checkHarvesterVerificationOrPrompt(context)) return;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required hive details correctly before saving.'),
          backgroundColor: AppConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isSaving) return;

    final userController = context.read<UserController>();
    setState(() => _isSaving = true);

    final controller = context.read<HiveController>();
    final code = _hiveCodeController.text.trim();

    // Check if code is already used in local state
    if (code.isNotEmpty && controller.isHiveCodeTaken(code, excludingHiveId: widget.hive?.id)) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hive code "$code" is already in use. Please choose another.'),
          backgroundColor: AppConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final isEditing = widget.hive != null;

    final hiveData = Hive(
      id: isEditing ? widget.hive!.id : '', // Let backend assign UUID for new hives
      userId: userController.user.id,
      name: _nameController.text.trim(),
      hiveCode: _hiveCodeController.text.trim(),
      apiaryLocation: _apiaryLocationController.text.trim(),
      hiveType: _hiveType,
      dateAdded: _dateAdded,
      queenStatus: _queenStatus,
      totalFrames: int.tryParse(_totalFramesController.text.trim()) ?? 10,
      broodFrames: int.tryParse(_broodFramesController.text.trim()) ?? 0,
      colonyStrength: _colonyStrength,
      queenAgeMonths: int.tryParse(_queenAgeMonthsController.text.trim()) ?? 0,
      beeBreed: _beeBreed,
      expectedProductionKg:
          double.tryParse(_expectedProductionController.text.trim()) ?? 0.0,
      previousYearProductionKg:
          double.tryParse(_previousYearProductionController.text.trim()) ?? 0.0,
      currentYearProductionKg:
          double.tryParse(_currentYearProductionController.text.trim()) ?? 0.0,
      honeyType: _honeyType,
      lastInspectionDate: _lastInspectionDate,
      miteStatus: _miteStatus,
      diseaseStatus: _diseaseStatus,
      feedingRequired: _feedingRequired,
      queenCondition: _queenCondition,
      overallHealth: _overallHealth,
      notes: _notesController.text.trim(),
      updatedAt: now,
    );

    bool success;
    if (isEditing) {
      success = await controller.updateHive(hiveData, userId: userController.user.id);
    } else {
      success = await controller.addHive(hiveData, userId: userController.user.id);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Hive updated successfully' : 'Hive added successfully',
          ),
          backgroundColor: AppConstants.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save hive data. Please verify your profile and try again.'),
          backgroundColor: AppConstants.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.hive != null;
    final dateFormat = DateFormat('MMM dd, yyyy');

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
                  const _PillBackButton(),
                  const SizedBox(width: 14),
                  Text(
                    isEditing ? context.tr('edit_hive') : context.tr('add_new_hive'),
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
                key: _formKey,        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Basic Information Section
              _buildSectionHeader(context.tr('basic_info'), Icons.info_outline_rounded),
              _buildCardContainer([
                _buildTextField(
                  label: '${context.tr('hive_name')} *',
                  hint: 'e.g. Hive Alpha',
                  controller: _nameController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter hive name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.space16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: '${context.tr('hive_code')} *',
                        hint: 'e.g. HIVE-A1B2C3',
                        controller: _hiveCodeController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter hive code';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildDropdown(
                        label: context.tr('hive_type'),
                        value: _hiveType,
                        items: _hiveTypeOptions,
                        onChanged: (val) => setState(() => _hiveType = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space16),
                _buildTextField(
                  label: '${context.tr('apiary_location')} *',
                  hint: 'e.g. Main Apiary, Meadow Field',
                  controller: _apiaryLocationController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter apiary location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.space16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePickerTile(
                        label: context.tr('date_added'),
                        value: dateFormat.format(_dateAdded),
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildDropdown(
                        label: context.tr('queen_status'),
                        value: _queenStatus,
                        items: _queenStatusOptions,
                        onChanged: (val) => setState(() => _queenStatus = val!),
                      ),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: AppConstants.space24),

              // 2. Hive Details Section
              _buildSectionHeader(context.tr('hive_details'), Icons.widgets_outlined),
              _buildCardContainer([
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: '${context.tr('total_frames')} *',
                        hint: 'e.g. 10',
                        controller: _totalFramesController,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter total frames';
                          }
                          final parsed = int.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Must be at least 1';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildTextField(
                        label: '${context.tr('brood_frames')} *',
                        hint: 'e.g. 6',
                        controller: _broodFramesController,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter brood frames';
                          }
                          final parsed = int.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Must be 0 or more';
                          }
                          final total = int.tryParse(_totalFramesController.text.trim()) ?? 0;
                          if (total > 0 && parsed > total) {
                            return 'Max $total frames';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: context.tr('colony_strength'),
                        value: _colonyStrength,
                        items: _colonyStrengthOptions,
                        onChanged: (val) => setState(() => _colonyStrength = val!),
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildTextField(
                        label: '${context.tr('queen_age')} (months) *',
                        hint: 'e.g. 12',
                        controller: _queenAgeMonthsController,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter queen age';
                          }
                          final parsed = int.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Must be 0 or more';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space16),
                _buildDropdown(
                  label: context.tr('bee_breed'),
                  value: _beeBreed,
                  items: _beeBreedOptions,
                  onChanged: (val) => setState(() => _beeBreed = val!),
                ),
              ]),

              const SizedBox(height: AppConstants.space24),

              // 3. Production Information Section
              _buildSectionHeader(context.tr('production_info'), Icons.scale_outlined),
              _buildCardContainer([
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: '${context.tr('expected_honey')} (kg) *',
                        hint: 'e.g. 35.0',
                        controller: _expectedProductionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter expected yield';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Valid number >= 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildTextField(
                        label: '${context.tr('previous_year')} (kg) *',
                        hint: 'e.g. 25.0',
                        controller: _previousYearProductionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter previous yield';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Valid number >= 0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: '${context.tr('current_year')} (kg) *',
                        hint: 'e.g. 28.0',
                        controller: _currentYearProductionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter current yield';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Valid number >= 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildDropdown(
                        label: context.tr('honey_type'),
                        value: _honeyType,
                        items: _honeyTypeOptions,
                        onChanged: (val) => setState(() => _honeyType = val!),
                      ),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: AppConstants.space24),

              // 4. Health & Inspection Section
              _buildSectionHeader(context.tr('health_inspection'), Icons.health_and_safety_outlined),
              _buildCardContainer([
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePickerTile(
                        label: context.tr('last_inspected'),
                        value: dateFormat.format(_lastInspectionDate),
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildDropdown(
                        label: context.tr('mite_status'),
                        value: _miteStatus,
                        items: _miteStatusOptions,
                        onChanged: (val) => setState(() => _miteStatus = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: context.tr('disease_status'),
                        value: _diseaseStatus,
                        items: _diseaseStatusOptions,
                        onChanged: (val) => setState(() => _diseaseStatus = val!),
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildDropdown(
                        label: context.tr('queen_condition'),
                        value: _queenCondition,
                        items: _queenConditionOptions,
                        onChanged: (val) => setState(() => _queenCondition = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space16),
                _buildDropdown(
                  label: context.tr('overall_health'),
                  value: _overallHealth,
                  items: _overallHealthOptions,
                  onChanged: (val) => setState(() => _overallHealth = val!),
                ),
                const SizedBox(height: AppConstants.space16),
                // Feeding Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.scaffoldBg,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('feeding_required'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('feeding_sub'),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _feedingRequired,
                        activeTrackColor: context.textPrimaryColor,
                        onChanged: (val) => setState(() => _feedingRequired = val),
                      ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: AppConstants.space24),

              // 5. Additional Notes Section
              _buildSectionHeader(context.tr('additional_notes'), Icons.notes_outlined),
              _buildCardContainer([
                _buildTextField(
                  label: context.tr('notes'),
                  hint: context.tr('inspection_notes_hint'),
                  controller: _notesController,
                  maxLines: 4,
                ),
              ]),

              const SizedBox(height: AppConstants.space32),

              // Form Action Buttons (Save & Cancel)
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: context.tr('cancel'),
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppConstants.space16),
                  Expanded(
                    child: AppButton(
                      text: isEditing ? context.tr('update_hive') : context.tr('save_hive'),
                      isLoading: _isSaving,
                      variant: AppButtonVariant.primary,
                      onPressed: _saveHive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.space32),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.space8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.textPrimaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: context.borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(fontSize: 14, color: context.textPrimaryColor),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          isDense: true,
          style: TextStyle(fontSize: 14, color: context.textPrimaryColor),
          dropdownColor: context.surfaceColor,
          decoration: const InputDecoration(isDense: true),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondaryColor),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePickerTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 14, color: context.textPrimaryColor),
                ),
                Icon(Icons.calendar_month_outlined, size: 18, color: context.textSecondaryColor),
              ],
            ),
          ),
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
