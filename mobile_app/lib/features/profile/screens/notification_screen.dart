import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pill_back_button.dart';

/// One notification entry. All entries are clearly-labelled DUMMY/SAMPLE data:
/// they never trigger real notifications, sounds, beeping, or backend events.
class DummyNotification {
  final String title;
  final String body;
  final DateTime time;
  final NotificationCategory category;
  final bool isUnread;

  const DummyNotification({
    required this.title,
    required this.body,
    required this.time,
    required this.category,
    this.isUnread = false,
  });
}

enum NotificationCategory { operations, alerts, identity }

/// Notification page — categorized, scannable, pill actions, both themes.
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Explicitly dummy content — replace with real backend events when wired.
    final items = <DummyNotification>[
      DummyNotification(
        title: '[Sample] Batch confirmed on-chain',
        body: 'A provenance event was recorded on the ledger.',
        time: now.subtract(const Duration(minutes: 18)),
        category: NotificationCategory.operations,
        isUnread: true,
      ),
      DummyNotification(
        title: '[Sample] Hive needs attention',
        body: 'Hive Beta: mite count slightly elevated — schedule treatment.',
        time: now.subtract(const Duration(hours: 3)),
        category: NotificationCategory.alerts,
      ),
      DummyNotification(
        title: '[Sample] Identity issued',
        body: 'BSID and BSP Pass generated for your harvester account.',
        time: now.subtract(const Duration(days: 1)),
        category: NotificationCategory.identity,
      ),
      DummyNotification(
        title: '[Sample] Inspection reminder',
        body: 'Hive Gamma is due for its 14-day inspection.',
        time: now.subtract(const Duration(days: 2)),
        category: NotificationCategory.alerts,
      ),
    ];

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppConstants.space16, AppConstants.space8, AppConstants.space24, 0),
              child: Row(
                children: [
                  const PillBackButton(),
                  const SizedBox(width: AppConstants.space12),
                  Expanded(
                    child: Text(
                      context.tr('notifications'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(AppConstants.space24, AppConstants.space4, AppConstants.space24, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.warningBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      context.tr('dummy_sample'),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.warningColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.space8),
                  Expanded(
                    child: Text(
                      'Demo content — not real events.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.textMutedColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: context.primarySoftColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Mark all read',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.primaryDarkColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.space12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppConstants.space24, 0, AppConstants.space24, 120),
                children: [
                  _buildSection(
                    context,
                    'Operations',
                    Icons.local_shipping_outlined,
                    items.where((n) => n.category == NotificationCategory.operations).toList(),
                  ),
                  _buildSection(
                    context,
                    'Alerts',
                    Icons.notification_important_outlined,
                    items.where((n) => n.category == NotificationCategory.alerts).toList(),
                  ),
                  _buildSection(
                    context,
                    'Identity',
                    Icons.badge_outlined,
                    items.where((n) => n.category == NotificationCategory.identity).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<DummyNotification> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppConstants.space8, bottom: AppConstants.space12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: context.textMutedColor),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: context.textMutedColor,
                ),
              ),
            ],
          ),
        ),
        ...items.map((n) => _buildItem(context, n)),
        const SizedBox(height: AppConstants.space12),
      ],
    );
  }

  Widget _buildItem(BuildContext context, DummyNotification n) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.space12),
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.primarySoftColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              n.category == NotificationCategory.operations
                  ? Icons.verified_outlined
                  : n.category == NotificationCategory.alerts
                      ? Icons.warning_amber_rounded
                      : Icons.badge_outlined,
              size: 18,
              color: context.primaryDarkColor,
            ),
          ),
          const SizedBox(width: AppConstants.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                    ),
                    if (n.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.body,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _timeAgo(n.time),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: context.textMutedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
