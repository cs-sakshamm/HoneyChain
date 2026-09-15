import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/telemetry_alert_controller.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/auto_image_slider.dart';
import '../../../core/widgets/critical_alert_dialog.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserController>().user;
      final userId = (user.id != null && user.id!.isNotEmpty) ? user.id! : user.email;
      if (userId.isNotEmpty) {
        context.read<VerificationController>().loadVerification(userId);
        context.read<TelemetryAlertController>().startMonitoring(userId: userId);
      }
    });
  }

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  void _openAddHive() {
    if (!ProfileGuard.checkHarvesterVerificationOrPrompt(context)) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditHiveScreen()),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return const AutoImageSlider(
      role: 'HARVESTER',
      height: 165,
      borderRadius: 20,
      margin: EdgeInsets.only(bottom: AppConstants.space20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final workflowController = context.watch<WorkflowController>();
    final hiveController = context.watch<HiveController>();
    final telemetryAlertCtrl = context.watch<TelemetryAlertController>();

    final user = userController.user;
    final beekeeperName = user.name.trim();
    final greeting = _timeBasedGreeting();
    final greetingDisplay = beekeeperName.isNotEmpty ? '$greeting, $beekeeperName 👋' : '$greeting 👋';
    
    final activeRequests = workflowController.pendingCollectionRequests.length;
    final hives = hiveController.hives;
    final criticalAlert = telemetryAlertCtrl.activeUnacknowledgedAlert;

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.space24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // 1. Natural Professional Beekeeping Hero Image directly below Top Navbar
                  _buildHeroImage(context),

                  // 2. Dynamic Time-Based Greeting
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greetingDisplay,
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimaryColor,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Overview of your apiary, identity, and honey collection.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.space20),

                  // 3. Real Beekeeper Information & Identity
                  _IdentityCard(),

                  const SizedBox(height: AppConstants.space16),

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

                  const SizedBox(height: AppConstants.space24),

                  // 4. Real Beehive Data / Empty State
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

                  const SizedBox(height: AppConstants.space20),

                  // 5. Add Hive Action (Only when profile is complete)
                  _AddHiveCard(onTap: _openAddHive),

                  const SizedBox(height: AppConstants.space24),

                  // 6. Recent Requests Header
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
    ),

    // Unignorable Critical Alert Modal Overlay
    if (criticalAlert != null)
      Container(
        color: Colors.black.withValues(alpha: 0.65),
        alignment: Alignment.center,
        child: CriticalAlertDialog(
          alert: criticalAlert,
          onAcknowledge: () {
            telemetryAlertCtrl.acknowledgeAlert(
              criticalAlert.id,
              userId: user.id ?? user.email,
              userName: user.name,
            );
          },
        ),
      ),
    ],
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

/// Harvester identity & verification status card with dynamic linear progress indicator
/// and 3-parameter verification workflow.
class _IdentityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final verCtrl = context.watch<VerificationController>();
    final ver = verCtrl.verification;
    final isVerified = ver.isFullyVerified;
    final int count = ver.completedStepsCount;
    final double progress = (count / 3.0).clamp(0.0, 1.0);
    final int percentage = (progress * 100).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String statusBadgeText;
    final Color statusColor;
    final Color statusBgColor;

    if (isVerified || count == 3) {
      statusBadgeText = 'Profile Verified (3 of 3)';
      statusColor = context.successColor;
      statusBgColor = context.successBgColor;
    } else if (count == 0) {
      statusBadgeText = 'Profile Setup (0 of 3)';
      statusColor = context.warningColor;
      statusBgColor = context.warningBgColor;
    } else {
      statusBadgeText = 'Partially Verified ($count of 3)';
      statusColor = context.colors.primary;
      statusBgColor = context.primarySoftColor;
    }

    final String supportingText;
    if (isVerified) {
      supportingText = 'Profile Verified — Harvester access enabled.';
    } else {
      supportingText = 'Complete profile verification to add hives and start harvesting activities.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified
              ? context.successColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white.withValues(alpha: 0.1) : context.borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: isVerified
                ? context.successColor.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isVerified ? Icons.verified_user_rounded : Icons.hive_rounded,
                      size: 20,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Harvester Verification',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimaryColor,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusBadgeText,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : context.borderColor.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentage%',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildMiniCheck(context, 'Govt ID', ver.isStep1Complete),
              _buildMiniCheck(context, 'Mobile OTP', ver.isStep2Complete),
              _buildMiniCheck(context, 'Apiary & Reg', ver.isStep3Complete),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  supportingText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
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
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isVerified ? context.successBgColor : context.primarySoftColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isVerified ? context.successColor.withValues(alpha: 0.4) : context.borderColor,
                    ),
                  ),
                  child: Text(
                    isVerified ? 'View Certificate ✓' : 'Verify Profile →',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isVerified ? context.successColor : context.textPrimaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCheck(BuildContext context, String title, bool isDone) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: isDone ? context.successColor : context.textMutedColor,
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isDone ? FontWeight.w600 : FontWeight.w500,
            color: isDone ? context.textPrimaryColor : context.textMutedColor,
          ),
        ),
      ],
    );
  }
}

class _HiveInfoCard extends StatefulWidget {
  final Hive hive;

  const _HiveInfoCard({required this.hive});

  @override
  State<_HiveInfoCard> createState() => _HiveInfoCardState();
}

class _HiveInfoCardState extends State<_HiveInfoCard> {
  List<Map<String, dynamic>> _telemetryHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTelemetry();
  }

  Future<void> _loadTelemetry() async {
    if (!mounted) return;
    final ctrl = context.read<TelemetryAlertController>();
    final history = await ctrl.fetchHiveTelemetry(widget.hive.id);
    if (mounted) {
      setState(() {
        _telemetryHistory = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthy = widget.hive.isHealthy;

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
              MaterialPageRoute(builder: (context) => HiveDetailsScreen(hiveId: widget.hive.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            widget.hive.name,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.hive.hiveCode} · ${widget.hive.apiaryLocation}',
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
                        widget.hive.overallHealth,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: healthy ? context.successColor : context.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_isLoading && _telemetryHistory.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.scaffoldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _TelemetryStat(
                          label: 'Temp',
                          value: '${_telemetryHistory.first['temperature'] ?? '--'}°C',
                          icon: Icons.thermostat_rounded,
                        ),
                        _TelemetryStat(
                          label: 'Humidity',
                          value: '${_telemetryHistory.first['humidity'] ?? '--'}%',
                          icon: Icons.water_drop_rounded,
                        ),
                        _TelemetryStat(
                          label: 'Weight',
                          value: '${_telemetryHistory.first['weightKg'] ?? '--'} kg',
                          icon: Icons.scale_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TelemetryStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TelemetryStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: context.colors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: context.textSecondaryColor,
          ),
        ),
      ],
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
