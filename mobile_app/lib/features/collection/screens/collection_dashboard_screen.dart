import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/auto_image_slider.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/status_badge.dart';
import 'batch_timeline_screen.dart';
import 'harvester_detail_screen.dart';
import 'nearest_centres_screen.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/localization/localization_service.dart';
import '../../profile/controllers/user_controller.dart';
import '../../verification/controllers/verification_controller.dart';
import '../../verification/screens/collector_verification_screen.dart';

class CollectionDashboardScreen extends StatefulWidget {
  const CollectionDashboardScreen({super.key});

  @override
  State<CollectionDashboardScreen> createState() => _CollectionDashboardScreenState();
}

class _CollectionDashboardScreenState extends State<CollectionDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserController>().user;
      final userId = user.id ?? user.email;
      if (userId.isNotEmpty) {
        context.read<VerificationController>().loadCollectorVerification(userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRejectDialog(BuildContext context, WorkflowRequest req) {
    if (!ProfileGuard.checkCollectorVerificationOrPrompt(context)) return;
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reject Harvest Batch', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a reason for rejection (this will be recorded on-chain):', style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                filled: true,
                fillColor: context.scaffoldBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
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
              await context.read<WorkflowController>().rejectRequest(req.id, actorRole: 'COLLECTOR_PROCESSOR', reason: reasonCtrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request rejected & recorded.'), backgroundColor: AppConstants.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  void _showSendToLabDialog(BuildContext context, WorkflowRequest req) {
    if (!ProfileGuard.checkCollectorVerificationOrPrompt(context)) return;
    final user = context.read<UserController>().user;
    final methodCtrl = TextEditingController();
    final facilityCtrl = TextEditingController(text: user.facilityLocation ?? '');
    final moistureCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Process & Send to Lab', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Batch ID: ${req.batchId}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
              const SizedBox(height: 12),
              Text('Extraction Method / Details', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              const SizedBox(height: 4),
              TextField(
                controller: methodCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Cold Extraction & Filtration',
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              Text('Facility / Location', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              const SizedBox(height: 4),
              TextField(
                controller: facilityCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter processing facility name or address',
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              Text('Moisture Level (%)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              const SizedBox(height: 4),
              TextField(
                controller: moistureCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g. 17.2',
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              Text('Notes to Lab', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              const SizedBox(height: 4),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter notes or observations for testing lab...',
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final userCtrl = context.read<UserController>();
              final success = await context.read<WorkflowController>().sendToLab(
                requestId: req.id,
                batchId: req.batchId,
                qtyReceived: req.estimatedQuantityKg,
                qtyAfter: req.estimatedQuantityKg > 0 ? req.estimatedQuantityKg * 0.95 : 10.0,
                method: '${methodCtrl.text.trim()} (Facility: ${facilityCtrl.text.trim()}, Moisture: ${moistureCtrl.text.trim()}%)',
                notes: notesCtrl.text.trim(),
                processorId: userCtrl.user.id,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Processing logged & sample dispatched to Lab!' : 'Failed to dispatch to Lab'),
                    backgroundColor: success ? AppConstants.success : AppConstants.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Dispatch to Lab'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return const AutoImageSlider(
      role: 'COLLECTOR_PROCESSOR',
      height: 155,
      borderRadius: 20,
      margin: EdgeInsets.only(bottom: AppConstants.space16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workflowCtrl = context.watch<WorkflowController>();
    final newRequests = workflowCtrl.collectionNewRequests;
    final acceptedRequests = workflowCtrl.collectionAcceptedRequests;
    final rejectedRequests = workflowCtrl.collectionRejectedRequests;
    final completedRequests = workflowCtrl.collectionCompletedRequests;

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
                    context.tr('collection_processing') == 'collection_processing'
                        ? 'Collection & Processing'
                        : context.tr('collection_processing'),
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage incoming harvests, extraction records, and lab testing handoffs.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: context.colors.primary,
                    unselectedLabelColor: context.textSecondaryColor,
                    indicatorColor: context.colors.primary,
                    indicatorWeight: 3,
                    tabAlignment: TabAlignment.start,
                    labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                    tabs: [
                      Tab(text: 'New Requests (${newRequests.length})'),
                      Tab(text: 'Accepted (${acceptedRequests.length})'),
                      Tab(text: 'Rejected (${rejectedRequests.length})'),
                      Tab(text: 'Completed (${completedRequests.length})'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: New Requests
                  _buildRequestListView(context, newRequests, 'No new pending requests', 'New harvest batches sent by harvesters will appear here.', showAcceptReject: true),

                  // Tab 1: Accepted Requests
                  _buildRequestListView(context, acceptedRequests, 'No accepted requests', 'Harvest batches you have accepted will appear here ready for extraction.', showSendToLab: true),

                  // Tab 2: Rejected Requests
                  _buildRequestListView(context, rejectedRequests, 'No rejected requests', 'Harvest batches that were rejected will appear here for audit history.', isRejectedTab: true),

                  // Tab 3: Completed Processing
                  _buildRequestListView(context, completedRequests, 'No completed batches', 'Batches that have finished processing and were sent to testing labs will appear here.', isCompletedTab: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestListView(
    BuildContext context,
    List<WorkflowRequest> requests,
    String emptyTitle,
    String emptySubtitle, {
    bool showAcceptReject = false,
    bool showSendToLab = false,
    bool isRejectedTab = false,
    bool isCompletedTab = false,
  }) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppConstants.space16, AppConstants.space16, AppConstants.space16, 0),
            child: _buildVerificationBanner(context),
          ),
        ),
        requests.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context, emptyTitle, emptySubtitle),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppConstants.space16, AppConstants.space16, AppConstants.space16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final req = requests[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppConstants.space16),
                        child: _buildRequestCard(
                          context,
                          req,
                          showAcceptReject: showAcceptReject,
                          showSendToLab: showSendToLab,
                          isRejectedTab: isRejectedTab,
                          isCompletedTab: isCompletedTab,
                        ),
                      );
                    },
                    childCount: requests.length,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildVerificationBanner(BuildContext context) {
    final verCtrl = context.watch<VerificationController>();
    final userCtrl = context.watch<UserController>();
    final collectorVer = verCtrl.collectorVerification;
    final isFullyVerified = collectorVer.isFullyVerified || userCtrl.user.isVerified || userCtrl.user.isProfileComplete;
    final count = isFullyVerified ? 3 : collectorVer.completedStepsCount;
    final double progress = (count / 3.0).clamp(0.0, 1.0);
    final int percentage = (progress * 100).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String statusBadgeText;
    final Color statusColor;
    final Color statusBgColor;

    if (isFullyVerified || count == 3) {
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
    if (isFullyVerified) {
      supportingText = 'Profile Verified — Collection & Processing access enabled.';
    } else {
      supportingText = 'Complete profile verification to start collection & processing activities.';
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
                      isFullyVerified ? Icons.verified_user_rounded : Icons.shield_outlined,
                      size: 20,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Profile Verification',
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
              _buildMiniCheck(context, 'Business', collectorVer.isStep2BusinessComplete),
              _buildMiniCheck(context, 'License & KYC', collectorVer.isStep3KycComplete),
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
                    MaterialPageRoute(builder: (context) => const CollectorVerificationScreen()),
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
            fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
            color: isDone ? context.successColor : context.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String subtitle) {
    return EmptyStateWidget(
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    WorkflowRequest req, {
    bool showAcceptReject = false,
    bool showSendToLab = false,
    bool isRejectedTab = false,
    bool isCompletedTab = false,
  }) {
    final verCtrl = context.watch<VerificationController>();
    final userCtrl = context.watch<UserController>();
    final isCollectorVerified = verCtrl.collectorVerification.isFullyVerified || userCtrl.user.isVerified || userCtrl.user.isProfileComplete;

    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HarvesterDetailScreen(request: req)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(status: req.status),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BatchTimelineScreen(batchId: req.batchId)),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.timeline_rounded, size: 14, color: context.colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      req.batchId,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Text(
            req.harvesterName,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: context.textSecondaryColor),
              const SizedBox(width: AppConstants.space4),
              Expanded(
                child: Text(
                  req.location,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space4),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: context.textSecondaryColor),
              const SizedBox(width: AppConstants.space4),
              Expanded(
                child: Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(req.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.space12, vertical: AppConstants.space8),
                decoration: BoxDecoration(
                  color: context.scaffoldBg,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Quantity:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: AppConstants.space8),
                    Text(
                      '${req.estimatedQuantityKg.toStringAsFixed(1)} kg',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (req.notes != null && req.notes!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    req.notes!,
                    style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (isRejectedTab) ...[
            const SizedBox(height: AppConstants.space12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined, size: 16, color: AppConstants.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection Reason: ${req.notes ?? "Batch quality specifications not met."}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showAcceptReject) ...[
            const SizedBox(height: AppConstants.space16),
            if (!isCollectorVerified) ...[
              Container(
                margin: const EdgeInsets.only(bottom: AppConstants.space12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.warningBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.warningColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_person_outlined, size: 16, color: context.warningColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Complete your profile verification to accept requests.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _showRejectDialog(context, req);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.error,
                      side: const BorderSide(color: AppConstants.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                      ),
                    ),
                    child: Text(
                      'Reject',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.space12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!ProfileGuard.checkCollectorVerificationOrPrompt(context)) return;
                      await context.read<WorkflowController>().acceptRequest(req.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harvest batch accepted! You can now extract and send to Lab.')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCollectorVerified ? context.colors.primary : context.borderColor,
                      foregroundColor: isCollectorVerified ? context.colors.onPrimary : context.textMutedColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                      ),
                    ),
                    child: Text(
                      'Accept Request',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: isCollectorVerified ? context.colors.onPrimary : context.textMutedColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (showSendToLab) ...[
            const SizedBox(height: AppConstants.space16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!ProfileGuard.checkCollectorVerificationOrPrompt(context)) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NearestCentresScreen(
                            targetRole: 'LAB',
                            batchId: req.batchId,
                            requestId: req.id,
                            quantity: req.estimatedQuantityKg,
                            originLocation: req.location,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.near_me_rounded, size: 18),
                    label: const Text('Nearest Lab Testing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: context.colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showSendToLabDialog(context, req);
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Custom'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall)),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isCompletedTab) ...[
            const SizedBox(height: AppConstants.space12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BatchTimelineScreen(batchId: req.batchId)),
                  );
                },
                icon: const Icon(Icons.timeline_rounded, size: 16),
                label: const Text('View Lifecycle & Blockchain Trace'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


