import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import '../../profile/controllers/user_controller.dart';
import 'add_edit_hive_screen.dart';
import 'hive_details_screen.dart';

/// Hives list screen — in-body header (no top navbar) with pill Add Hive.
class AllHivesScreen extends StatelessWidget {
  const AllHivesScreen({super.key});

  void _openAddHive(BuildContext context) {
    final userCtrl = context.read<UserController>();
    if (!userCtrl.user.isProfileComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('complete_profile_first'))),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditHiveScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HiveController>();
    final hives = controller.hives;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // In-body header: title + pill Add Hive action
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('hives'),
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Material(
                    color: context.primarySoftColor,
                    borderRadius: BorderRadius.circular(30),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openAddHive(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: context.primaryDarkColor),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('add_hive'),
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.primaryDarkColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('your_active_fields'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),

              const SizedBox(height: AppConstants.space20),

              Expanded(
                child: hives.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        itemCount: hives.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final hive = hives[index];
                          return _buildFieldCard(context, hive);
                        },
                      ),
              ),
              // Clear the floating bottom nav pill
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard(BuildContext context, Hive hive) {
    final healthy = hive.isHealthy;

    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HiveDetailsScreen(hiveId: hive.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppConstants.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      hive.name,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: healthy ? context.successBgColor : context.warningBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      hive.overallHealth,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: healthy ? context.successColor : context.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${hive.hiveCode} · ${hive.apiaryLocation} · ${hive.hiveType}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${hive.currentYearProductionKg.toStringAsFixed(1)} kg this year',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  Text(
                    'Target ${hive.expectedProductionKg.toStringAsFixed(0)} kg',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: context.textMutedColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: hive.expectedProductionKg > 0
                      ? (hive.currentYearProductionKg / hive.expectedProductionKg).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 5,
                  backgroundColor: context.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hive_outlined, size: 56, color: context.textMutedColor),
          const SizedBox(height: AppConstants.space16),
          Text(
            context.tr('no_hives_yet'),
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('no_hives_subtitle'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(30),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openAddHive(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                child: Text(
                  context.tr('add_first_hive'),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
