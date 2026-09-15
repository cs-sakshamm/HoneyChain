import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_guard.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import 'add_edit_hive_screen.dart';
import 'start_harvesting_screen.dart';
import '../../../core/controllers/telemetry_alert_controller.dart';

/// Clean, Minimal Field Overview & Harvest Details Screen
class HiveDetailsScreen extends StatelessWidget {
  final String hiveId;

  const HiveDetailsScreen({
    super.key,
    required this.hiveId,
  });

  void _showDeleteDialog(BuildContext context, Hive hive) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(
            dialogContext.tr('delete_confirm_title'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          content: Text(
            '${dialogContext.tr('delete_confirm_msg')} ("${hive.name}")',
            style: GoogleFonts.inter(fontSize: 14, color: dialogContext.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('cancel'), style: GoogleFonts.inter(color: dialogContext.textSecondaryColor)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final controller = context.read<HiveController>();
                final success = await controller.deleteHive(hive.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? context.tr('hive_deleted') : context.tr('failed_to_delete_hive'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: Text(
                dialogContext.tr('delete_hive'),
                style: GoogleFonts.manrope(color: AppConstants.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HiveController>();
    final hive = controller.getHiveById(hiveId);

    if (hive == null) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _PillBackButton(),
                ),
              ),
              Expanded(child: Center(child: Text(context.tr('no_matching_hives')))),
            ],
          ),
        ),
      );
    }

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
                  const Spacer(),
                  Material(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddEditHiveScreen(hive: hive),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.borderColor),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(Icons.edit_outlined, size: 20, color: context.primaryDarkColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppConstants.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => _showDeleteDialog(context, hive),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppConstants.error.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 20, color: AppConstants.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    hive.name,
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${hive.hiveCode} • ${hive.hiveType} • ${hive.totalFrames} Frames',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: context.textSecondaryColor,
                    ),
                  ),

                  const SizedBox(height: AppConstants.space20),

                  // 1. Hive Specifications
                  Text(
                    'Hive Specifications',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(AppConstants.space16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildRowItem(context, 'Hive Code', hive.hiveCode),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Hive Type', hive.hiveType),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Bee Breed', hive.beeBreed),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Colony Strength', hive.colonyStrength),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Honey Type', hive.honeyType),
                        const Divider(height: 16),
                        _buildRowItem(
                          context,
                          'Brood Frames',
                          hive.broodFrames > 0
                              ? '${hive.broodFrames} / ${hive.totalFrames}'
                              : '0 / ${hive.totalFrames}',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.space20),

