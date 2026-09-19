import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/auto_image_slider.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/status_badge.dart';
import '../../collection/screens/batch_timeline_screen.dart';
import '../../collection/screens/nearest_centres_screen.dart';
import '../../profile/controllers/user_controller.dart';
import '../../verification/controllers/verification_controller.dart';
import '../../verification/screens/lab_verification_screen.dart';
import 'lab_report_screen.dart';

class LabDashboardScreen extends StatefulWidget {
  const LabDashboardScreen({super.key});

  @override
  State<LabDashboardScreen> createState() => _LabDashboardScreenState();
}

class _LabDashboardScreenState extends State<LabDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserController>().user;
      final userId = user.id ?? user.email;
      if (userId.isNotEmpty) {
        context.read<VerificationController>().loadLabVerification(userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRejectSampleDialog(BuildContext context, WorkflowRequest req) {
    if (!ProfileGuard.checkLabVerificationOrPrompt(context)) return;
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reject Honey Sample', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide reason for lab rejection (e.g. Broken seal, invalid container):', style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Rejection reason...',
                filled: true,
                fillColor: context.scaffoldBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await context.read<WorkflowController>().rejectRequest(req.id, actorRole: 'LAB', reason: reasonCtrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sample rejected & recorded.'), backgroundColor: AppConstants.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return const AutoImageSlider(
      role: 'LAB_TESTER',
      height: 155,
      borderRadius: 20,
      margin: EdgeInsets.only(bottom: AppConstants.space16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workflowCtrl = context.watch<WorkflowController>();
    final requestedSamples = workflowCtrl.labRequestedRequests;
    final acceptedSamples = workflowCtrl.labAcceptedRequests;
    final completedSamples = workflowCtrl.labCompletedRequests;

    final verCtrl = context.watch<VerificationController>();
    final labVer = verCtrl.labVerification;
    final isFullyVerified = labVer.isFullyVerified;
    final completedCount = labVer.completedStepsCount;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroImage(context),
                  Text(
                    'Laboratory Testing',
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analyze honey samples for purity, moisture content, and quality scoring.',
                    style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
                  ),
                  const SizedBox(height: 14),

                  const SizedBox(height: 14),

                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: context.colors.primary,
                    unselectedLabelColor: context.textSecondaryColor,
                    indicatorColor: context.colors.primary,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                    tabs: [
                      Tab(text: 'Requested (${requestedSamples.length})'),
                      Tab(text: 'Accepted (${acceptedSamples.length})'),
                      Tab(text: 'Completed (${completedSamples.length})'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Requested
                  _buildLabListView(
                    context,
                    requestedSamples,
                    'No requested samples',
                    'Incoming honey samples sent by collection centres will appear here.',
                    showAcceptReject: true,
                  ),

                  // Tab 1: Accepted
                  _buildLabListView(
                    context,
                    acceptedSamples,
                    'No accepted samples',
                    'Samples accepted by this lab ready for physical & chemical testing will appear here.',
                    showConductTest: true,
                  ),

                  // Tab 2: Completed
                  _buildLabListView(
                    context,
                    completedSamples,
                    'No completed lab tests',
                    'Tested and certified honey reports will appear here.',
                    showSendToPackaging: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabListView(
    BuildContext context,
    List<WorkflowRequest> samples,
    String emptyTitle,
    String emptySubtitle, {
    bool showAcceptReject = false,
    bool showConductTest = false,
    bool showSendToPackaging = false,
  }) {
    if (samples.isEmpty) {
      return EmptyStateWidget(
        title: emptyTitle,
        subtitle: '> No data available yet.',
        icon: Icons.science_outlined,
      );
    }

    final verCtrl = context.watch<VerificationController>();
    final userCtrl = context.watch<UserController>();
    final isFullyVerified = verCtrl.labVerification.isFullyVerified || userCtrl.user.isVerified || userCtrl.user.isProfileComplete;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppConstants.space16, AppConstants.space16, AppConstants.space16, 120),
      itemCount: samples.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
      itemBuilder: (context, index) {
        final req = samples[index];
        final formattedDate = DateFormat('MMM dd, yyyy • h:mm a').format(req.createdAt);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Sample: ' + ((req.labSampleId != null && req.labSampleId!.isNotEmpty) ? req.labSampleId! : req.batchId),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppConstants.space8),
                  StatusBadge(status: req.status),
                ],
              ),
              const SizedBox(height: AppConstants.space12),
              Row(
                children: [
                  Icon(Icons.tag_rounded, size: 16, color: context.textSecondaryColor),
                  const SizedBox(width: AppConstants.space8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BatchTimelineScreen(batchId: req.batchId)),
                        );
                      },
                      child: Text(
                        'Batch: ' + req.batchId,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.space8),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 16, color: context.textSecondaryColor),
                  const SizedBox(width: AppConstants.space8),
                  Expanded(
                    child: Text(
                      'Harvester: ' + req.harvesterName,
                      style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.space8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: context.textSecondaryColor),
                  const SizedBox(width: AppConstants.space8),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (req.notes != null && req.notes!.isNotEmpty) ...[
                const SizedBox(height: AppConstants.space8),
                Text(
                  'Processing Notes: ${req.notes!}',
                  style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor, fontStyle: FontStyle.italic),
                ),
              ],
              if (showAcceptReject) ...[
                const SizedBox(height: AppConstants.space16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (!ProfileGuard.checkLabVerificationOrPrompt(context)) return;
                          _showRejectSampleDialog(context, req);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.error,
                          side: const BorderSide(color: AppConstants.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Reject Sample', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!ProfileGuard.checkLabVerificationOrPrompt(context)) return;
                          await context.read<WorkflowController>().acceptRequest(req.id, actorRole: 'LAB');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sample accepted! Ready to conduct chemical & purity test.')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFullyVerified ? context.colors.primary : context.textMutedColor,
                          foregroundColor: context.colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Accept Sample', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ] else if (showConductTest) ...[
                const SizedBox(height: AppConstants.space16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!ProfileGuard.checkLabVerificationOrPrompt(context)) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LabReportScreen(request: req),
                        ),
                      );
                    },
                    icon: const Icon(Icons.biotech_rounded, size: 18),
                    label: const Text('Conduct 6-Parameter Test & Generate Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFullyVerified ? context.colors.primary : context.textMutedColor,
                      foregroundColor: context.colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else if (showSendToPackaging) ...[
                const SizedBox(height: AppConstants.space16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (!ProfileGuard.checkLabVerificationOrPrompt(context)) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NearestCentresScreen(
                                targetRole: 'PACKAGING',
                                batchId: req.batchId,
                                requestId: req.id,
                                quantity: req.estimatedQuantityKg,
                                originLocation: req.location,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.local_shipping_rounded, size: 18),
                        label: const Text('Send to Packaging (Nearest)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: context.colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => BatchTimelineScreen(batchId: req.batchId)),
                          );
                        },
                        icon: const Icon(Icons.timeline_rounded, size: 16),
                        label: const Text('Timeline'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerificationBanner(BuildContext context, int count, bool isVerified) {
    final verCtrl = context.watch<VerificationController>();
    final userCtrl = context.watch<UserController>();
    final labVer = verCtrl.labVerification;
    final isFullyVerified = labVer.isFullyVerified || userCtrl.user.isVerified || userCtrl.user.isProfileComplete;
    final int completedCount = isFullyVerified ? 3 : labVer.completedStepsCount;
    final double progress = (completedCount / 3.0).clamp(0.0, 1.0);
    final int percentage = (progress * 100).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String statusBadgeText;
    final Color statusColor;
    final Color statusBgColor;

    if (isFullyVerified || completedCount == 3) {
      statusBadgeText = 'Profile Verified (3 of 3)';
      statusColor = context.successColor;
      statusBgColor = context.successBgColor;
    } else if (completedCount == 0) {
      statusBadgeText = 'Profile Setup (0 of 3)';
      statusColor = context.warningColor;
      statusBgColor = context.warningBgColor;
    } else {
      statusBadgeText = 'Partially Verified ($completedCount of 3)';
      statusColor = context.colors.primary;
      statusBgColor = context.primarySoftColor;
    }

    final String supportingText;
    if (isFullyVerified) {
      supportingText = 'Profile Verified — Laboratory Testing access enabled.';
    } else {
      supportingText = 'Complete profile verification to accept and perform laboratory testing requests.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFullyVerified
              ? context.successColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white.withValues(alpha: 0.1) : context.borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: isFullyVerified
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
                      isFullyVerified ? Icons.verified_user_rounded : Icons.science_rounded,
                      size: 20,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Lab Profile Verification',
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
              _buildMiniCheck(context, 'Lab Details', labVer.isStep2LabDetailsComplete),
              _buildMiniCheck(context, 'KYC & Scope', labVer.isStep3KycComplete),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LabVerificationScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFullyVerified ? context.successBgColor : context.primarySoftColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFullyVerified ? context.successColor.withValues(alpha: 0.4) : context.borderColor,
                    ),
                  ),
                  child: Text(
                    isFullyVerified ? 'View Badge ✓' : 'Verify Profile →',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFullyVerified ? context.successColor : context.textPrimaryColor,
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

