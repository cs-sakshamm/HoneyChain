import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/controllers/user_controller.dart';
import '../models/hive_model.dart';

/// Harvest Session Screen for Harvester Operator
/// Timer starts at 0 when session begins. No fake pre-seeded values.
class StartHarvestingScreen extends StatefulWidget {
  final Hive? hive;

  const StartHarvestingScreen({super.key, this.hive});

  @override
  State<StartHarvestingScreen> createState() => _StartHarvestingScreenState();
}

class _StartHarvestingScreenState extends State<StartHarvestingScreen> {
  bool _isHarvestActive = false;
  bool _isPaused = false;
  Timer? _timer;
  int _secondsElapsed = 0; // Always starts at 0 — real session time only

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _beginHarvest() {
    final userCtrl = context.read<UserController>();
    if (!userCtrl.user.isProfileComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete your profile before starting a harvest.')),
      );
      return;
    }
    setState(() {
      _isHarvestActive = true;
      _secondsElapsed = 0;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _showFinishConfirmation() {
    _timer?.cancel();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(
            context.tr('finish_harvest') == 'finish_harvest' ? 'Finish Harvest?' : context.tr('finish_harvest'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Session time: ${_formatTimer(_secondsElapsed)}. This will mark the hive session as complete.',
            style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _startTimer(); // Resume timer if dismissed
              },
              child: Text(context.tr('cancel') == 'cancel' ? 'Cancel' : context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Harvest session logged: ${_formatTimer(_secondsElapsed)}'),
                    backgroundColor: AppConstants.success,
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
              child: Text('Confirm & Save', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hive = widget.hive;
    final hiveName = hive?.name ?? 'Unknown Hive';
    final hiveType = hive?.hiveType ?? '';
    final queenStatus = hive?.queenStatus ?? '';

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header row with pill back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _PillBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _isHarvestActive
                          ? (context.tr('harvesting_in_progress') == 'harvesting_in_progress' ? 'Harvest In Progress' : context.tr('harvesting_in_progress'))
                          : (context.tr('start_harvest') == 'start_harvest' ? 'Start Harvest' : context.tr('start_harvest')),
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimaryColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.space20),
                child: _isHarvestActive
                    ? _buildActiveHarvestView(context, hiveName, queenStatus)
                    : _buildPreHarvestView(context, hiveName, hiveType, queenStatus),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pre-Harvest view with real hive data only
  Widget _buildPreHarvestView(BuildContext context, String hiveName, String hiveType, String queenStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.space20),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(context, 'Hive', hiveName),
                    if (hiveType.isNotEmpty) ...[
                      const Divider(height: 20),
                      _buildInfoRow(context, 'Type', hiveType),
                    ],
                    if (queenStatus.isNotEmpty) ...[
                      const Divider(height: 20),
                      _buildInfoRow(context, 'Queen Status', queenStatus),
                    ],
                    if (widget.hive?.colonyStrength != null) ...[
                      const Divider(height: 20),
                      _buildInfoRow(context, 'Colony Strength', '${widget.hive!.colonyStrength}/10'),
                    ],
                    if (widget.hive?.currentYearProductionKg != null && widget.hive!.currentYearProductionKg > 0) ...[
                      const Divider(height: 20),
                      _buildInfoRow(context, 'This Year', '${widget.hive!.currentYearProductionKg.toStringAsFixed(1)} kg'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _beginHarvest,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
              ),
            ),
            child: Text(
              context.tr('start_harvest') == 'start_harvest' ? 'Begin Harvest Session' : context.tr('start_harvest'),
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor)),
        Text(value, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimaryColor)),
      ],
    );
  }

  // Active harvest view — real wall-clock timer only, no fake data
  Widget _buildActiveHarvestView(BuildContext context, String hiveName, String queenStatus) {
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              // Session Timer — starts at 0:00:00 when user begins
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  children: [
                    Text(
                      'Session Time',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.textMutedColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTimer(_secondsElapsed),
                      style: GoogleFonts.manrope(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimaryColor,
                        letterSpacing: -1.0,
                      ),
                    ),
                    if (_isPaused) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.warningBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Paused',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.space16),

              // Hive info during active session
              Container(
                padding: const EdgeInsets.all(AppConstants.space16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(context, 'Hive', hiveName),
                    if (queenStatus.isNotEmpty) ...[
                      const Divider(height: 20),
                      _buildInfoRow(context, 'Queen Status', queenStatus),
                    ],
                    const Divider(height: 20),
                    _buildInfoRow(context, 'Status', _isPaused ? 'Paused' : 'Active'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Pause & Finish buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => setState(() => _isPaused = !_isPaused),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                  ),
                  child: Text(
                    _isPaused
                        ? (context.tr('resume_harvest') == 'resume_harvest' ? 'Resume' : context.tr('resume_harvest'))
                        : (context.tr('pause') == 'pause' ? 'Pause' : context.tr('pause')),
                    style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _showFinishConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                  ),
                  child: Text(
                    context.tr('finish_harvest') == 'finish_harvest' ? 'Finish' : context.tr('finish_harvest'),
                    style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.onPrimary),
                  ),
                ),
              ),
            ),
          ],
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
