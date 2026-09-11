import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/models/workflow_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../authentication/auth_controller.dart';
import '../../profile/controllers/user_controller.dart';
import '../controllers/hive_controller.dart';

class HarvesterDashboardScreen extends StatefulWidget {
  const HarvesterDashboardScreen({super.key});

  @override
  State<HarvesterDashboardScreen> createState() => _HarvesterDashboardScreenState();
}

class _HarvesterDashboardScreenState extends State<HarvesterDashboardScreen> {
  void _showCreateRequestModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _CreateRequestForm(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final userController = context.watch<UserController>();
    final workflowController = context.watch<WorkflowController>();
    final hiveController = context.watch<HiveController>();
    
    final harvesterName = userController.user.name ?? 'Harvester';
    final activeRequests = workflowController.pendingCollectionRequests.length;
    final totalHives = hiveController.hives.length;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('greeting_morning'),
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
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.primarySoftColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.agriculture_rounded, color: context.primaryDarkColor),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppConstants.space32),
                  
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: context.tr('total_hives'),
                          value: totalHives.toString(),
                          icon: Icons.hive_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: context.tr('active_requests'),
                          value: activeRequests.toString(),
                          icon: Icons.pending_actions_rounded,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppConstants.space32),
                  
                  // Create Request Call to Action
                  AppCard(
                    onTap: () => _showCreateRequestModal(context),
                    padding: const EdgeInsets.all(AppConstants.space24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppConstants.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_shopping_cart_rounded, color: context.textPrimaryColor),
                        ),
                        const SizedBox(width: AppConstants.space16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('create_request'),
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Submit a new batch for collection',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: context.textSecondaryColor),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppConstants.space32),
                  
                  Text(
                    context.tr('recent_requests'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  
                  const SizedBox(height: AppConstants.space16),
                ],
              ),
            ),
          ),
          
          if (workflowController.allRequests.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    context.tr('no_requests_yet'),
                    style: GoogleFonts.inter(
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Sort by most recent
                  final sortedRequests = List<WorkflowRequest>.from(workflowController.allRequests)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  
                  final request = sortedRequests[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.monitor_weight_outlined, size: 16, color: context.textSecondaryColor),
                              const SizedBox(width: 8),
                              Text(
                                '${request.estimatedQuantityKg} kg',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.location_on_outlined, size: 16, color: context.textSecondaryColor),
                              const SizedBox(width: 8),
                              Text(
                                request.location,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: context.textSecondaryColor,
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
            child: SizedBox(height: 100), // padding for bottom nav
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
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 16, color: context.textSecondaryColor),
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
          const SizedBox(height: 12),
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

class _CreateRequestForm extends StatefulWidget {
  const _CreateRequestForm();

  @override
  State<_CreateRequestForm> createState() => _CreateRequestFormState();
}

class _CreateRequestFormState extends State<_CreateRequestForm> {
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    final qtyStr = _quantityController.text.trim();
    final location = _locationController.text.trim();

    if (qtyStr.isEmpty || location.isEmpty) return;

    final qty = double.tryParse(qtyStr);
    if (qty == null) return;

    final userController = context.read<UserController>();
    final workflowController = context.read<WorkflowController>();

    workflowController.createRequest(
      harvesterName: userController.user.name ?? 'Unknown Harvester',
      location: location,
      estimatedQuantityKg: qty,
      collectionType: 'Raw Honey',
      description: 'New collection request',
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('create_request'),
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimaryColor,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.textSecondaryColor),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _locationController,
            labelText: 'Collection Location',
            hintText: 'Enter location',
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            labelText: context.tr('estimated_quantity'),
            hintText: 'e.g. 50.5',
            prefixIcon: const Icon(Icons.monitor_weight_outlined),
          ),
          const SizedBox(height: 32),
          AppButton(
            text: context.tr('submit_request'),
            onPressed: _submit,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

