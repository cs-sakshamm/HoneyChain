import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../profile/controllers/user_controller.dart';
import '../../../core/widgets/pill_back_button.dart';

/// Centre selection screen — Collection, Lab and Packaging stages.
///
/// Every card renders ONLY backend data (GET /api/centers/nearest): name,
/// location, dynamically calculated distance and license/registration
/// details. When a field was never provided by the deployment, the UI says
/// so honestly ("Not Provided" / "Distance unavailable" / "Pending
/// Verification") instead of inventing content. API failures surface an
/// error state with Retry — never demo/fallback centres.
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
      return 'Lab Testing Centres';
    } else if (widget.targetRole == 'PACKAGING') {
      return 'Packaging Centres';
    }
    return 'Collection & Processing Centres';
  }

  String get _subtitle {
    if (widget.targetRole == 'LAB') {
      return 'Select a testing laboratory for this batch. Distances are calculated from the provided coordinates.';
    } else if (widget.targetRole == 'PACKAGING') {
      return 'Select a packaging facility for this batch. Distances are calculated from the provided coordinates.';
    }
    return 'Select a collection centre for this harvest. Distances are calculated from the provided coordinates.';
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
          // Real failure (HTTP error / unreachable backend): show the error
          // state with Retry. No fallback demo centres, ever.
          _errorMessage =
              'Unable to load centres. Please check the server connection and try again.';
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
            Text(
              _distanceText(center),
              style: GoogleFonts.inter(fontSize: 12, color: context.colors.primary, fontWeight: FontWeight.w600),
            ),
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
                  quantity: widget.quantity ?? 0.0,
                  targetCollectorId: center['userId'] ?? center['id'],
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
                  qtyReceived: widget.quantity ?? 0.0,
                  qtyAfter: (widget.quantity ?? 0.0) > 0 ? (widget.quantity ?? 0.0) * 0.95 : 0.0,
                  method: widget.processingMethod ?? 'Standard Cold Extraction',
                  targetLabId: center['userId'] ?? center['id'],
                  moisture: widget.moistureLevel,
                  notes: effectiveNotes,
                  processorId: userCtrl.user.id,
                );
              } else if (widget.targetRole == 'PACKAGING') {
                success = await workflowCtrl.sendToPackaging(
                  requestId: widget.requestId ?? '',
                  batchId: widget.batchId ?? '',
                  targetPackagerId: center['userId'] ?? center['id'],
                  notes: notesCtrl.text.trim(),
                  labId: userCtrl.user.id,
                );
              }

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Request dispatched to ${center['name']}'),
                      backgroundColor: AppConstants.success,
                    ),
                  );
                  Navigator.pop(context, true);
                } else {
                  // Real failure — show the backend's own message. Never a
                  // fabricated success.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(workflowCtrl.errorMessage ??
                          'Unable to send request. Please check the server connection and try again.'),
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
                  const PillBackButton(),
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
                          'Official registered centres',
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
                      ? _buildErrorState(context)
                      : _centers.isEmpty
                          ? _buildEmptyState(context)
                          : RefreshIndicator(
                              onRefresh: _fetchCentres,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(AppConstants.space16, 8, AppConstants.space16, 100),
                                itemCount: _centers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final center = _centers[index];
                                  return _buildCentreCard(context, center);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: context.errorColor),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchCentres,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Retry', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final typeLabel = widget.targetRole == 'LAB'
        ? 'Lab Testing Centres'
        : widget.targetRole == 'PACKAGING'
            ? 'Packaging Centres'
            : 'Collection Centres';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined, size: 44, color: context.textMutedColor),
            const SizedBox(height: 12),
            Text(
              'No $typeLabel Available',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
            ),
            const SizedBox(height: 6),
            Text(
              'No registered centre exists yet. Please check back later.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
            ),
          ],
        ),
      ),
    );
  }

  String _distanceText(Map<String, dynamic> center) {
    final dynamic km = center['distanceKm'];
    if (km is num) {
      return '${km.toStringAsFixed(1)} km away';
    }
    // Coordinates missing on either end — say so, never invent a number.
    return 'Distance unavailable';
  }

  String _verificationText(Map<String, dynamic> center) {
    final v = (center['verificationStatus'] ?? '').toString();
    // Only "Verified" when the backend attests it; anything else is pending.
    return v == 'Verified' ? 'Verified' : 'Pending Verification';
  }

  Color _verificationColor(BuildContext context, Map<String, dynamic> center) {
    return _verificationText(center) == 'Verified' ? context.successColor : context.warningColor;
  }

  void _showCenterDetails(BuildContext context, Map<String, dynamic> center) {
    final verification = _verificationText(center);
    final verificationColor = _verificationColor(context, center);
    final String? licenseNumber = (center['licenseNumber'] as String?)?.trim();
    final bool hasLicense = licenseNumber != null && licenseNumber.isNotEmpty;

    String? fmtDate(dynamic iso) {
      if (iso == null || (iso as String).isEmpty) return null;
      try {
        return DateFormat('dd MMM yyyy').format(DateTime.parse(iso).toLocal());
      } catch (_) {
        return null;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                center['name'] ?? 'Centre',
                style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimaryColor),
              ),
              const SizedBox(height: 2),
              Text(
                center['typeLabel'] ?? 'Registered Centre',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.primary),
              ),
              const SizedBox(height: 12),
              _detailRow(context, 'Location', center['location'] ?? 'Not Provided'),
              _detailRow(context, 'Distance', _distanceText(center)),
              if (center['contactPhone'] != null && center['contactPhone'].toString().isNotEmpty)
                _detailRow(context, 'Contact Phone', center['contactPhone']),
              if (center['contactEmail'] != null && center['contactEmail'].toString().isNotEmpty)
                _detailRow(context, 'Contact Email', center['contactEmail']),
              const Divider(height: 24),
              Text(
                'License / Registration',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
              ),
              const SizedBox(height: 8),
              _detailRow(context, 'License / Registration ID', hasLicense ? licenseNumber : 'Not Provided'),
              _detailRow(context, 'License Type', (center['licenseType'] as String?)?.trim().isNotEmpty == true ? center['licenseType'] : 'Not Provided'),
              _detailRow(context, 'Issuing Authority', (center['issuingAuthority'] as String?)?.trim().isNotEmpty == true ? center['issuingAuthority'] : 'Not Provided'),
              _detailRow(context, 'Issue Date', fmtDate(center['issueDate']) ?? 'Not Provided'),
              _detailRow(context, 'Expiry Date', fmtDate(center['expiryDate']) ?? 'Not Provided'),
              if ((center['accreditation'] as String?)?.trim().isNotEmpty == true)
                _detailRow(context, 'Accreditation', center['accreditation']),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    verification == 'Verified' ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                    size: 16,
                    color: verificationColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Verification Status: ',
                    style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
                  ),
                  Text(
                    verification,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: verificationColor),
                  ),
                ],
              ),
              if ((center['verificationSource'] as String?)?.trim().isNotEmpty == true)
                _detailRow(context, 'Verification Source', center['verificationSource']),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12.5, color: context.textSecondaryColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentreCard(BuildContext context, Map<String, dynamic> center) {
    final distanceDisplay = _distanceText(center);
    final verification = _verificationText(center);
    final verificationColor = _verificationColor(context, center);
    final String? licenseNumber = (center['licenseNumber'] as String?)?.trim();
    final bool hasLicense = licenseNumber != null && licenseNumber.isNotEmpty;

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
                  color: context.primarySoftColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.targetRole == 'LAB'
                      ? Icons.science_outlined
                      : widget.targetRole == 'PACKAGING'
                          ? Icons.inventory_2_outlined
                          : Icons.local_shipping_outlined,
                  size: 20,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      center['name'] ?? 'Registered Centre',
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
                            center['location'] ?? 'Location not provided',
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

          // Honest status badges — no fabricated "Verified ✓".
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: verificationColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      verification == 'Verified' ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                      size: 12,
                      color: verificationColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      verification,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: verificationColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.primarySoftColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasLicense ? 'License ID: $licenseNumber' : 'License ID: Not Provided',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasLicense ? context.textPrimaryColor : context.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              // Secondary action: full centre + license details.
              OutlinedButton(
                onPressed: () => _showCenterDetails(context, center),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13, color: context.textPrimaryColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
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
                            ? 'Send Request'
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
        ],
      ),
    );
  }
}
