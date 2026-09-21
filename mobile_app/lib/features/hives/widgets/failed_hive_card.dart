import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/hive_controller.dart';

/// Error card for a hive submission the backend rejected.
///
/// Shows the real backend error message associated with the specific hive
/// it belongs to — never on unrelated cards — with a Retry action and an
/// optional Dismiss. Uses the existing HoneyChain card design language.
class FailedHiveCard extends StatelessWidget {
  final FailedHiveSubmission failed;
  final VoidCallback onRetry;
  final VoidCallback? onDismiss;

  const FailedHiveCard({
    super.key,
    required this.failed,
    required this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.space12),
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.errorColor.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.errorColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.errorColor.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.error_outline_rounded, color: context.errorColor, size: 22),
              ),
              const SizedBox(width: AppConstants.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      failed.hive.name.isNotEmpty ? failed.hive.name : 'New Hive',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hive ID: ${failed.hive.hiveCode}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.errorColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Request Failed',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.errorColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.report_problem_rounded, size: 14, color: context.errorColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  failed.message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.errorColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onDismiss != null)
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    'Dismiss',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              const SizedBox(width: AppConstants.space8),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Retry', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
