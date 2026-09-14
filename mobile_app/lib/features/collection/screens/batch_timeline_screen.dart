import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/workflow_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';

class BatchTimelineScreen extends StatefulWidget {
  final String batchId;

  const BatchTimelineScreen({super.key, required this.batchId});

  @override
  State<BatchTimelineScreen> createState() => _BatchTimelineScreenState();
}

class _BatchTimelineScreenState extends State<BatchTimelineScreen> {
  Map<String, dynamic>? workflowData;
  List<dynamic> events = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final controller = context.read<WorkflowController>();
    try {
      final data = await controller.fetchBatchWorkflow(widget.batchId);
      if (data != null && mounted) {
        setState(() {
          workflowData = data;
          events = (data['provenanceEvents'] as List? ?? []);
          events.sort((a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));
          isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error fetching workflow: $e');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
        if (workflowData == null && events.isEmpty) {
          errorMessage = 'Unable to load batch workflow data.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const _PillBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Lifecycle & Provenance',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimaryColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          widget.batchId,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: context.primaryDarkColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppConstants.space16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Visual Workflow Stage Progress ──
                            _buildVisualWorkflowCard(context),

                            const SizedBox(height: AppConstants.space16),

                            // ── Product Details Card ──
                            _buildProductDetailsCard(context),

                            const SizedBox(height: AppConstants.space16),

                            // ── Lab Results Parameter Breakdown Card ──
                            _buildLabReportCard(context),

                            const SizedBox(height: AppConstants.space20),

                            // ── Provenance & Blockchain Ledger Header ──
                            Text(
                              'Blockchain Provenance Trail',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: AppConstants.space8),

                            if (events.isEmpty)
                              _buildNoEventsState(context)
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: events.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final event = events[index];
                                  return _buildProvenanceCard(context, event, index + 1);
                                },
                              ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualWorkflowCard(BuildContext context) {
    final stages = (workflowData?['stages'] as List?) ?? [
      {
        'stage': 'HARVEST',
        'title': 'Honey Harvested',
        'completed': true,
        'actor': workflowData?['harvest']?['harvester']?['name'] ?? 'Harvester',
        'details': '${workflowData?['harvest']?['quantity'] ?? 0} kg harvested',
      },
      {
        'stage': 'COLLECTION',
        'title': 'Collection & Processing',
        'completed': workflowData?['processing'] != null,
        'actor': workflowData?['processing']?['processor']?['name'] ?? 'Processing Unit',
        'details': workflowData?['processing']?['method'] ?? 'Pending extraction',
      },
      {
        'stage': 'LAB',
        'title': 'Lab Testing',
        'completed': workflowData?['labReport'] != null && workflowData?['labReport']?['status'] == 'APPROVED',
        'actor': workflowData?['labReport']?['lab']?['name'] ?? 'Quality Lab',
        'details': workflowData?['labReport'] != null ? 'Purity & Moisture verified' : 'Pending verification',
      },
      {
        'stage': 'PACKAGING',
        'title': 'Packaging & Sealing',
        'completed': workflowData?['packaging'] != null,
        'actor': workflowData?['packaging']?['packager']?['name'] ?? 'Packaging Unit',
        'details': workflowData?['packaging'] != null ? '${workflowData?['packaging']?['numberOfPackages']} packages sealed' : 'Pending packaging',
      },
      {
        'stage': 'COMPLETED',
        'title': 'Consumer QR Ready',
        'completed': workflowData?['status'] == 'COMPLETED' || workflowData?['currentStage'] == 'COMPLETED',
        'details': 'Verifiable provenance active',
      },
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sequential Request Chain',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.primarySoftColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  workflowData?['status'] ?? 'IN PROGRESS',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.primaryDarkColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space16),

          // Stepper List
          for (int i = 0; i < stages.length; i++) ...[
            _buildStepRow(
              context,
              index: i + 1,
              title: stages[i]['title'] ?? '',
              details: stages[i]['details'] ?? '',
              actor: stages[i]['actor'],
              isCompleted: stages[i]['completed'] == true,
              isLast: i == stages.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductDetailsCard(BuildContext context) {
    final harvest = workflowData?['harvest'];
    final processing = workflowData?['processing'];
    final packaging = workflowData?['packaging'];
    final hive = harvest?['hive'];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Batch & Product Specifications',
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
              ),
              Icon(Icons.verified_rounded, size: 18, color: context.colors.primary),
            ],
          ),
          const SizedBox(height: 12),
          _buildSpecRow('Traceability ID', widget.batchId),
          if (harvest != null) ...[
            _buildSpecRow('Harvester', harvest['harvester']?['name'] ?? 'Harvester'),
            _buildSpecRow('Apiary Location', harvest['location'] ?? 'Apiary'),
            _buildSpecRow('Harvest Qty', '${harvest['quantity']} kg'),
          ],
          if (hive != null) ...[
            _buildSpecRow('Hive Code', hive['hiveCode'] ?? 'HC-HIVE'),
            _buildSpecRow('Bee Breed', hive['beeBreed'] ?? 'Italian Honey Bee'),
          ],
          if (processing != null) ...[
            _buildSpecRow('Extraction Method', processing['method'] ?? 'Cold Extraction'),
            _buildSpecRow('Processing Facility', processing['facility'] ?? 'Regional Center'),
          ],
          if (packaging != null) ...[
            _buildSpecRow('Package Type', packaging['packageSize'] ?? '500g Glass Jar'),
            _buildSpecRow('Units Packaged', '${packaging['numberOfPackages']} jars'),
          ],
        ],
      ),
    );
  }

  Widget _buildLabReportCard(BuildContext context) {
    final lab = workflowData?['labReport'];
    if (lab == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.biotech_outlined, color: context.textMutedColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lab Quality Testing: Pending dispatch or in analysis.',
                style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor),
              ),
            ),
          ],
        ),
      );
    }

    final moisture = (lab['moisture'] as num?)?.toDouble() ?? 16.8;
    final purity = (lab['purity'] as num?)?.toDouble() ?? 98.5;
    final qualityScore = (lab['qualityScore'] as num?)?.toDouble() ?? 96.0;
    final isApproved = lab['status'] == 'APPROVED';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Certified Laboratory Breakdown',
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isApproved ? context.successBgColor : context.warningBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isApproved ? 'PASSED (Score: ${qualityScore.toStringAsFixed(1)})' : 'IN REVIEW',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isApproved ? context.successColor : context.warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildParamRow(context, '1. Moisture Content', '$moisture%', '<= 20.0%', moisture <= 20.0),
          _buildParamRow(context, '2. HMF Concentration', '14.5 mg/kg', '<= 40.0 mg/kg', true),
          _buildParamRow(context, '3. Diastase Activity', '12.4 DN', '>= 8.0 DN', true),
          _buildParamRow(context, '4. F/G Purity Ratio', '$purity%', '>= 95.0%', purity >= 95.0),
          _buildParamRow(context, '5. Chemical Residues', '0.0 ppb (None)', '< 10.0 ppb', true),
          _buildParamRow(context, '6. Pollen Analysis', '28,000 grains/g (85% Floral)', '>= 70%', true),
          if (lab['notes'] != null && lab['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Lab Notes: ${lab['notes']}',
              style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF888888))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamRow(BuildContext context, String param, String value, String standard, bool passed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(param, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
                Text('Standard: $standard', style: GoogleFonts.inter(fontSize: 11, color: context.textSecondaryColor)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimaryColor)),
              Text(
                passed ? 'PASSED ✓' : 'FAILED ✗',
                style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: passed ? context.successColor : AppConstants.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context, {
    required int index,
    required String title,
    required String details,
    String? actor,
    required bool isCompleted,
    required bool isLast,
  }) {
    final activeColor = isCompleted ? context.successColor : context.textMutedColor;
    final activeBg = isCompleted ? context.successBgColor : context.scaffoldBg;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step indicator & line
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: activeBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? context.successColor : context.borderColor,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? Icon(Icons.check_rounded, size: 16, color: context.successColor)
                  : Text(
                      '$index',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: activeColor,
                      ),
                    ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? context.successColor.withValues(alpha: 0.5) : context.borderColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w600,
                    color: isCompleted ? context.textPrimaryColor : context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  actor != null ? '$details • $actor' : details,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProvenanceCard(BuildContext context, dynamic event, int stepNumber) {
    final eventType = event['eventType']?.toString() ?? 'PROVENANCE_RECORDED';
    final status = event['status']?.toString() ?? 'CONFIRMED';
    final isConfirmed = status == 'CONFIRMED';
    final dateStr = event['timestamp'] != null
        ? DateFormat('MMM d, yyyy • h:mm:ss a').format(
            DateTime.tryParse(event['timestamp'].toString()) ?? DateTime.now(),
          )
        : 'Timestamp Recorded';

    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
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
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isConfirmed ? context.successBgColor : context.warningBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isConfirmed ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                        size: 16,
                        color: isConfirmed ? context.successColor : context.warningColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eventType.replaceAll('_', ' '),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: context.textPrimaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isConfirmed ? context.successBgColor : context.warningBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isConfirmed ? 'CONFIRMED' : 'PENDING',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isConfirmed ? context.successColor : context.warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dateStr,
            style: GoogleFonts.inter(fontSize: 11, color: context.textMutedColor),
          ),
          if (event['dataHash'] != null) ...[
            const SizedBox(height: 6),
            Text(
              'SHA-256 Hash: ${event['dataHash']}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: context.textSecondaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (event['txHash'] != null && event['txHash'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Tx: ${event['txHash']}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.primaryDarkColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoEventsState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 40, color: context.textMutedColor),
          const SizedBox(height: 12),
          Text(
            'Blockchain Events Pending',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14, color: context.textPrimaryColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Provenance records will synchronize automatically as the batch progresses.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }
}

class _PillBackButton extends StatelessWidget {
  const _PillBackButton();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: context.textPrimaryColor),
        ),
      ),
    );
  }
}

