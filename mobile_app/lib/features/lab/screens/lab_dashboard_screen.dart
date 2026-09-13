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
import '../../../core/widgets/my_requests_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../collection/screens/batch_timeline_screen.dart';
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRejectSampleDialog(BuildContext context, WorkflowRequest req) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Reject Honey Sample', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide reason for lab rejection:', style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor)),
            const SizedBox(height: 12),
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
              context.read<WorkflowController>().rejectRequest(req.id, actorRole: 'LAB', reason: reasonCtrl.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sample rejected & recorded.'), backgroundColor: AppConstants.error),
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
    final requests = context.watch<WorkflowController>().labPendingRequests;

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
                      Tab(text: 'Pending Samples (${requests.length})'),
                      const Tab(text: 'All Lab History'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  requests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.science_outlined, size: 64, color: context.textMutedColor.withValues(alpha: 0.5)),
                              const SizedBox(height: AppConstants.space16),
                              Text(
                                'No pending samples',
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: AppConstants.space8),
                              Text(
                                'Processed batches dispatched by collectors will appear here.',
                                style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppConstants.space16, AppConstants.space16, AppConstants.space16, 120),
                          itemCount: requests.length,
                          separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
                          itemBuilder: (context, index) {
                            final req = requests[index];
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
                                          'Sample: ${(req.labSampleId != null && req.labSampleId!.isNotEmpty) ? req.labSampleId! : req.batchId}',
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
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => BatchTimelineScreen(batchId: req.batchId)),
                                          );
                                        },
                                        child: Text(
                                          'Batch: ${req.batchId}',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.primary,
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
                                      Text(
                                        req.harvesterName,
                                        style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppConstants.space8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 16, color: context.textSecondaryColor),
                                      const SizedBox(width: AppConstants.space8),
                                      Text(
                                        formattedDate,
                                        style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppConstants.space16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            if (!ProfileGuard.checkOrPrompt(context)) return;
                                            _showRejectSampleDialog(context, req);
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppConstants.error,
                                            side: const BorderSide(color: AppConstants.error),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: Text('Reject Sample', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (!ProfileGuard.checkOrPrompt(context)) return;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => LabReportScreen(request: req),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: context.colors.primary,
                                            foregroundColor: context.colors.onPrimary,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: Text('Conduct Test', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  const MyRequestsView(userRole: 'LAB'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

