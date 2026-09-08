import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../../authentication/auth_controller.dart';
import '../controllers/hive_controller.dart';
import '../models/hive_model.dart';
import '../widgets/add_hive_card.dart';
import '../widgets/hive_note_card.dart';
import 'add_edit_hive_screen.dart';
import 'all_hives_screen.dart';
import 'hive_details_screen.dart';

/// Post-login Home/Dashboard Screen inspired by Google Keep / Google Notes
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  void _showDeleteConfirmation(BuildContext context, Hive hive) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete this hive?'),
          content: Text(
            'Are you sure you want to delete "${hive.name}"? This action cannot be undone.',
            style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final controller = context.read<HiveController>();
                final success = await controller.deleteHive(hive.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Hive deleted' : 'Failed to delete hive',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text(
                'Delete Hive',
                style: TextStyle(color: AppConstants.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;
    final hiveController = context.watch<HiveController>();

    final userDisplayName = user?.displayName ?? 'Beekeeper';
    final userFirstName = userDisplayName.split(' ').first;

    final recentHives = hiveController.recentHives;
    final totalHivesCount = hiveController.hives.length;

    String greeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good morning';
      if (hour < 17) return 'Good afternoon';
      return 'Good evening';
    }

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: const GlobalAppBar(),
      body: hiveController.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppConstants.primaryDark),
            )
          : RefreshIndicator(
              onRefresh: () => hiveController.loadHives(),
              color: AppConstants.primaryDark,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Natural Human Greeting
                    Text(
                      '${greeting()}, $userFirstName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Here is the current status of your apiaries.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppConstants.space24),

                    // 2. Prominent Add Hive Card
                    AddHiveCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddEditHiveScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: AppConstants.space32),

                    // 2. Recent Hives Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Hives',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (totalHivesCount > 0)
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AllHivesScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Text(
                                    'Show more',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppConstants.primaryDark,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: AppConstants.primaryDark,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppConstants.space16),

                    // 3. Recent Hives List or Empty State
                    if (recentHives.isEmpty)
                      _buildEmptyState(context)
                    else
                      Column(
                        children: recentHives.map((hive) {
                          return HiveNoteCard(
                            hive: hive,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HiveDetailsScreen(hiveId: hive.id),
                                ),
                              );
                            },
                            onEdit: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddEditHiveScreen(hive: hive),
                                ),
                              );
                            },
                            onDelete: () => _showDeleteConfirmation(context, hive),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: AppConstants.space32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space32),
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppConstants.border, width: 1.0),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppConstants.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hive_outlined,
              size: 36,
              color: AppConstants.primaryDark,
            ),
          ),
          const SizedBox(height: AppConstants.space16),
          const Text(
            'No hives added yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first hive to start tracking production and health.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.space24),
          AppButton(
            text: 'Add Your First Hive',
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            variant: AppButtonVariant.primary,
            width: 220,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditHiveScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
