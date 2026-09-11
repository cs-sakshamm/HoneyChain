import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../models/workflow_request.dart';

/// Consistent status badge/chip used across all role dashboards
class StatusBadge extends StatelessWidget {
  final RequestStatus status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = _statusColors(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.manrope(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  static (Color, Color) _statusColors(BuildContext context, RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
      case RequestStatus.awaitingTest:
        return (context.warningBgColor, context.warningColor);
      case RequestStatus.accepted:
      case RequestStatus.processing:
      case RequestStatus.testing:
        return (context.primarySoftColor, context.textPrimaryColor);
      case RequestStatus.denied:
      case RequestStatus.labRejected:
        return (context.errorBgColor, context.errorColor);
      case RequestStatus.labApproved:
      case RequestStatus.readyForPackaging:
      case RequestStatus.packagingApproved:
      case RequestStatus.qrGenerated:
      case RequestStatus.completed:
        return (context.successBgColor, context.successColor);
    }
  }
}
