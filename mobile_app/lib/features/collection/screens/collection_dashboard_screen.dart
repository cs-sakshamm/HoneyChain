import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/my_requests_view.dart';
import '../../../core/widgets/status_badge.dart';
import 'batch_timeline_screen.dart';
import 'harvester_detail_screen.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/utils/profile_guard.dart';
import '../../profile/controllers/user_controller.dart';

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRejectDialog(BuildContext context, WorkflowRequest req) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<WorkflowController>().rejectRequest(req.id, reason: reasonCtrl.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Request rejected & recorded.'), backgroundColor: AppConstants.error),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.error),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  void _showSendToLabDialog(BuildContext context, WorkflowRequest req) {
    final methodCtrl = TextEditingController();
    final facilityCtrl = TextEditingController();
    final moistureCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
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
                processorId: userCtrl.user.name.isNotEmpty ? userCtrl.user.name : 'Processor Officer',
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
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
            child: const Text('Dispatch to Lab'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<WorkflowController>().pendingCollectionRequests;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    isScrollable: false,
                    labelColor: context.colors.primary,
                    unselectedLabelColor: context.textSecondaryColor,
                    indicatorColor: context.colors.primary,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                    tabs: [
                      Tab(text: 'Incoming (${requests.length})'),
                      const Tab(text: 'All Requests & History'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Pending incoming harvests
                  requests.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppConstants.space16, AppConstants.space16, AppConstants.space16, 120),
                          itemCount: requests.length,
                          separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
                          itemBuilder: (context, index) {
                            final req = requests[index];
                            return _buildIncomingRequestCard(context, req);
                          },
                        ),
                  // Tab 2: Full MyRequestsView
                  const MyRequestsView(userRole: 'COLLECTOR_PROCESSOR'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: context.textMutedColor.withValues(alpha: 0.5)),
          const SizedBox(height: AppConstants.space16),
          Text(
            context.tr('no_pending_requests') == 'no_pending_requests' ? 'No pending requests' : context.tr('no_pending_requests'),
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Text(
            'New harvest batches sent by harvesters will appear here.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestCard(BuildContext context, WorkflowRequest req) {
    final isPending = req.status == RequestStatus.pending;
    final isAccepted = req.status == RequestStatus.accepted;

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
                  'Harvest Quantity:',
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
          const SizedBox(height: AppConstants.space16),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (!ProfileGuard.checkOrPrompt(context)) return;
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
                      if (!ProfileGuard.checkOrPrompt(context)) return;
                      await context.read<WorkflowController>().acceptRequest(req.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harvest batch accepted! You can now extract and send to Lab.')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: context.colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                      ),
                    ),
                    child: Text(
                      'Accept Batch',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            )
          else if (isAccepted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!ProfileGuard.checkOrPrompt(context)) return;
                  _showSendToLabDialog(context, req);
                },
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Extract & Send to Lab'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

