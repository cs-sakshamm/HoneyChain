import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_guard.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../../collection/screens/nearest_centres_screen.dart';

class SendToPackagingScreen extends StatefulWidget {
  const SendToPackagingScreen({super.key});

  @override
  State<SendToPackagingScreen> createState() => _SendToPackagingScreenState();
}

class _SendToPackagingScreenState extends State<SendToPackagingScreen> {
  String? _selectedRequestId;

  @override
  Widget build(BuildContext context) {
    final workflowCtrl = context.watch<WorkflowController>();
    final completedSamples = workflowCtrl.labCompletedRequests;

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
                'Send to Packaging',
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a completely tested batch to send to a packaging facility.',
                style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
              ),
              const SizedBox(height: 32),
              
              Text('Select Certified Batch', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
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
                    hint: const Text('Choose a completed sample'),
                    value: _selectedRequestId,
                    items: completedSamples.map((req) {
                      return DropdownMenuItem<String>(
                        value: req.id,
                        child: Text('Sample: ${req.labSampleId ?? req.batchId} (${req.estimatedQuantityKg} kg)'),
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
              
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _selectedRequestId == null ? null : () {
                    if (!ProfileGuard.checkLabVerificationOrPrompt(context)) return;
                    
                    final req = completedSamples.firstWhere((r) => r.id == _selectedRequestId);
                    
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NearestCentresScreen(
                          targetRole: 'PACKAGING',
                          batchId: req.batchId,
                          requestId: req.id,
                          quantity: req.estimatedQuantityKg,
                          originLocation: req.location,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.local_shipping_rounded, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  label: Text('Find Nearest Packaging Centre', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: context.colors.onPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
