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

    context.read<WorkflowController>().submitLabReport(
          requestId: widget.request.id,
          moistureContent: moisture,
          purityGrade: purity,
          contaminantsFound: _contaminantsController.text,
          qualityScore: score,
          labNotes: _notesController.text,
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
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Lab Report — ${widget.request.batchId}',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: context.borderColor,
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.space16),
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
              ), // maxLines not standard param in this AppTextField, removing. Wait, it isn't in the provided signature!
              const SizedBox(height: AppConstants.space32),
              AppButton(
                text: 'Submit Lab Report',
                variant: AppButtonVariant.primary,
                onPressed: _submitReport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
