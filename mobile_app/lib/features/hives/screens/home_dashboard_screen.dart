import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/auth_controller.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import 'add_edit_hive_screen.dart';
import 'hive_details_screen.dart';
import 'start_harvesting_screen.dart';

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
    
    // Sort hives to show most recently updated first
    final List<Hive> sortedHives = List.from(hiveController.hives);
    sortedHives.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final primaryHive = sortedHives.isNotEmpty ? sortedHives.first : null;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false, // Let bottom nav handle its own safe area
        child: RefreshIndicator(
          onRefresh: () => hiveController.loadHives(),
          color: context.primaryDarkColor,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppConstants.space24, AppConstants.space24, AppConstants.space24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        '${_greeting(context)}, $userFirstName',
                        style: GoogleFonts.manrope(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Overview of your apiaries and honey collection.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: context.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space32),

                      // Quick Stats / Overview
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context, 
                              title: 'Active Hives', 
                              value: '${hiveController.hives.length}',
                              icon: Icons.hive_rounded,
                            ),
                          ),
                          const SizedBox(width: AppConstants.space16),
                          Expanded(
                            child: _buildStatCard(
                              context, 
                              title: 'Total Yield', 
                              value: '0 kg', // TODO: Calculate real yield from backend
                              icon: Icons.water_drop_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space32),

                      // Actions Row (Add Hive & Start Harvest)
                      Row(
                        children: [
                          Expanded(
                            child: _buildPillButton(
                              context,
                              label: 'Add Hive',
                              icon: Icons.add_rounded,
                              isPrimary: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AddEditHiveScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppConstants.space12),
                          Expanded(
                            child: _buildPillButton(
                              context,
                              label: context.tr('start_harvest'),
                              icon: Icons.play_arrow_rounded,
                              isPrimary: true,
                              onTap: () {
                                if (primaryHive != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => StartHarvestingScreen(hive: primaryHive)),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please add a hive first.')),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space32),

                      // Recent Hives
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Hives',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space16),
                    ],
                  ),
                ),
              ),
              
              // Hive Grid / List
              if (hiveController.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (sortedHives.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(context),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.space24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final hive = sortedHives[index];
                        return _buildHiveCard(context, hive);
                      },
                      childCount: sortedHives.length,
                    ),
                  ),
                ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding for nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.textPrimaryColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: context.primaryDarkColor),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton(BuildContext context, {required String label, required IconData icon, required bool isPrimary, required VoidCallback onTap}) {
    return Material(
      color: isPrimary ? context.primaryDarkColor : context.surfaceColor,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: isPrimary ? null : Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isPrimary ? context.primarySoftColor : context.textPrimaryColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? context.primarySoftColor : context.textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.space24),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.space32),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.hive_outlined, size: 48, color: context.textMutedColor),
            const SizedBox(height: 16),
            Text(
              'No Hives Found',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first hive to start tracking your honey harvest and apiary health.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHiveCard(BuildContext context, Hive hive) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.space16),
      child: Material(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HiveDetailsScreen(hiveId: hive.id)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(AppConstants.space20),
            decoration: BoxDecoration(
              border: Border.all(color: context.borderColor),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: hive.statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.hive_rounded, color: hive.statusColor, size: 28),
                ),
                const SizedBox(width: AppConstants.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hive.name,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hive.location,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.textMutedColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
