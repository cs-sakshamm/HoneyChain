import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../controllers/workflow_controller.dart';
import '../models/workflow_request.dart';
import '../theme/app_theme.dart';
import '../utils/profile_guard.dart';
import 'app_card.dart';
import 'status_badge.dart';
import 'global_app_bar.dart';
import '../../features/collection/screens/batch_timeline_screen.dart';
import '../../features/lab/screens/lab_report_screen.dart';
import '../../features/packaging/screens/packaging_qr_screen.dart';
import '../../features/profile/controllers/user_controller.dart';

enum RequestTabFilter {
  incoming,
  outgoing,
  pending,
  accepted,
  rejected,
  completed,
  all,
}

class MyRequestsView extends StatefulWidget {
  final String userRole; // 'HARVESTER', 'COLLECTOR_PROCESSOR', 'LAB', 'PACKAGING'
  final bool showAppBar;

  const MyRequestsView({
    super.key,
    required this.userRole,
    this.showAppBar = false,
  });

  @override
  State<MyRequestsView> createState() => _MyRequestsViewState();
}

class _MyRequestsViewState extends State<MyRequestsView> {
  RequestTabFilter _currentFilter = RequestTabFilter.incoming;

  String _normalizeRole(String role) {
    final r = role.toUpperCase().trim();
    if (r.contains('COLLECT') || r.contains('PROCESS')) return 'COLLECTOR_PROCESSOR';
    if (r.contains('LAB')) return 'LAB';
    if (r.contains('PKG') || r.contains('PACKAG')) return 'PACKAGING';
    return 'HARVESTER';
  }

