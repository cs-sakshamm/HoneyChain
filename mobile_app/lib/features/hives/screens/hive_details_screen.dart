import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import 'add_edit_hive_screen.dart';
import 'start_harvesting_screen.dart';

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
                    '${hive.hiveType} • ${hive.totalFrames} Frames',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: context.textSecondaryColor,
                    ),
                  ),

                  const SizedBox(height: AppConstants.space20),

                  // 1. Hive Overview Section
                  Text(
                    context.tr('overview') == 'overview' ? 'Hive Overview' : context.tr('overview'),
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
                        _buildRowItem(context, 'Colony Strength', hive.colonyStrength),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Honey Type', hive.honeyType),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Expected Production', '${hive.expectedProductionKg.toStringAsFixed(1)} kg'),
                        const Divider(height: 16),
                        _buildRowItem(context, 'Overall Health', hive.overallHealth),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.space20),

                  // 7-Day Hive History Section
                  Text(
                    '7-Day Hive History',
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 32, color: context.textMutedColor),
                        const SizedBox(height: 12),
                        Text(
                          'No historical data available.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sensor and production data (temperature, humidity, weight, anomalies) will appear here once IoT devices are connected.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.textSecondaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
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
                          height: 110,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: context.scaffoldBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.map_outlined, size: 20, color: context.textMutedColor),
                                const SizedBox(width: 8),
                                Text(
                                  'GPS Map Preview (28.6139° N, 77.2090° E)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: context.textMutedColor,
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.space16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildHistoryRow(
                          context,
                          title: 'Harvest started',
                          time: 'Today · 8:42 AM',
                        ),
                        const Divider(height: 20),
                        _buildHistoryRow(
                          context,
                          title: 'Progress updated',
                          time: 'Today · 10:15 AM',
                        ),
                        const Divider(height: 20),
                        _buildHistoryRow(
                          context,
                          title: 'Harvest paused',
                          time: 'Yesterday · 5:30 PM',
                        ),
                      ],
                    ),
                  ),

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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: context.textSecondaryColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(BuildContext context, {required String title, required String time}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
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
