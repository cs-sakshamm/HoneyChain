import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../profile/controllers/user_controller.dart';

class NearestCentresScreen extends StatefulWidget {
  final String targetRole; // 'COLLECTOR_PROCESSOR', 'LAB', or 'PACKAGING'
  final String? originLocation;
  final String? originHiveId;
  final String? batchId;
  final String? requestId;
  final double? quantity;
  final String? harvesterName;
  final String? processingMethod;
  final double? moistureLevel;
  final String? notes;

  const NearestCentresScreen({
    super.key,
    required this.targetRole,
    this.originLocation,
    this.originHiveId,
    this.batchId,
    this.requestId,
    this.quantity,
    this.harvesterName,
    this.processingMethod,
    this.moistureLevel,
    this.notes,
  });

  @override
  State<NearestCentresScreen> createState() => _NearestCentresScreenState();
}

class _NearestCentresScreenState extends State<NearestCentresScreen> {
  List<Map<String, dynamic>> _centers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCentres();
  }

  String get _pageTitle {
    if (widget.targetRole == 'LAB') {
      return 'Nearest Lab Testing Centres';
    } else if (widget.targetRole == 'PACKAGING') {
      return 'Nearest Packaging Centres';
    }
    return 'Nearest Collection & Processing Centres';
  }

  String get _subtitle {
    if (widget.targetRole == 'LAB') {
      return 'Select a certified quality testing laboratory sorted by distance from extraction.';
    } else if (widget.targetRole == 'PACKAGING') {
      return 'Select a certified bottling facility sorted by distance from the testing lab.';
    }
    return 'Select a verified extraction center sorted by nearest distance to your apiary.';
  }

  Future<void> _fetchCentres() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final workflowCtrl = context.read<WorkflowController>();
    final userCtrl = context.read<UserController>();

    try {
      final centers = await workflowCtrl.fetchNearestCenters(
        targetRole: widget.targetRole,
        originLocation: widget.originLocation,
        originHiveId: widget.originHiveId,
        batchId: widget.batchId,
        userId: userCtrl.user.id,
      );

      if (mounted) {
        setState(() {
          _centers = centers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to fetch nearest centers: $e';
        });
      }
    }
  }

  void _sendRequest(BuildContext context, Map<String, dynamic> center) {
    final defaultHint = widget.targetRole == 'COLLECTOR_PROCESSOR'
        ? 'e.g. Harvest ready for cold extraction and collection'
        : widget.targetRole == 'LAB'
            ? 'e.g. Extracted sample sent for HPLC & spectrometry testing'
            : 'e.g. Lab-certified batch sent for packaging and QR sealing';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Send Workflow Request', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target Centre: ${center['name']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimaryColor)),
            const SizedBox(height: 4),
            Text('Distance: ${center['distanceDisplay']}', style: GoogleFonts.inter(fontSize: 12, color: context.colors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('Notes / Instructions:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
            const SizedBox(height: 4),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                hintText: defaultHint,
                filled: true,
                fillColor: context.scaffoldBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final workflowCtrl = context.read<WorkflowController>();
              final userCtrl = context.read<UserController>();

              bool success = false;
              if (widget.targetRole == 'COLLECTOR_PROCESSOR') {
                success = await workflowCtrl.createHarvestAndRequest(
                  harvesterName: userCtrl.user.name.isNotEmpty ? userCtrl.user.name : 'Harvester',
                  location: widget.originLocation ?? 'Apiary',
                  quantity: widget.quantity ?? 25.0,
                  targetCollectorId: center['id'],
                  hiveId: widget.originHiveId,
                  notes: notesCtrl.text.trim(),
                );
              } else if (widget.targetRole == 'LAB') {
                final effectiveNotes = [
                  if (widget.notes != null && widget.notes!.isNotEmpty) widget.notes!,
                  if (notesCtrl.text.trim().isNotEmpty) notesCtrl.text.trim(),
                ].join(' | ');

                success = await workflowCtrl.sendToLab(
                  requestId: widget.requestId ?? '',
                  batchId: widget.batchId ?? '',
                  qtyReceived: widget.quantity ?? 25.0,
                  qtyAfter: (widget.quantity ?? 25.0) > 0 ? (widget.quantity ?? 25.0) * 0.95 : 20.0,
                  method: widget.processingMethod ?? 'Standard Cold Extraction',
                  targetLabId: center['id'],
                  moisture: widget.moistureLevel,
                  notes: effectiveNotes,
                  processorId: userCtrl.user.name,
                );
              } else if (widget.targetRole == 'PACKAGING') {
                success = await workflowCtrl.sendToPackaging(
                  requestId: widget.requestId ?? '',
                  batchId: widget.batchId ?? '',
                  targetPackagerId: center['id'],
                  notes: notesCtrl.text.trim(),
                  labId: userCtrl.user.name,
                );
              }

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Request dispatched to ${center['name']} (${center['distanceDisplay']})'),
                      backgroundColor: AppConstants.success,
                    ),
                  );
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(workflowCtrl.errorMessage ?? 'Failed to send request. Please try again.'),
                      backgroundColor: AppConstants.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Confirm & Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const _PillBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pageTitle,
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimaryColor,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Sorted by Distance (Ascending KM)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                _subtitle,
                style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(_errorMessage!, style: GoogleFonts.inter(color: AppConstants.error)),
                          ),
                        )
                      : _centers.isEmpty
                          ? Center(
                              child: Text('No verified centres found in this area.', style: GoogleFonts.inter(color: context.textSecondaryColor)),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchCentres,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(AppConstants.space16, 8, AppConstants.space16, 100),
                                itemCount: _centers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final center = _centers[index];
                                  return _buildCentreCard(context, center, index + 1);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCentreCard(BuildContext context, Map<String, dynamic> center, int rank) {
    final isFirst = rank == 1;
    final distanceDisplay = center['distanceDisplay'] ?? '${center['distanceKm']} km away';

    return AppCard(
      padding: const EdgeInsets.all(AppConstants.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isFirst ? context.colors.primary : context.primarySoftColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isFirst ? context.colors.onPrimary : context.textPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      center['name'] ?? 'Authorized Centre',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: context.textSecondaryColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            center['address'] ?? 'Oregon Region',
                            style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  distanceDisplay,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Details & badges
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.successBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 12, color: context.successColor),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Centre ✓',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: context.successColor),
                    ),
                  ],
                ),
              ),
              if (center['licenseNumber'] != null && center['licenseNumber'].toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.primarySoftColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Lic: ${center['licenseNumber']}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                  ),
                ),
            ],
          ),

          if (center['specialtyDetails'] != null && center['specialtyDetails'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              center['specialtyDetails'],
              style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _sendRequest(context, center),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    widget.targetRole == 'COLLECTOR_PROCESSOR'
                        ? 'Send Request to Centre'
                        : widget.targetRole == 'LAB'
                            ? 'Send Lab Request'
                            : 'Send Packaging Request',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
