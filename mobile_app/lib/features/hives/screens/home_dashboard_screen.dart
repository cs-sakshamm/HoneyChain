import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
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
          title: Text(dialogContext.tr('delete_confirm_title')),
          content: Text(
            '${dialogContext.tr('delete_confirm_msg')} ("${hive.name}")',
            style: TextStyle(fontSize: 14, color: dialogContext.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('cancel'), style: TextStyle(color: dialogContext.textSecondaryColor)),
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
                        success ? context.tr('hive_deleted') : context.tr('failed_to_delete_hive'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(
                dialogContext.tr('delete_hive'),
                style: const TextStyle(color: AppConstants.error, fontWeight: FontWeight.w600),
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
      if (hour < 12) return context.tr('greeting_morning');
      if (hour < 17) return context.tr('greeting_afternoon');
      return context.tr('greeting_evening');
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: const GlobalAppBar(),
      body: hiveController.isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.primaryDarkColor),
            )
          : RefreshIndicator(
              onRefresh: () => hiveController.loadHives(),
              color: context.primaryDarkColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Natural Human Greeting
                    Text(
                      '${greeting()}, $userFirstName',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('status_apiaries_sub'),
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondaryColor,
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
                        Text(
                          context.tr('recent_hives'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimaryColor,
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Text(
                                    context.tr('show_more'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppConstants.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
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
          Text(
            context.tr('no_hives_yet'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('no_hives_subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.space24),
          AppButton(
            text: context.tr('add_first_hive'),
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