  List<WorkflowRequest> _filterRequests(List<WorkflowRequest> all) {
    final myRole = _normalizeRole(widget.userRole);

    switch (_currentFilter) {
      case RequestTabFilter.incoming:
        return all.where((r) => r.toRole == myRole).toList();
      case RequestTabFilter.outgoing:
        return all.where((r) => r.fromRole == myRole).toList();
      case RequestTabFilter.pending:
        return all
            .where((r) =>
                (r.toRole == myRole || r.fromRole == myRole) &&
                r.status == RequestStatus.pending)
            .toList();
      case RequestTabFilter.accepted:
        return all
            .where((r) =>
                (r.toRole == myRole || r.fromRole == myRole) &&
                (r.status == RequestStatus.accepted ||
                    r.status == RequestStatus.processing ||
                    r.status == RequestStatus.testing ||
                    r.status == RequestStatus.packagingApproved))
            .toList();
      case RequestTabFilter.rejected:
        return all
            .where((r) =>
                (r.toRole == myRole || r.fromRole == myRole) &&
                (r.status == RequestStatus.denied || r.status == RequestStatus.labRejected))
            .toList();
      case RequestTabFilter.completed:
        return all
            .where((r) =>
                (r.toRole == myRole || r.fromRole == myRole) &&
                r.status == RequestStatus.completed)
            .toList();
      case RequestTabFilter.all:
        return all
            .where((r) => r.toRole == myRole || r.fromRole == myRole)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkflowController>();
    final requests = _filterRequests(controller.allRequests);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: widget.showAppBar
          ? const GlobalAppBar(
              titleText: 'My Requests',
              showBackButton: true,
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Tabs
            _buildTabSelector(context),

            // Requests List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.fetchAllData(),
                child: controller.isLoading && controller.allRequests.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : requests.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppConstants.space16,
                              AppConstants.space16,
                              AppConstants.space16,
                              120,
                            ),
                            itemCount: requests.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppConstants.space16),
                            itemBuilder: (context, index) {
                              final req = requests[index];
                              return _buildRequestCard(context, req);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    final tabs = [
      (RequestTabFilter.incoming, 'Incoming'),
      (RequestTabFilter.outgoing, 'Outgoing'),
      (RequestTabFilter.pending, 'Pending'),
      (RequestTabFilter.accepted, 'Accepted'),
      (RequestTabFilter.rejected, 'Rejected'),
      (RequestTabFilter.completed, 'Completed'),
      (RequestTabFilter.all, 'All'),
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label) = tabs[index];
          final isSelected = _currentFilter == filter;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _currentFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? context.colors.primary : context.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? context.colors.primary : context.borderColor,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? context.colors.onPrimary : context.textSecondaryColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: context.textMutedColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No requests found',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no ${_currentFilter.name} requests matching your role at this time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, WorkflowRequest req) {
    final myRole = _normalizeRole(widget.userRole);
    final isIncoming = req.toRole == myRole;
    final isConfirmedBlockchain = req.blockchainStatus == 'CONFIRMED' || (req.txHash != null && req.txHash!.isNotEmpty);

    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BatchTimelineScreen(batchId: req.batchId),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Request ID + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    req.requestId,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.primaryDarkColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Batch: ${req.batchId}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.textMutedColor,
                    ),
                  ),
                ],
              ),
              StatusBadge(status: req.status),
            ],
          ),

          const SizedBox(height: AppConstants.space12),

          // Role Chain Flow (From Role -> To Role)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.scaffoldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                _buildRolePill(context, req.fromRole, true),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 14, color: context.textMutedColor),
                const SizedBox(width: 8),
                _buildRolePill(context, req.toRole, false),
                const Spacer(),
                Text(
                  '${req.estimatedQuantityKg.toStringAsFixed(1)} kg',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: context.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.space12),

          // Meta Info: Harvester & Date
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 15, color: context.textSecondaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  req.harvesterName,
                  style: GoogleFonts.inter(fontSize: 13, color: context.textPrimaryColor, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.calendar_today_outlined, size: 14, color: context.textMutedColor),
              const SizedBox(width: 6),
              Text(
                DateFormat('MMM d, h:mm a').format(req.createdAt),
                style: GoogleFonts.inter(fontSize: 12, color: context.textMutedColor),
              ),
            ],
          ),

          if (req.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              req.notes,
              style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppConstants.space12),

          // Blockchain Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isConfirmedBlockchain ? context.successBgColor : context.warningBgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConfirmedBlockchain ? Icons.hive_rounded : Icons.hourglass_top_rounded,
                  size: 13,
                  color: isConfirmedBlockchain ? context.successColor : context.warningColor,
                ),
                const SizedBox(width: 6),
                Text(
                  isConfirmedBlockchain
                      ? 'Blockchain Confirmed'
                      : 'Blockchain Pending',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isConfirmedBlockchain ? context.successColor : context.warningColor,
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons depending on role and status
          if (isIncoming) ...[
            const SizedBox(height: AppConstants.space16),
            const Divider(height: 1),
            const SizedBox(height: AppConstants.space12),
            _buildRoleActions(context, req),
          ],
        ],
      ),
    );
  }

  Widget _buildRolePill(BuildContext context, String role, bool isSource) {
    String label = role;
    if (role == 'HARVESTER') label = 'Harvester';
    if (role == 'COLLECTOR_PROCESSOR') label = 'Collection';
    if (role == 'LAB') label = 'Lab';
    if (role == 'PACKAGING') label = 'Packaging';

    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isSource ? context.textSecondaryColor : context.primaryDarkColor,
      ),
    );
  }

  Widget _buildRoleActions(BuildContext context, WorkflowRequest req) {
    final myRole = _normalizeRole(widget.userRole);

    // ── Collection & Processing Actions ──
    if (myRole == 'COLLECTOR_PROCESSOR') {
      if (req.status == RequestStatus.pending) {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showRejectDialog(context, req),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.error,
                  side: const BorderSide(color: AppConstants.error),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Reject', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _acceptRequest(context, req),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Accept', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        );
      } else if (req.status == RequestStatus.accepted) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.science_outlined, size: 16),
            label: Text('Process & Send to Lab', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: () => _showProcessAndSendToLabDialog(context, req),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
      }
    }

    // ── Lab Testing Actions ──
    if (myRole == 'LAB') {
      if (req.status == RequestStatus.pending || req.status == RequestStatus.awaitingTest) {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showRejectDialog(context, req),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.error,
                  side: const BorderSide(color: AppConstants.error),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Reject', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _acceptRequest(context, req),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Accept Sample', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        );
      } else if (req.status == RequestStatus.accepted || req.status == RequestStatus.testing) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.assignment_outlined, size: 16),
            label: Text('Submit Lab Report', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LabReportScreen(request: req)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
      } else if (req.status == RequestStatus.labApproved) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.inventory_2_outlined, size: 16),
            label: Text('Approve for Packaging', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: () => _sendToPackaging(context, req),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
      }
    }

    // ── Packaging Actions ──
    if (myRole == 'PACKAGING') {
      if (req.status == RequestStatus.pending || req.status == RequestStatus.readyForPackaging) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: Text('Accept for Packaging', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: () => _acceptRequest(context, req),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
      } else if (req.status == RequestStatus.accepted || req.status == RequestStatus.packagingApproved) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_2_rounded, size: 16),
            label: Text('Finalize Packaging & QR', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: () => _showFinalizePackagingDialog(context, req),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
      } else if (req.status == RequestStatus.completed || req.status == RequestStatus.qrGenerated) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_rounded, size: 16),
            label: Text('View QR Verification', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PackagingQrScreen(request: req)),
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  void _acceptRequest(BuildContext context, WorkflowRequest req) async {
    if (!ProfileGuard.checkOrPrompt(context)) return;
    final userCtrl = context.read<UserController>();
    final wfCtrl = context.read<WorkflowController>();
    final success = await wfCtrl.acceptRequest(
          req.id,
          actorId: userCtrl.user.name,
          actorRole: widget.userRole,
        );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${req.requestId} accepted'),
          backgroundColor: AppConstants.success,
        ),
      );
    } else if (wfCtrl.isProfileIncompleteError) {
      ProfileGuard.showIncompleteProfileDialog(context);
    }
  }

  void _showRejectDialog(BuildContext context, WorkflowRequest req) {
    if (!ProfileGuard.checkOrPrompt(context)) return;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Reject Request', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify the reason for rejecting batch ${req.batchId}:', style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Quality threshold not met, package damaged...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogCtx);
              final wfCtrl = context.read<WorkflowController>();
              final success = await wfCtrl.rejectRequest(
                    req.id,
                    actorRole: widget.userRole,
                    reason: reason,
                  );
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Request ${req.requestId} rejected'), backgroundColor: AppConstants.error),
                );
              } else if (wfCtrl.isProfileIncompleteError) {
                ProfileGuard.showIncompleteProfileDialog(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.error),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  void _showProcessAndSendToLabDialog(BuildContext context, WorkflowRequest req) {
    if (!ProfileGuard.checkOrPrompt(context)) return;
    final qtyController = TextEditingController(text: req.estimatedQuantityKg > 0 ? req.estimatedQuantityKg.toString() : '');
    final methodController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Process & Send to Lab', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Extracted Quantity (kg)',
                hintText: 'e.g. ${req.estimatedQuantityKg > 0 ? req.estimatedQuantityKg : "25.0"}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: methodController,
              decoration: InputDecoration(
                labelText: 'Extraction Method',
                hintText: 'e.g. Standard Cold Extraction',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(qtyController.text) ?? req.estimatedQuantityKg;
              Navigator.pop(dialogCtx);
              final wfCtrl = context.read<WorkflowController>();
              final success = await wfCtrl.sendToLab(
                    requestId: req.id,
                    batchId: req.batchId,
                    qtyReceived: req.estimatedQuantityKg,
                    qtyAfter: qty,
                    method: methodController.text.trim(),
                  );
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Batch processed and forwarded to Lab Testing'), backgroundColor: AppConstants.success),
                );
              } else if (wfCtrl.isProfileIncompleteError) {
                ProfileGuard.showIncompleteProfileDialog(context);
              }
            },
            child: const Text('Send to Lab'),
          ),
        ],
      ),
    );
  }

  void _sendToPackaging(BuildContext context, WorkflowRequest req) async {
    if (!ProfileGuard.checkOrPrompt(context)) return;
    final wfCtrl = context.read<WorkflowController>();
    final success = await wfCtrl.sendToPackaging(
          requestId: req.id,
          batchId: req.batchId,
        );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch approved and forwarded to Packaging'), backgroundColor: AppConstants.success),
      );
    } else if (wfCtrl.isProfileIncompleteError) {
      ProfileGuard.showIncompleteProfileDialog(context);
    }
  }

  void _showFinalizePackagingDialog(BuildContext context, WorkflowRequest req) {
    if (!ProfileGuard.checkOrPrompt(context)) return;
    final qtyController = TextEditingController(text: req.estimatedQuantityKg > 0 ? req.estimatedQuantityKg.toString() : '');
    final pkgsController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Finalize Packaging', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Total Quantity (kg)',
                hintText: 'e.g. ${req.estimatedQuantityKg > 0 ? req.estimatedQuantityKg : "15.0"}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pkgsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of Packages (Jars)',
                hintText: 'e.g. 30',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(qtyController.text) ?? req.estimatedQuantityKg;
              final pkgs = int.tryParse(pkgsController.text) ?? 50;
              Navigator.pop(dialogCtx);
              final wfCtrl = context.read<WorkflowController>();
              final success = await wfCtrl.finalizePackaging(
                    requestId: req.id,
                    batchId: req.batchId,
                    finalQuantity: qty,
                    numberOfPackages: pkgs,
                  );
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Packaging completed! QR Code generated.'), backgroundColor: AppConstants.success),
                );
              } else if (wfCtrl.isProfileIncompleteError) {
                ProfileGuard.showIncompleteProfileDialog(context);
              }
            },
            child: const Text('Finalize & Generate QR'),
          ),
        ],
      ),
    );
  }
}
