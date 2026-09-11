import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import 'harvester_detail_screen.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/localization/localization_service.dart';
import '../../profile/controllers/user_controller.dart';
class CollectionDashboardScreen extends StatelessWidget {
  const CollectionDashboardScreen({super.key});

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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('collection_processing') == 'collection_processing' 
                        ? 'Collection & Processing' 
                        : context.tr('collection_processing'),
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${requests.length} ${context.tr('pending_requests') == 'pending_requests' ? 'pending requests' : context.tr('pending_requests')}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: requests.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.all(AppConstants.space16),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppConstants.space16),
              itemBuilder: (context, index) {
                final req = requests[index];
                return _buildRequestCard(context, req);
              },
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
            context.tr('no_pending_requests') == 'no_pending_requests' 
                ? 'No pending requests' 
                : context.tr('no_pending_requests'),
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Text(
            context.tr('no_pending_requests_subtitle') == 'no_pending_requests_subtitle' 
                ? 'You are all caught up for now.' 
                : context.tr('no_pending_requests_subtitle'),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, WorkflowRequest req) {
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
              Text(
                req.batchId,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textMutedColor,
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
                  DateFormat('MMM d, yyyy â€¢ h:mm a').format(req.createdAt),
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
                  context.tr('est_quantity') == 'est_quantity' ? 'Est. Quantity:' : context.tr('est_quantity'),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final userCtrl = context.read<UserController>();
                    if (!userCtrl.user.isProfileComplete) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your profile first.')));
                      return;
                    }
                    context.read<WorkflowController>().denyRequest(req.id, "Denied by Processor");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('request_denied') == 'request_denied' ? 'Request denied' : context.tr('request_denied'))),
                    );
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
                    context.tr('deny') == 'deny' ? 'Deny' : context.tr('deny'),
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.space12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final userCtrl = context.read<UserController>();
                    if (!userCtrl.user.isProfileComplete) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your profile first.')));
                      return;
                    }
                    context.read<WorkflowController>().acceptRequest(req.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('request_accepted') == 'request_accepted' ? 'Request accepted' : context.tr('request_accepted'))),
                    );
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
                    context.tr('accept') == 'accept' ? 'Accept' : context.tr('accept'),
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
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

