import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// One selectable white status pill (e.g. "Request · 3").
///
/// Light mode: pure-white surface with a subtle border + elevation.
/// Dark mode: zinc-900 surface with a translucent white border — the same
/// visual hierarchy adapted to the HoneyChain dark theme.
class StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const StatusPill({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark
        ? AppConstants.honeyAccent.withValues(alpha: 0.14)
        : AppConstants.honeyAccent.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : context.surfaceColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? AppConstants.honeyAccent
                  : (isDark ? Colors.white.withValues(alpha: 0.14) : context.borderColor),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppConstants.honeyAccent : context.textMutedColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppConstants.honeyAccent
                      : (isDark ? Colors.white.withValues(alpha: 0.08) : context.scaffoldBg),
                  borderRadius: BorderRadius.circular(999),
                  border: isSelected
                      ? null
                      : Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : context.borderColor),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppConstants.onPrimary : context.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One expandable primary section: a single primary pill that, when tapped,
/// reveals ONLY its own related status pills with a smooth size/fade animation.
class ExpandablePillSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final List<(String, int)> statuses; // (label, count) — exactly the 3 related statuses
  final int? selectedStatusIndex;
  final ValueChanged<int?> onStatusSelected;
  final Widget? content; // request list for the currently selected status

  const ExpandablePillSection({
    super.key,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.statuses,
    required this.selectedStatusIndex,
    required this.onStatusSelected,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount =
        statuses.fold<int>(0, (sum, s) => sum + s.$2);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.space12),
      padding: const EdgeInsets.all(AppConstants.space12),
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: expanded
              ? AppConstants.honeyAccent.withValues(alpha: 0.45)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : context.borderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Primary pill ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: expanded
                        ? AppConstants.honeyAccent
                        : (isDark ? Colors.white.withValues(alpha: 0.14) : context.borderColor),
                    width: expanded ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: AppConstants.honeyAccent),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : context.primarySoftColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$totalCount',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Expandable status pills (only this section's own 3 statuses) ──
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppConstants.space12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppConstants.space8,
                          runSpacing: AppConstants.space8,
                          children: [
                            for (var i = 0; i < statuses.length; i++)
                              StatusPill(
                                label: statuses[i].$1,
                                count: statuses[i].$2,
                                isSelected: selectedStatusIndex == i,
                                onTap: () => onStatusSelected(selectedStatusIndex == i ? null : i),
                              ),
                          ],
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: content != null
                              ? Padding(
                                  key: ValueKey(selectedStatusIndex),
                                  padding: const EdgeInsets.only(top: AppConstants.space12),
                                  child: content,
                                )
                              : const SizedBox.shrink(key: ValueKey('empty')),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
