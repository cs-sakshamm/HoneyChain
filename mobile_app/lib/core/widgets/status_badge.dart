import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
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
    final (Color bg, Color fg) = _statusColors(status);

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

  static (Color, Color) _statusColors(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return (const Color(0xFFF3F4F6), const Color(0xFF4B5563)); // Gray 100 / Gray 600
      case RequestStatus.accepted:
      case RequestStatus.processing:
        return (const Color(0xFFE5E7EB), const Color(0xFF374151)); // Gray 200 / Gray 700
      case RequestStatus.denied:
      case RequestStatus.labRejected:
        return (const Color(0xFF111827), const Color(0xFFF9FAFB)); // Gray 900 / Gray 50
      case RequestStatus.awaitingTest:
      case RequestStatus.testing:
        return (const Color(0xFFE5E7EB), const Color(0xFF111827)); // Gray 200 / Gray 900
      case RequestStatus.labApproved:
      case RequestStatus.readyForPackaging:
        return (const Color(0xFF000000), const Color(0xFFFFFFFF)); // Black / White
      case RequestStatus.packagingApproved:
        return (const Color(0xFF000000), const Color(0xFFFFFFFF)); // Black / White
      case RequestStatus.qrGenerated:
      case RequestStatus.completed:
        return (const Color(0xFF000000), const Color(0xFFFFFFFF)); // Black / White
    }
  }
}
