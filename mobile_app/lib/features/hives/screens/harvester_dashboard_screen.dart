import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/my_requests_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../collection/screens/batch_timeline_screen.dart';
import '../../profile/controllers/user_controller.dart';
import '../../verification/controllers/verification_controller.dart';
import '../../verification/screens/harvester_verification_screen.dart';
import '../../verification/screens/verification_certificate_screen.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import 'add_edit_hive_screen.dart';
import 'hive_details_screen.dart';

/// Harvester Home — greeting, hive overview with real data, Add Hive action,
/// identity card, and recent collection requests. No fake telemetry.
class HarvesterDashboardScreen extends StatefulWidget {
  const HarvesterDashboardScreen({super.key});

  @override
  State<HarvesterDashboardScreen> createState() => _HarvesterDashboardScreenState();
}

class _HarvesterDashboardScreenState extends State<HarvesterDashboardScreen> {
  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.tr('greeting_morning');
    if (hour < 17) return context.tr('greeting_afternoon');
    return context.tr('greeting_evening');
  }

  void _openAddHive() {
    final userCtrl = context.read<UserController>();
    if (!userCtrl.user.isProfileComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('complete_profile_first'))),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditHiveScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final workflowController = context.watch<WorkflowController>();
    final hiveController = context.watch<HiveController>();

    final user = userController.user;
    final harvesterName = user.name.isEmpty ? 'Harvester' : user.name;
    final activeRequests = workflowController.pendingCollectionRequests.length;
    final hives = hiveController.hives;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting — localized time-of-day text (fixes hardcoded label)
                  Text(
                    _greeting(context),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: context.textSecondaryColor,
                    ),
                  ),
                  Text(
                    harvesterName,
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: AppConstants.space24),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: context.tr('total_hives'),
                          value: hives.length.toString(),
                          icon: Icons.hive_rounded,
                        ),
                      ),
                      const SizedBox(width: AppConstants.space16),
                      Expanded(
                        child: _StatCard(
                          title: context.tr('active_requests'),
                          value: activeRequests.toString(),
                          icon: Icons.pending_actions_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.space16),

                  // Add Hive CTA — functional, navigates to the dedicated page
                  _AddHiveCard(onTap: _openAddHive),

                  const SizedBox(height: AppConstants.space16),

                  // Harvester identity (issued once, persisted)
                  _IdentityCard(),

                  const SizedBox(height: AppConstants.space24),

                  // My Hives
                  Text(
                    context.tr('recent_hives'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: AppConstants.space12),

                  if (hives.isEmpty)
                    _HiveEmptyState(onAddHive: _openAddHive)
                  else
                    ...hives.take(3).map((hive) => _HiveInfoCard(hive: hive)),

                  const SizedBox(height: AppConstants.space24),

                  // Recent requests header with View All button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('recent_requests'),
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      if (workflowController.allRequests.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  backgroundColor: context.scaffoldBg,
                                  appBar: AppBar(
                                    title: Text('My Workflow Requests', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                                    backgroundColor: context.surfaceColor,
                                    elevation: 0,
                                  ),
                                  body: const MyRequestsView(userRole: 'HARVESTER'),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'View All (${workflowController.allRequests.length})',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.space12),
                ],
              ),
            ),
          ),

          if (workflowController.allRequests.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.space24),
                child: _RequestsEmptyState(),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final sortedRequests = List<WorkflowRequest>.from(workflowController.allRequests)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  final request = sortedRequests[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.space24, vertical: 8),
                    child: AppCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BatchTimelineScreen(batchId: request.batchId),
                          ),
                        );
                      },
                      padding: const EdgeInsets.all(AppConstants.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Batch ${request.batchId}',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              StatusBadge(status: request.status),
                            ],
                          ),
                          const SizedBox(height: AppConstants.space12),
                          Row(
                            children: [
                              Icon(Icons.monitor_weight_outlined, size: 16, color: context.textSecondaryColor),
                              const SizedBox(width: 8),
                              Text(
                                '${request.estimatedQuantityKg.toStringAsFixed(1)} kg',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                              const SizedBox(width: AppConstants.space16),
                              Icon(Icons.location_on_outlined, size: 16, color: context.textSecondaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  request.location,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: context.textSecondaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.timeline_rounded, size: 14, color: context.colors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to view live timeline & blockchain state',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: workflowController.allRequests.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 120), // clear the floating bottom nav
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.primarySoftColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderColor),
                ),
                child: Icon(icon, size: 16, color: context.textPrimaryColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Add Hive call-to-action card — honey accent, functional navigation.
class _AddHiveCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddHiveCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.primary,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.onPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, size: 22, color: context.colors.onPrimary),
              ),
              const SizedBox(width: AppConstants.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('add_hive'),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('create_manage_hive'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.colors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 20, color: context.colors.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Harvester identity & verification status card with direct navigation to
/// the 5-parameter verification workflow.
class _IdentityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final verCtrl = context.watch<VerificationController>();
    final ver = verCtrl.verification;
    final isVerified = ver.isFullyVerified;

    final badgeColor = isVerified
        ? context.successColor
        : ver.completedStepsCount > 0
            ? context.primaryColor
            : context.textMutedColor;

    final badgeBg = isVerified
        ? context.successBgColor
        : context.primarySoftColor;

    final statusLabel = isVerified
        ? 'Verified ✓'
        : ver.completedStepsCount > 0
            ? '${ver.completedStepsCount}/5 Steps'
            : 'Not Verified';

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified ? context.successColor.withValues(alpha: 0.35) : context.borderColor,
          width: isVerified ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (isVerified) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VerificationCertificateScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HarvesterVerificationScreen()),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.space16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isVerified ? context.successBgColor : context.primarySoftColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isVerified ? context.successColor.withValues(alpha: 0.2) : context.borderColor,
                    ),
                  ),
                  child: Icon(
                    isVerified ? Icons.verified_rounded : Icons.shield_outlined,
                    size: 20,
                    color: isVerified ? context.successColor : context.textPrimaryColor,
                  ),
                ),
                const SizedBox(width: AppConstants.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Harvester Verification',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVerified
                            ? '${ver.verificationId} · Blockchain Recorded'
                            : '5 Parameters · Complete to unlock blockchain badge',
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
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: context.textMutedColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HiveInfoCard extends StatelessWidget {
  final Hive hive;

  const _HiveInfoCard({required this.hive});

  @override
  Widget build(BuildContext context) {
    final healthy = hive.isHealthy;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.space12),
      child: Material(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HiveDetailsScreen(hiveId: hive.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.space16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.primarySoftColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Icon(Icons.hive_outlined, color: context.textPrimaryColor, size: 22),
                ),
                const SizedBox(width: AppConstants.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hive.name,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hive.hiveCode} · ${hive.apiaryLocation}',
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
                    color: healthy ? context.successBgColor : context.warningBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hive.overallHealth,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: healthy ? context.successColor : context.warningColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HiveEmptyState extends StatelessWidget {
  final VoidCallback onAddHive;

  const _HiveEmptyState({required this.onAddHive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.hive_outlined, size: 40, color: context.textMutedColor),
          const SizedBox(height: AppConstants.space12),
          Text(
            context.tr('no_hives_yet'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('no_hives_subtitle'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: context.textMutedColor),
          const SizedBox(height: AppConstants.space12),
          Text(
            context.tr('no_requests_yet'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Collection requests you create will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
