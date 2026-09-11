import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/controllers/user_controller.dart';
import '../models/hive_model.dart';

/// Extremely Focused Operational Screen for Harvester Operator
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
  int _secondsElapsed = 2712; // Simulated initial active operational time (45m 12s)
  double _harvestedArea = 8.5;
  final double _totalArea = 12.0;

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
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _secondsElapsed++;
          if (_secondsElapsed % 20 == 0 && _harvestedArea < _totalArea) {
            _harvestedArea = (_harvestedArea + 0.1).clamp(0.0, _totalArea);
          }
        });
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
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(
            dialogContext.tr('finish_harvest'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Confirm completing harvest for ${widget.hive?.name ?? "Field A"}?',
            style: GoogleFonts.inter(fontSize: 14, color: dialogContext.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('cancel'), style: GoogleFonts.inter(color: dialogContext.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Harvest log saved successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
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
    final fieldName = widget.hive?.name ?? 'Field A';
    final cropType = widget.hive?.queenStatus.isNotEmpty == true ? widget.hive!.queenStatus : 'Wheat';

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isHarvestActive ? context.tr('harvesting_in_progress') : context.tr('start_harvest'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space20),
          child: _isHarvestActive
              ? _buildActiveHarvestView(context, fieldName, cropType)
              : _buildPreHarvestView(context, fieldName, cropType),
        ),
      ),
    );
  }

  // Pre-Harvest Screen View
  Widget _buildPreHarvestView(BuildContext context, String fieldName, String cropType) {
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
                    _buildPreItem(context, 'Field', fieldName),
                    const Divider(height: 20),
                    _buildPreItem(context, 'Crop', cropType),
                    const Divider(height: 20),
                    _buildPreItem(context, 'Area', '12 acres'),
                    const Divider(height: 20),
                    _buildPreItem(context, context.tr('machine'), context.tr('machine_ready')),
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
              context.tr('start_harvest'),
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

  Widget _buildPreItem(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  // Active Harvesting Screen View (Time, Harvested area, Area remaining, Machine)
  Widget _buildActiveHarvestView(BuildContext context, String fieldName, String cropType) {
    final areaRemaining = (_totalArea - _harvestedArea).clamp(0.0, _totalArea);

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              // Digital Operational Timer
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
                      context.tr('time'),
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
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.space16),

              // Active Metrics Box
              Container(
                padding: const EdgeInsets.all(AppConstants.space16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  children: [
                    _buildPreItem(
                      context,
                      context.tr('harvested_area'),
                      '${_harvestedArea.toStringAsFixed(1)} acres',
                    ),
                    const Divider(height: 20),
                    _buildPreItem(
                      context,
                      context.tr('area_remaining'),
                      '${areaRemaining.toStringAsFixed(1)} acres',
                    ),
                    const Divider(height: 20),
                    _buildPreItem(
                      context,
                      context.tr('machine'),
                      _isPaused ? 'Paused' : 'Active (Fuel: 72%)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Action Buttons: Pause & Finish Harvest
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isPaused = !_isPaused;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                  ),
                  child: Text(
                    _isPaused ? context.tr('resume_harvest') : context.tr('pause'),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
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
                    context.tr('finish_harvest'),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onPrimary,
                    ),
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
