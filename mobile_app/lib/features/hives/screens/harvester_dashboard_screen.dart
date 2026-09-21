import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/telemetry_alert_controller.dart';
import '../../../core/models/hive_telemetry_models.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/failed_hive_card.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/auto_image_slider.dart';
import '../../../core/widgets/critical_alert_dialog.dart';
import '../../../core/widgets/my_requests_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../../collection/screens/batch_timeline_screen.dart';
import '../../profile/controllers/user_controller.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import 'add_edit_hive_screen.dart';
import 'hive_details_screen.dart';

/// Harvester Home — greeting, hive overview with real data, Add Hive action,
/// and recent collection requests. No fake telemetry.
class HarvesterDashboardScreen extends StatefulWidget {
  const HarvesterDashboardScreen({super.key});

  @override
  State<HarvesterDashboardScreen> createState() => _HarvesterDashboardScreenState();
}

class _HarvesterDashboardScreenState extends State<HarvesterDashboardScreen> {
  /// Real backend status of the collection request attached to a hive.
  /// Reads only from WorkflowController data fetched from GET /api/requests —
  /// no local/dummy status is invented.
  String _requestStatusLabel(String? hiveId) {
    if (hiveId == null || hiveId.isEmpty) return 'Request Not Sent';
    final workflowCtrl = context.read<WorkflowController>();
    final requests = workflowCtrl.harvesterRequests
        .where((r) => r.hiveId == hiveId)
        .toList();
    if (requests.isEmpty) return 'Request Not Sent';
    // Most recent request for this hive wins.
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests.first.status.label;
  }

  Color _requestStatusColor(String label) {
    switch (label) {
      case 'Request Not Sent':
        return context.textMutedColor;
      case 'Pending':
        return context.warningColor;
      case 'Accepted':
      case 'Processing':
      case 'Lab Verified':
      case 'Completed':
        return context.successColor;
      case 'Denied':
      case 'Lab Rejected':
        return context.errorColor;
      default:
        return context.colors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserController>().user;
      final userId = (user.id != null && user.id!.isNotEmpty) ? user.id! : user.email;
      if (userId.isNotEmpty) {
        context.read<TelemetryAlertController>().startMonitoring(userId: userId);
      }
      // Re-fetch requests from the backend so statuses updated elsewhere
      // (e.g. Collection & Processing accepting a request) are shown when the
      // harvester opens the dashboard. Without this the dashboard only ever
      // saw the state captured at login.
      context.read<WorkflowController>().fetchAllData();
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
    // Accessible to any authenticated harvester (e.g. Google sign-in) —
    // no profile-verification gate.
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
    
    // Active requests from THIS harvester: still in progress (not yet
    // accepted/completed/rejected). pendingCollectionRequests is the
    // collector-inbound getter and would count other users' requests.
    final activeRequests = workflowController.harvesterRequests
        .where((r) =>
            r.status == RequestStatus.pending ||
            r.status == RequestStatus.accepted ||
            r.status == RequestStatus.processing ||
            r.status == RequestStatus.awaitingTest ||
            r.status == RequestStatus.testing)
        .length;
    final hives = hiveController.hives;
    final criticalAlert = telemetryAlertCtrl.activeUnacknowledgedAlert;

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => context.read<WorkflowController>().fetchAllData(),
            color: context.primaryDarkColor,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        'Overview of your apiary and honey collection.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.space20),

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

                  if (hives.isEmpty && hiveController.failedSubmissions.isEmpty)
                    _HiveEmptyState(onAddHive: _openAddHive)
                  else ...[
                    // Honest per-hive error cards for submissions the backend
                    // rejected — real message + Retry, never a fake success.
                    ...hiveController.failedSubmissions.values.map(
                      (failed) => FailedHiveCard(
                        failed: failed,
                        onRetry: () => hiveController.retryFailedSubmission(failed.localKey),
                        onDismiss: () => hiveController.dismissFailedSubmission(failed.localKey),
                      ),
                    ),
                    ...hives.take(3).map((hive) => _HiveInfoCard(
                          hive: hive,
                          requestStatusLabel: _requestStatusLabel(hive.id),
                          requestStatusColor: _requestStatusColor(_requestStatusLabel(hive.id)),
                        )),
                  ],

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
                                  appBar: const GlobalAppBar(
                                    titleText: 'My Workflow Requests',
                                    showBackButton: true,
                                  ),
                                  body: const MyRequestsView(userRole: 'HARVESTER'),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'View All (${workflowController.harvesterRequests.length})',
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

          if (workflowController.harvesterRequests.isEmpty)
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
                  final sortedRequests = workflowController.harvesterRequests;

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
                childCount: workflowController.harvesterRequests.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 120), // clear the floating bottom nav
          ),
              ],
            ),
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

class _HiveInfoCard extends StatefulWidget {
  final Hive hive;
  final String requestStatusLabel;
  final Color requestStatusColor;

  const _HiveInfoCard({
    required this.hive,
    required this.requestStatusLabel,
    required this.requestStatusColor,
  });

  @override
  State<_HiveInfoCard> createState() => _HiveInfoCardState();
}

class _HiveInfoCardState extends State<_HiveInfoCard> {
  HiveSnapshot? _snapshot;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTelemetry();
  }

  Future<void> _loadTelemetry() async {
    if (!mounted) return;
    final ctrl = context.read<TelemetryAlertController>();
    final snapshot = await ctrl.fetchHiveSnapshot(widget.hive.id);
    if (mounted) {
      setState(() {
        _snapshot = snapshot;
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Real workflow status for this hive from the backend
                        // (Request Not Sent → Pending → Accepted → …).
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.requestStatusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.requestStatusLabel,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: widget.requestStatusColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
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
                  ],
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                ] else if (_snapshot != null && _snapshot!.hasTelemetry && _snapshot!.telemetry != null) ...[
                  // Real latest sensor values from ESP32 -> MQTT -> AI -> backend.
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
                          value: '${_snapshot!.telemetry!.temperature?.toStringAsFixed(1) ?? '--'}°C',
                          icon: Icons.thermostat_rounded,
                        ),
                        _TelemetryStat(
                          label: 'Humidity',
                          value: '${_snapshot!.telemetry!.humidity?.toStringAsFixed(1) ?? '--'}%',
                          icon: Icons.water_drop_rounded,
                        ),
                        _TelemetryStat(
                          label: 'Weight',
                          value: '${_snapshot!.telemetry!.weightKg?.toStringAsFixed(2) ?? '--'} kg',
                          icon: Icons.scale_rounded,
                        ),
                      ],
                    ),
                  ),
                  if (_snapshot!.aiStatus != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _snapshot!.aiStatus!.status == 'HEALTHY'
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          size: 13,
                          color: _snapshot!.aiStatus!.status == 'HEALTHY'
                              ? context.successColor
                              : context.warningColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI: ${_snapshot!.aiStatus!.status ?? '--'} · Risk ${_snapshot!.aiStatus!.riskLevel ?? '--'}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_snapshot!.aiReadiness != null && !_snapshot!.aiReadiness!.ready) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Collecting telemetry history... (${_snapshot!.aiReadiness!.currentReadings}/${_snapshot!.aiReadiness!.requiredReadings})',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: context.textMutedColor,
                      ),
                    ),
                  ],
                ] else ...[
                  // Honest empty state — no telemetry has arrived yet.
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.sensors_off_rounded, size: 14, color: context.textMutedColor),
                      const SizedBox(width: 6),
                      Text(
                        'Waiting for telemetry...',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: context.textMutedColor,
                        ),
                      ),
                    ],
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

