import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_guard.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../../profile/controllers/user_controller.dart';
import 'nearest_centres_screen.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  String? _selectedRequestId;
  final _methodCtrl = TextEditingController();
  final _facilityCtrl = TextEditingController();
  final _moistureCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<UserController>().user;
    _facilityCtrl.text = user.facilityLocation ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final workflowCtrl = context.watch<WorkflowController>();
    final acceptedRequests = workflowCtrl.collectionAcceptedRequests;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: const GlobalAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Request to Lab',
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Process an accepted batch and select a laboratory to send it for testing.',
                style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
              ),
              const SizedBox(height: 24),
              
              Text('Select Batch', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Choose an accepted batch'),
                    value: _selectedRequestId,
                    items: acceptedRequests.map((req) {
                      return DropdownMenuItem<String>(
                        value: req.id,
                        child: Text('Batch: ${req.batchId} (${req.estimatedQuantityKg} kg)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedRequestId = val;
                      });
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              Text('Extraction Method / Details', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _methodCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Cold Extraction & Filtration',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              
              const SizedBox(height: 20),
              Text('Processing Facility', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _facilityCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter processing facility name',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              
              const SizedBox(height: 20),
              Text('Moisture Level (%)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _moistureCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g. 17.2',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),

              const SizedBox(height: 20),
              Text('Notes to Lab', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any special instructions...',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedRequestId == null ? null : () {
                    if (!ProfileGuard.checkCollectorVerificationOrPrompt(context)) return;

                    final req = acceptedRequests.firstWhere((r) => r.id == _selectedRequestId);
                    final methodText = _methodCtrl.text.trim();
                    final facilityText = _facilityCtrl.text.trim();
                    final moistureText = _moistureCtrl.text.trim();
                    final combinedMethod = [
                      if (methodText.isNotEmpty) methodText,
                      if (facilityText.isNotEmpty) 'Facility: $facilityText',
                      if (moistureText.isNotEmpty) 'Moisture: $moistureText%',
                    ].join(' | ');

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NearestCentresScreen(
                          targetRole: 'LAB',
                          batchId: req.batchId,
                          requestId: req.id,
                          quantity: req.estimatedQuantityKg,
                          originLocation: req.location,
                          processingMethod: combinedMethod.isNotEmpty ? combinedMethod : 'Cold Extraction & Centrifugation',
                          moistureLevel: double.tryParse(moistureText),
                          notes: _notesCtrl.text.trim(),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Process & Find Nearest Lab', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: context.colors.onPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
