import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class LabReportScreen extends StatefulWidget {
  final WorkflowRequest request;

  const LabReportScreen({super.key, required this.request});

  @override
  State<LabReportScreen> createState() => _LabReportScreenState();
}

class _LabReportScreenState extends State<LabReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _moistureController = TextEditingController();
  final _purityController = TextEditingController();
  final _contaminantsController = TextEditingController();
  final _qualityScoreController = TextEditingController();
  final _notesController = TextEditingController();

  /// A report may only be generated from a real data source: the batch's
  /// on-chain provenance data hash recorded when the batch was submitted.
  /// No synthetic/demo data source is ever accepted.
  bool get _hasDataSource {
    final hash = widget.request.dataHash;
    return hash != null && hash.isNotEmpty;
  }

  @override
  void dispose() {
    _moistureController.dispose();
    _purityController.dispose();
    _contaminantsController.dispose();
    _qualityScoreController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitReport() {
    if (!_formKey.currentState!.validate()) return;

    final moisture = double.tryParse(_moistureController.text) ?? 0.0;
    final purity = double.tryParse(_purityController.text) ?? 0.0;
    final score = double.tryParse(_qualityScoreController.text) ?? 0.0;

    final results = "Moisture: $moisture%, Purity: $purity%, Contaminants: ${_contaminantsController.text}";
    context.read<WorkflowController>().submitLabReport(
      widget.request.batchId,
      'Lab Technician',
      results,
      score,
      _notesController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lab report submitted successfully',
          style: GoogleFonts.inter(color: context.colors.onPrimary),
        ),
        backgroundColor: AppConstants.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
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
                  Material(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.borderColor),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(Icons.arrow_back_rounded, size: 20, color: context.textPrimaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Lab Report — ${widget.request.batchId}',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.space24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter Test Results',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space8),
                      Text(
                        'Sample ID: ${widget.request.labSampleId}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: context.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space24),
                      AppTextField(
                        controller: _moistureController,
                        labelText: 'Moisture Content (%)',
                        hintText: 'e.g. 15.5',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Must be a number';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.space16),
                      AppTextField(
                        controller: _purityController,
                        labelText: 'Purity Grade (%)',
                        hintText: 'e.g. 98.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Must be a number';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.space16),
                      AppTextField(
                        controller: _contaminantsController,
                        labelText: 'Contaminants Found',
                        hintText: 'e.g. None, Traces of pollen',
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.space16),
                      AppTextField(
                        controller: _qualityScoreController,
                        labelText: 'Quality Score (1-100)',
                        hintText: 'e.g. 95',
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          final score = double.tryParse(val);
                          if (score == null) return 'Must be a number';
                          if (score < 1 || score > 100) return 'Must be between 1 and 100';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.space16),
                      AppTextField(
                        controller: _notesController,
                        labelText: 'Lab Notes (Optional)',
                        hintText: 'Any additional observations...',
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: AppConstants.space24),
                      // Data Source Upload Section
                      Container(
                        padding: const EdgeInsets.all(AppConstants.space16),
                        decoration: BoxDecoration(
                          color: _hasDataSource ? AppConstants.success.withValues(alpha: 0.1) : context.surfaceColor,
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                          border: Border.all(
                            color: _hasDataSource ? AppConstants.success.withValues(alpha: 0.5) : context.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _hasDataSource ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                              color: _hasDataSource ? AppConstants.success : context.primaryDarkColor,
                              size: 24,
                            ),
                            const SizedBox(width: AppConstants.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _hasDataSource ? 'Data Source Verified' : 'Data Source Required',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _hasDataSource ? AppConstants.success : context.textPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    _hasDataSource
                                        ? 'On-chain batch data: ${widget.request.dataHash!.substring(0, widget.request.dataHash!.length > 20 ? 20 : widget.request.dataHash!.length)}…'
                                        : 'This batch has no on-chain provenance data yet.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_hasDataSource)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Reports can only be generated from real submitted data. Ask the harvester to record this batch on-chain first.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppConstants.error),
                          ),
                        ),
                      const SizedBox(height: AppConstants.space32),
                      AppButton(
                        text: 'Submit Lab Report',
                        variant: AppButtonVariant.primary,
                        onPressed: _hasDataSource ? _submitReport : null,
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
}