                  // 2. Production Information
                  Text(
                    'Production Information',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(AppConstants.space16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildRowItem(
                          context,
                          'Expected Production',
                          hive.expectedProductionKg > 0
                              ? '${hive.expectedProductionKg.toStringAsFixed(1)} kg'
                              : 'Not recorded',
                        ),
                        const Divider(height: 16),
                        _buildRowItem(
                          context,
                          'Current Season Yield',
                          hive.currentYearProductionKg > 0
                              ? '${hive.currentYearProductionKg.toStringAsFixed(1)} kg'
                              : '0.0 kg (No harvest yet)',
                        ),
                        const Divider(height: 16),
                        _buildRowItem(
                          context,
                          'Previous Season Yield',
                          hive.previousYearProductionKg > 0
                              ? '${hive.previousYearProductionKg.toStringAsFixed(1)} kg'
                              : 'No prior record',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.space20),

                  // 3. Health & Inspection Status
                  Text(
                    'Health & Inspection',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(AppConstants.space16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildRowItem(context, 'Overall Health', hive.overallHealth),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Queen Status', '${hive.queenStatus} (${hive.queenCondition})'),
                        const Divider(height: 16),
                        _buildRowItem(
                          context,
                          'Queen Age',
                          hive.queenAgeMonths > 0 ? '${hive.queenAgeMonths} months' : 'Not recorded',
                        ),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Mite Status', hive.miteStatus.isNotEmpty ? hive.miteStatus : 'None'),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Disease Status', hive.diseaseStatus.isNotEmpty ? hive.diseaseStatus : 'None'),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Feeding Required', hive.feedingRequired ? 'Yes' : 'No'),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Last Inspected', '${hive.lastInspectionDate.day}/${hive.lastInspectionDate.month}/${hive.lastInspectionDate.year}'),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Next Inspection Due', '${hive.nextInspectionDate.day}/${hive.nextInspectionDate.month}/${hive.nextInspectionDate.year}'),
                        if (hive.notes.trim().isNotEmpty) ...[
                          const Divider(height: 16),
                          _buildRowItem(context, 'Notes', hive.notes.trim()),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.space20),

                  // 2. Location Section (Map Preview)
                  Text(
                    context.tr('location'),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
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
                          hive.apiaryLocation,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: context.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 80,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: context.scaffoldBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on_outlined, size: 20, color: context.primaryDarkColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hive.apiaryLocation.isNotEmpty
                                        ? 'Registered Apiary Location: ${hive.apiaryLocation}'
                                        : 'No GPS coordinates recorded',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: context.textSecondaryColor,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.space20),

                  // 3. Harvest History Timeline
                  Text(
                    context.tr('harvest_history'),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final workflowCtrl = context.watch<WorkflowController>();
                      final hiveRequests = workflowCtrl.harvesterRequests
                          .where((r) =>
                              (hive.apiaryLocation.isNotEmpty && r.location.toLowerCase().contains(hive.apiaryLocation.toLowerCase())) ||
                              (hive.hiveCode.isNotEmpty && (r.notes.contains(hive.hiveCode) || r.batchId.contains(hive.hiveCode))))
                          .toList();

                      if (hiveRequests.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppConstants.space16),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppConstants.space12),
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 28, color: context.textMutedColor),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No records found',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'No harvest records logged yet for this hive.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: context.textSecondaryColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppConstants.space16),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < hiveRequests.length; i++) ...[
                              if (i > 0) const Divider(height: 20),
                              _buildHistoryRow(
                                context,
                                title: 'Batch ${hiveRequests[i].batchId} (${hiveRequests[i].estimatedQuantityKg.toStringAsFixed(1)} kg)',
                                time: '${hiveRequests[i].status.name.toUpperCase()} · ${_formatDate(hiveRequests[i].createdAt)}',
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: AppConstants.space24),

                  // 4. Telemetry History Section
                  Text(
                    'Live Telemetry & Sensors',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TelemetryHistorySection(hiveId: hive.id),

                  const SizedBox(height: AppConstants.space24),
                ],
              ),
            ),
          ),

          // 4. Fixed CTA: Resume Harvest
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(top: BorderSide(color: context.borderColor)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (!ProfileGuard.checkOrPrompt(context)) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StartHarvestingScreen(hive: hive),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  ),
                ),
                child: Text(
                  context.tr('resume_harvest'),
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRowItem(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.textSecondaryColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(BuildContext context, {required String title, required String time}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: context.textMutedColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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

class _TelemetryHistorySection extends StatefulWidget {
  final String hiveId;
  const _TelemetryHistorySection({required this.hiveId});

  @override
  State<_TelemetryHistorySection> createState() => _TelemetryHistorySectionState();
}

class _TelemetryHistorySectionState extends State<_TelemetryHistorySection> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final ctrl = context.read<TelemetryAlertController>();
    final data = await ctrl.fetchHiveTelemetry(widget.hiveId);
    if (mounted) {
      setState(() {
        _history = data;
        _isLoading = false;
      });
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    
    if (_history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.space16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.sensors_off_rounded, size: 28, color: context.textMutedColor),
            const SizedBox(height: 8),
            Text(
              'No Sensor Data',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Telemetry data not available for this hive yet.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Time', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              Text('Temp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              Text('Hum', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              Text('Weight', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
            ],
          ),
          const Divider(height: 16),
          ..._history.take(7).map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(flex: 3, child: Text(_formatTime(entry['recordedAt']), style: GoogleFonts.inter(fontSize: 12, color: context.textPrimaryColor))),
                  Expanded(flex: 2, child: Text('${entry['temperature']}°C', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimaryColor), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('${entry['humidity']}%', style: GoogleFonts.inter(fontSize: 12, color: context.textPrimaryColor), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('${entry['weightKg']}kg', style: GoogleFonts.inter(fontSize: 12, color: context.textPrimaryColor), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

