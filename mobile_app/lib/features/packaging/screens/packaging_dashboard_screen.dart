import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/my_requests_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../collection/screens/batch_timeline_screen.dart';
import '../../profile/controllers/user_controller.dart';
import 'packaging_qr_screen.dart';

class PackagingDashboardScreen extends StatefulWidget {
  const PackagingDashboardScreen({super.key});

  @override
  State<PackagingDashboardScreen> createState() => _PackagingDashboardScreenState();
}

class _PackagingDashboardScreenState extends State<PackagingDashboardScreen> with SingleTickerProviderStateMixin {
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

  void _showFinalizePackagingDialog(BuildContext context, WorkflowRequest req) {
    final qtyCtrl = TextEditingController(text: req.estimatedQuantityKg > 0 ? req.estimatedQuantityKg.toStringAsFixed(1) : '15.0');
    final countCtrl = TextEditingController(text: '30');
    final sizeCtrl = TextEditingController(text: '500g Glass Jar (Tamper-evident sealed)');
    final notesCtrl = TextEditingController(text: 'Packaged, sealed, and assigned batch QR verification tag.');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Finalize Packaging', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Batch ID: ${req.batchId}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
              const SizedBox(height: 12),
              Text('Total Packaged Quantity (kg)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              const SizedBox(height: 4),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              Text('Number of Units / Jars', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              const SizedBox(height: 4),
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              Text('Package Type & Specification', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              const SizedBox(height: 4),
              TextField(
                controller: sizeCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              Text('Packaging Notes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
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
              final finalQty = double.tryParse(qtyCtrl.text.trim()) ?? 15.0;
              final numPackages = int.tryParse(countCtrl.text.trim()) ?? 30;
              Navigator.pop(dialogCtx);

              final userCtrl = context.read<UserController>();
              final workflowCtrl = context.read<WorkflowController>();

              final success = await workflowCtrl.finalizePackaging(
                requestId: req.id,
                batchId: req.batchId,
                finalQuantity: finalQty,
                numberOfPackages: numPackages,
                packageSize: sizeCtrl.text.trim(),
                notes: notesCtrl.text.trim(),
                packagerId: userCtrl.user.name.isNotEmpty ? userCtrl.user.name : 'Packaging Facility',
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Batch packaged & QR verification generated!' : 'Packaging recorded.'),
                    backgroundColor: AppConstants.success,
                  ),
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PackagingQrScreen(request: req),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
            child: const Text('Complete & Generate QR'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WorkflowRequest req) {
    final reasonCtrl = TextEditingController(text: 'Packaging inspection failed: seal integrity or labeling issue');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Reject Batch from Packaging', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Rejection reason...',
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
              context.read<WorkflowController>().rejectRequest(req.id, actorRole: 'PACKAGING', reason: reasonCtrl.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Batch rejected & logged.'), backgroundColor: AppConstants.error),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.error),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkflowController>();
    final pendingRequests = controller.packagingPendingRequests;

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
                    'Packaging & Labeling',
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Package lab-certified honey batches and generate verifiable consumer QR codes.',
                    style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    labelColor: context.colors.primary,
                    unselectedLabelColor: context.textSecondaryColor,
                    indicatorColor: context.colors.primary,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                    tabs: [
                      Tab(text: 'Pending Packaging (${pendingRequests.length})'),
                      const Tab(text: 'Packaging History & QR'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Pending batches
                  pendingRequests.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppConstants.space16, 12, AppConstants.space16, 120),
                          itemCount: pendingRequests.length,
                          separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
                          itemBuilder: (context, index) {
                            final req = pendingRequests[index];
                            return _buildPendingCard(context, req);
                          },
                        ),
                  // Tab 2: Full MyRequestsView
                  const MyRequestsView(userRole: 'PACKAGING'),
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
          Icon(Icons.inventory_2_outlined, size: 64, color: context.textMutedColor.withValues(alpha: 0.5)),
          const SizedBox(height: AppConstants.space16),
          Text(
            'No Pending Batches',
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
          ),
          const SizedBox(height: AppConstants.space8),
          Text(
            'Lab-approved batches will arrive here ready for packaging & QR assignment.',
            style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(BuildContext context, WorkflowRequest req) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                      style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.primary),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: req.status),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: context.textSecondaryColor),
              const SizedBox(width: AppConstants.space8),
              Expanded(
                child: Text(req.harvesterName, style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor)),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space8),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: context.textSecondaryColor),
              const SizedBox(width: AppConstants.space8),
              Text(
                DateFormat('MMM dd, yyyy • h:mm a').format(req.createdAt),
                style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space16),
          const Divider(),
          const SizedBox(height: AppConstants.space12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showRejectDialog(context, req),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.error,
                    side: const BorderSide(color: AppConstants.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Reject Batch', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showFinalizePackagingDialog(context, req),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Package & QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: context.colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

