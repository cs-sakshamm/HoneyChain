import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import '../../../core/widgets/global_app_bar.dart';

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
    _totalFramesController = TextEditingController(text: h?.totalFrames.toString() ?? '10');
    _broodFramesController = TextEditingController(text: h?.broodFrames.toString() ?? '6');
    _queenAgeMonthsController = TextEditingController(text: h?.queenAgeMonths.toString() ?? '12');
    _expectedProductionController =
        TextEditingController(text: h?.expectedProductionKg.toString() ?? '35.0');
    _previousYearProductionController =
        TextEditingController(text: h?.previousYearProductionKg.toString() ?? '25.0');
    _currentYearProductionController =
        TextEditingController(text: h?.currentYearProductionKg.toString() ?? '28.0');
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
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final isEditing = widget.hive != null;

    final hiveData = Hive(
      id: isEditing ? widget.hive!.id : 'hive_${now.millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      hiveCode: _hiveCodeController.text.trim(),
      apiaryLocation: _apiaryLocationController.text.trim(),
      hiveType: _hiveType,
      dateAdded: _dateAdded,
      queenStatus: _queenStatus,
      totalFrames: int.tryParse(_totalFramesController.text.trim()) ?? 10,
      broodFrames: int.tryParse(_broodFramesController.text.trim()) ?? 6,
      colonyStrength: _colonyStrength,
      queenAgeMonths: int.tryParse(_queenAgeMonthsController.text.trim()) ?? 12,
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

    final controller = context.read<HiveController>();
    bool success;
    if (isEditing) {
      success = await controller.updateHive(hiveData);
    } else {
      success = await controller.addHive(hiveData);
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
          content: Text('Failed to save hive data. Please try again.'),
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
      backgroundColor: AppConstants.background,
      appBar: GlobalAppBar(
        showBackButton: true,
        titleText: isEditing ? context.tr('edit_hive') : context.tr('add_new_hive'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? context.tr('hive_name') : null,
                ),
                const SizedBox(height: AppConstants.space16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: '${context.tr('hive_code')} *',
                        hint: 'e.g. H-001',
                        controller: _hiveCodeController,
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? context.tr('hive_code')
                            : null,
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
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? context.tr('apiary_location') : null,
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
                        hint: '10',
                        controller: _totalFramesController,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return context.tr('total_frames');
                          if (int.tryParse(val.trim()) == null) return context.tr('total_frames');
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildTextField(
                        label: '${context.tr('brood_frames')} *',
                        hint: '6',
                        controller: _broodFramesController,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return context.tr('brood_frames');
                          if (int.tryParse(val.trim()) == null) return context.tr('brood_frames');
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
                        label: context.tr('queen_age'),
                        hint: '12',
                        controller: _queenAgeMonthsController,
                        keyboardType: TextInputType.number,
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
                        label: context.tr('expected_honey'),
                        hint: '35.0',
                        controller: _expectedProductionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: _buildTextField(
                        label: context.tr('previous_year'),
                        hint: '25.0',
                        controller: _previousYearProductionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: context.tr('current_year'),
                        hint: '28.0',
                        controller: _currentYearProductionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    color: AppConstants.background,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                    border: Border.all(color: AppConstants.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('feeding_required'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppConstants.textPrimary,
                            ),
                          ),
                          Text(
                            context.tr('feeding_sub'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ],
                      ),
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
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppConstants.textPrimary,
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
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppConstants.border, width: 1.0),
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
          maxLines: maxLines,
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          isDense: true,
          style: const TextStyle(fontSize: 14, color: AppConstants.textPrimary),
          decoration: const InputDecoration(isDense: true),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppConstants.surface,
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              border: Border.all(color: AppConstants.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, color: AppConstants.textPrimary),
                ),
                const Icon(Icons.calendar_month_outlined, size: 18, color: AppConstants.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

