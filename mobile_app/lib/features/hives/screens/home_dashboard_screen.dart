import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../../authentication/auth_controller.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import 'all_hives_screen.dart';
import 'hive_details_screen.dart';
import 'start_harvesting_screen.dart';

/// Distinctive, Minimal Harvester Home Screen
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.tr('greeting_morning');
    if (hour < 17) return context.tr('greeting_afternoon');
    return context.tr('greeting_evening');
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;
    final hiveController = context.watch<HiveController>();

    final userDisplayName = user?.displayName ?? 'Harvester';
    final userFirstName = userDisplayName.split(' ').first;
    final primaryHive = hiveController.hives.isNotEmpty ? hiveController.hives.first : null;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: const GlobalAppBar(),
      body: RefreshIndicator(
        onRefresh: () => hiveController.loadHives(),
        color: context.primaryDarkColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Greeting
              Text(
                '${_greeting(context)}, $userFirstName',
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('harvest_overview_sub'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),

              const SizedBox(height: AppConstants.space24),

              // 2. Today's Progress Card (One Strong Number)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.space20),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('todays_progress'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.textMutedColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '8.5 acres',
                          style: GoogleFonts.manrope(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimaryColor,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppConstants.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '71% completed',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.space16),

              // 3. Current Field Section with Clean Icon-Only Hive Shortcut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('current_field'),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.hive_outlined, size: 20, color: context.primaryDarkColor),
                    tooltip: context.tr('all_hives'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllHivesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildCurrentFieldSection(context, primaryHive),

              const SizedBox(height: AppConstants.space16),

              // 4. Compact Machine & Fuel Level Row
              Row(
                children: [
                  Expanded(
                    child: _buildCompactInfoBox(
                      context,
                      label: context.tr('machine'),
                      value: context.tr('machine_ready'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactInfoBox(
                      context,
                      label: context.tr('fuel_level'),
                      value: '72%',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.space12),

              // 5. Weather Compact Row
              _buildCompactInfoBox(
                context,
                label: context.tr('weather'),
                value: '28°C · Clear',
              ),

              const SizedBox(height: AppConstants.space16),

              // 6. Maintenance Alert Notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConstants.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(color: AppConstants.warning.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 20, color: AppConstants.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('maintenance_due'),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.warning,
                            ),
                          ),
                          Text(
                            context.tr('maintenance_sub'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.space24),

              // 7. Strongest Visual Action: Start Harvest CTA
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StartHarvestingScreen(hive: primaryHive),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
                  label: Text(
                    context.tr('start_harvest'),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.space32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentFieldSection(BuildContext context, Hive? hive) {
    final fieldName = hive?.name ?? 'North Field - Hive #04';
    final locationName = hive?.location.isNotEmpty == true ? hive!.location : 'Sector 4, West Ridge';
    final cropType = hive?.queenStatus.isNotEmpty == true ? hive!.queenStatus : 'Wheat / Mustard';

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: context.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        child: InkWell(
          onTap: () {
            if (hive != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HiveDetailsScreen(hiveId: hive.id),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllHivesScreen(),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fieldName,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$locationName · $cropType',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.primarySoftColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.tr('in_progress'),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.primaryDarkColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.space12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '71% complete',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    Text(
                      '8.5 / 12.0 acres',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.textMutedColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.71,
                    minHeight: 6,
                    backgroundColor: context.borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.primary),
                  ),
                ),
                const SizedBox(height: AppConstants.space12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      context.tr('view_hive_details'),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.primaryDarkColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: context.primaryDarkColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfoBox(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.textSecondaryColor,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
