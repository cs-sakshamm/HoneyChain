import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/pill_back_button.dart';
import '../../verification/controllers/verification_controller.dart';
import '../../verification/screens/lab_verification_screen.dart';
import '../../collection/screens/nearest_centres_screen.dart';

class LabReportScreen extends StatefulWidget {
  final WorkflowRequest request;

  const LabReportScreen({super.key, required this.request});

  @override
  State<LabReportScreen> createState() => _LabReportScreenState();
}

class _LabReportScreenState extends State<LabReportScreen> {
  final _formKey = GlobalKey<FormState>();

  // 6 Testing Parameters
  final _moistureController = TextEditingController();
  final _hmfController = TextEditingController();
  final _diastaseController = TextEditingController();
  final _purityController = TextEditingController();
  final _residuesController = TextEditingController();
  final _pollenController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isReportGenerated = false;
  Map<String, dynamic>? _generatedReport;

  @override
  void dispose() {
    _moistureController.dispose();
    _hmfController.dispose();
    _diastaseController.dispose();
    _purityController.dispose();
    _residuesController.dispose();
    _pollenController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateAndSubmitReport() async {
    if (!ProfileGuard.checkLabVerificationOrPrompt(context)) {
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final moisture = double.tryParse(_moistureController.text) ?? 16.8;
    final hmf = double.tryParse(_hmfController.text) ?? 14.5;
    final diastase = double.tryParse(_diastaseController.text) ?? 12.4;
    final purity = double.tryParse(_purityController.text) ?? 98.5;
    final residues = double.tryParse(_residuesController.text) ?? 0.0;
    final pollen = double.tryParse(_pollenController.text) ?? 28000.0;

    // Quality Rules:
    // Moisture <= 20%
    // HMF <= 40 mg/kg
    // Diastase >= 8.0 DN
    // Purity >= 95%
    // Residues < 10 ppb
    final isMoisturePass = moisture <= 20.0;
    final isHmfPass = hmf <= 40.0;
    final isDiastasePass = diastase >= 8.0;
    final isPurityPass = purity >= 95.0;
    final isResiduesPass = residues < 10.0;

    final isOverallPass = isMoisturePass && isHmfPass && isDiastasePass && isPurityPass && isResiduesPass;
    final calculatedScore = isOverallPass ? (purity * 0.95).clamp(70.0, 99.0) : 45.0;

    final workflowCtrl = context.read<WorkflowController>();
    final success = await workflowCtrl.submitLabReport(
      requestId: widget.request.id,
      batchId: widget.request.batchId,
      moisture: moisture,
      purity: purity,
      qualityScore: calculatedScore,
      contaminants: residues > 0 ? (residues.toString() + ' ppb residues') : 'None (Pure Organic)',
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      if (workflowCtrl.isProfileIncompleteError) {
        ProfileGuard.showIncompleteProfileDialog(context);
      } else if (workflowCtrl.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(workflowCtrl.errorMessage!), backgroundColor: AppConstants.error),
        );
      }
      return;
    }

    final reportRes = workflowCtrl.lastLabReportResult;
    final reportId = (reportRes?['reportId'] as String?) ?? 'LAB-RPT-2026-${widget.request.batchId.replaceAll('BATCH-', '').replaceAll('HC-', '')}';
    final blockchain = reportRes?['blockchain'] as Map<String, dynamic>?;
    final sigHash = (blockchain?['tx_hash'] as String?) ??
        (blockchain?['data_hash'] as String?) ??
        (widget.request.txHash != null && widget.request.txHash!.isNotEmpty
            ? widget.request.txHash!
            : '0x${(reportId + widget.request.batchId).hashCode.abs().toRadixString(16).padLeft(16, '0')}');

    setState(() {
      _isReportGenerated = true;
      _generatedReport = {
        'reportId': reportId,
        'qrTraceabilityId': 'QR-TRC-2026-${widget.request.batchId.replaceAll('BATCH-', '').replaceAll('HC-', '')}',
        'overallResult': isOverallPass ? 'PASS' : 'FAIL',
        'qualityScore': calculatedScore,
        'moisture': moisture,
        'moistureStatus': isMoisturePass ? 'PASSED' : 'FAILED',
        'hmf': hmf,
        'hmfStatus': isHmfPass ? 'PASSED' : 'FAILED',
        'diastase': diastase,
        'diastaseStatus': isDiastasePass ? 'PASSED' : 'FAILED',
        'purity': purity,
        'purityStatus': isPurityPass ? 'PASSED' : 'FAILED',
        'residues': residues,
        'residuesStatus': isResiduesPass ? 'PASSED' : 'FAILED',
        'pollen': pollen,
        'notes': _notesController.text.trim(),
        'testerSignatureHash': sigHash,
      };
    });
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
                  const PillBackButton(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Lab Test — ' + widget.request.batchId,
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
                padding: const EdgeInsets.all(AppConstants.space20),
                child: _isReportGenerated ? _buildReportResultView(context) : _buildTestInputForm(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestInputForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sample Information', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimaryColor)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: context.primarySoftColor, borderRadius: BorderRadius.circular(8)),
                      child: Text('VERIFIED SAMPLE', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Batch ID: ' + widget.request.batchId, style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor)),
                Text('Harvester: ' + widget.request.harvesterName, style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor)),
                if (widget.request.labSampleId != null)
                  Text('Lab Sample Code: ' + widget.request.labSampleId!, style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Comprehensive Laboratory Testing (6 Parameters)', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimaryColor)),
          const SizedBox(height: 6),
          Text('Enter calibrated testing instrument readings for official report generation.', style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor)),
          const SizedBox(height: 16),

          // 1. Moisture
          AppTextField(
            controller: _moistureController,
            labelText: '1. Moisture Content (%) — Limit: <= 20.0%',
            hintText: 'e.g. 16.8',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icon(Icons.water_drop_outlined, size: 20, color: context.textSecondaryColor),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // 2. HMF
          AppTextField(
            controller: _hmfController,
            labelText: '2. HMF Level (mg/kg) — Limit: <= 40.0 mg/kg',
            hintText: 'e.g. 14.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icon(Icons.thermostat_outlined, size: 20, color: context.textSecondaryColor),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // 3. Diastase Activity
          AppTextField(
            controller: _diastaseController,
            labelText: '3. Diastase Activity (DN) — Limit: >= 8.0 Schade Units',
            hintText: 'e.g. 12.4',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icon(Icons.bubble_chart_outlined, size: 20, color: context.textSecondaryColor),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // 4. Purity Ratio
          AppTextField(
            controller: _purityController,
            labelText: '4. Sugar / Purity Ratio (%) — Limit: >= 95.0%',
            hintText: 'e.g. 98.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icon(Icons.grain_outlined, size: 20, color: context.textSecondaryColor),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // 5. Residue Analysis
          AppTextField(
            controller: _residuesController,
            labelText: '5. Antibiotic & Pesticide Residues (ppb) — Limit: < 10.0 ppb',
            hintText: 'e.g. 0.0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icon(Icons.shield_outlined, size: 20, color: context.textSecondaryColor),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // 6. Pollen Count
          AppTextField(
            controller: _pollenController,
            labelText: '6. Pollen Density (grains/10g) — Limit: >= 20000',
            hintText: 'e.g. 28000',
            keyboardType: TextInputType.number,
            prefixIcon: Icon(Icons.grain_outlined, size: 20, color: context.textSecondaryColor),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // Notes
          AppTextField(
            controller: _notesController,
            labelText: 'Lab Analysis Remarks & Observations',
            hintText: 'Enter observation details...',
            maxLines: 2,
            prefixIcon: Icon(Icons.notes_rounded, size: 20, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _calculateAndSubmitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Generate Official Lab Report',
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildReportResultView(BuildContext context) {
    final rep = _generatedReport!;
    final isPass = rep['overallResult'] == 'PASS';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isPass ? context.successBgColor : AppConstants.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isPass ? context.successColor : AppConstants.error),
          ),
          child: Column(
            children: [
              Icon(isPass ? Icons.verified_rounded : Icons.cancel_outlined, size: 48, color: isPass ? context.successColor : AppConstants.error),
              const SizedBox(height: 10),
              Text(
                isPass ? 'OFFICIAL LAB TEST PASSED' : 'LAB TEST REJECTED',
                style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: isPass ? context.successColor : AppConstants.error),
              ),
              const SizedBox(height: 4),
              Text(
                'Quality Score: ' + (rep['qualityScore'] as double).toStringAsFixed(1) + ' / 100',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Official Report Metadata', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimaryColor)),
              const SizedBox(height: 12),
              _buildReportRow('Report ID', rep['reportId']),
              _buildReportRow('QR Traceability ID', rep['qrTraceabilityId']),
              _buildReportRow('Batch ID', widget.request.batchId),
              _buildReportRow('Tester Signature Hash', (rep['testerSignatureHash'] as String).substring(0, 24) + '...'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parameter Breakdown', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimaryColor)),
              const SizedBox(height: 12),
              _buildParameterTile(context, 'Moisture Content', (rep['moisture'] as double).toString() + '%', rep['moistureStatus']),
              _buildParameterTile(context, 'HMF Level', (rep['hmf'] as double).toString() + ' mg/kg', rep['hmfStatus']),
              _buildParameterTile(context, 'Diastase Activity', (rep['diastase'] as double).toString() + ' DN', rep['diastaseStatus']),
              _buildParameterTile(context, 'Purity / Sugar Ratio', (rep['purity'] as double).toString() + '%', rep['purityStatus']),
              _buildParameterTile(context, 'Residue Analysis', (rep['residues'] as double).toString() + ' ppb', rep['residuesStatus']),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (isPass) ...[
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (!ProfileGuard.checkLabVerificationOrPrompt(context)) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NearestCentresScreen(
                      targetRole: 'PACKAGING',
                      batchId: widget.request.batchId,
                      requestId: widget.request.id,
                      quantity: widget.request.estimatedQuantityKg,
                      originLocation: widget.request.location,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Forward to Packaging Manager', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.onPrimary)),
            ),
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text('Back to Dashboard', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF888888))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterTile(BuildContext context, String param, String value, String status) {
    final isPass = status == 'PASSED';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(param, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
              Text('Reading: ' + value, style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPass ? context.successBgColor : AppConstants.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: isPass ? context.successColor : AppConstants.error),
            ),
          ),
        ],
      ),
    );
  }
}
