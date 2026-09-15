import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/telemetry_alert_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../profile/controllers/user_controller.dart';

class CriticalAlertModalWrapper extends StatelessWidget {
  final Widget child;

  const CriticalAlertModalWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Consumer<TelemetryAlertController>(
          builder: (context, controller, _) {
            if (controller.isAlertPopupOpen && controller.activeUnacknowledgedAlert != null) {
              return Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _CriticalAlertCard(
                        alert: controller.activeUnacknowledgedAlert!,
                        onAcknowledge: () {
                          final user = context.read<UserController>().user;
                          controller.acknowledgeAlert(
                            controller.activeUnacknowledgedAlert!.id,
                            userId: (user.id != null && user.id!.isNotEmpty) ? user.id : user.email,
                            userName: user.name,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _CriticalAlertCard extends StatelessWidget {
  final dynamic alert;
  final VoidCallback onAcknowledge;

  const _CriticalAlertCard({required this.alert, required this.onAcknowledge});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppConstants.error, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppConstants.error.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, size: 48, color: AppConstants.error),
            ),
            const SizedBox(height: 16),
            Text(
              'CRITICAL HIVE ALERT',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppConstants.error,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              alert.title ?? 'Emergency Trigger',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              alert.message ?? 'An urgent event has occurred at the hive.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAcknowledge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('ACKNOWLEDGE & MUTE', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
