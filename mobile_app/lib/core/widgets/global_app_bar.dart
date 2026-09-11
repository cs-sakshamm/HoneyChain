import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization/localization_service.dart';
import '../theme/app_theme.dart';
import 'pill_back_button.dart';

/// In-body page header used on secondary screens.
///
/// The old top navigation bar (logo + notification bell) was removed by design:
/// navigation happens through the floating pill bottom bar, and secondary pages
/// show a pill back button plus the page title inline with the content.
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final String? titleText;
  final List<Widget>? extraActions;
  final bool hasUnreadNotifications;

  const GlobalAppBar({
    super.key,
    this.showBackButton = false,
    this.titleText,
    this.extraActions,
    this.hasUnreadNotifications = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          if (showBackButton || canPop) ...[
            const PillBackButton(),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              titleText ?? '',
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
