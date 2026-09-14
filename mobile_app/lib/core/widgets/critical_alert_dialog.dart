import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/hive_alert_model.dart';
import '../theme/app_theme.dart';

/// Senior Product Design Critical Alert Modal Popup
/// Non-dismissible barrier with loud amber-red warning theme, parameter delta analysis, and prominent OK button.
class CriticalAlertDialog extends StatelessWidget {
  final HiveAlertModel alert;
  final VoidCallback onAcknowledge;

  const CriticalAlertDialog({
    super.key,
    required this.alert,
    required this.onAcknowledge,
  });

  String _formatDetectedTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // Prevent physical or gesture back dismiss
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const Duration().inMilliseconds == 0 ? const BoxConstraints(maxWidth: 420) : null,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppConstants.error.withValues(alpha: isDark ? 0.6 : 0.8),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppConstants.error.withValues(alpha: isDark ? 0.35 : 0.20),
                blurRadius: 28,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Warning Header Banner
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                decoration: BoxDecoration(
                  color: AppConstants.error.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(
                    bottom: BorderSide(
                      color: AppConstants.error.withValues(alpha: 0.2),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConstants.error.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppConstants.error,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CRITICAL HIVE ALERT',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppConstants.error,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sudden change detected in ${alert.hiveCode.isNotEmpty ? alert.hiveCode : "Hive"}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Parameter Details Matrix
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Parameter Name Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Parameter:',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondaryColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.primarySoftColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Text(
                            alert.parameter,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Values Comparison Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.scaffoldBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildValueRow(
                            context,
                            label: 'Previous Value:',
                            value: alert.previousValue.isNotEmpty ? alert.previousValue : '--',
                            color: context.textSecondaryColor,
                          ),
                          const Divider(height: 16, thickness: 0.8),
                          _buildValueRow(
                            context,
                            label: 'Current Value:',
                            value: alert.currentValue,
                            color: AppConstants.error,
                            isBold: true,
                          ),
                          const Divider(height: 16, thickness: 0.8),
                          _buildValueRow(
                            context,
                            label: 'Change:',
                            value: alert.changeValue,
                            color: AppConstants.error,
                            isBadge: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Detected Timestamp
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: context.textSecondaryColor),
                        const SizedBox(width: 6),
                        Text(
                          'Detected: ${_formatDetectedTime(alert.detectedAt)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Urgent Instruction Callout
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppConstants.warningBackground.withValues(alpha: isDark ? 0.12 : 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppConstants.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: AppConstants.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please check the hive immediately.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Prominent Unignorable [ OK ] Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        key: const Key('critical_alert_ok_button'),
                        onPressed: onAcknowledge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.honeyAccent,
                          foregroundColor: AppConstants.onPrimary,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'OK',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
    bool isBadge = false,
  }) {
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
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppConstants.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppConstants.error,
              ),
            ),
          )
        else
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
      ],
    );
  }
}
