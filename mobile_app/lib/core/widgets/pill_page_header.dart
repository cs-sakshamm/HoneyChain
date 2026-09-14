import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'pill_back_button.dart';

/// In-body page header: pill back button + title. Replaces top AppBars so
/// secondary pages follow the mobile-first, bottom-nav navigation pattern.
class PillPageHeader extends StatelessWidget {
  final String title;
  final List<Widget>? extraActions;

  const PillPageHeader({super.key, required this.title, this.extraActions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const PillBackButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.textPrimaryColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (extraActions != null) ...extraActions!,
        ],
      ),
    );
  }
}
