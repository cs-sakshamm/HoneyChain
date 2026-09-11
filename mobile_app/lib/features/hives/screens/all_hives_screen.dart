import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import 'add_edit_hive_screen.dart';
import 'hive_details_screen.dart';

/// Clean Hives & Active Fields List Screen
class AllHivesScreen extends StatelessWidget {
  const AllHivesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HiveController>();
    final hives = controller.hives;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: GlobalAppBar(
        extraActions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Consumer<UserController>(
              builder: (context, userCtrl, _) {
                return TextButton.icon(
                  onPressed: () {
                    if (!userCtrl.user.isProfileComplete) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please complete your profile (name, email, phone) before adding hives.')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddEditHiveScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.add_rounded, size: 18, color: context.textPrimaryColor),
                  label: Text(
                    context.tr('add_hive'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            Text(
              context.tr('hives'),
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
                letterSpacing: -0.4,
              ),
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

            // Active Field List
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
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(BuildContext context, Hive hive) {
    final cropType = hive.queenStatus.isNotEmpty ? hive.queenStatus : 'Wheat';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HiveDetailsScreen(hiveId: hive.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.space16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hive.name,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppConstants.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.tr('in_progress'),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$cropType · 12 acres',
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
                  '71% complete',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                Text(
                  '8.5 / 12.0 acres',
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
                value: 0.71,
                minHeight: 5,
                backgroundColor: context.borderColor,
                valueColor: const AlwaysStoppedAnimation<Color>(context.colors.primary),
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
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditHiveScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
            ),
            child: Text(
              context.tr('add_first_hive'),
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
