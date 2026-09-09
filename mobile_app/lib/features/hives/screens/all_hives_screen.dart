import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/global_app_bar.dart';
import '../controllers/hive_controller.dart';
import '../widgets/hive_note_card.dart';
import 'add_edit_hive_screen.dart';
import 'hive_details_screen.dart';

/// Complete "All Hives" screen with search, filtering, sorting, and management
class AllHivesScreen extends StatelessWidget {
  const AllHivesScreen({super.key});

  void _showDeleteDialog(BuildContext context, String hiveId, String hiveName) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr('delete_confirm_title')),
          content: Text(
            '${dialogContext.tr('delete_confirm_msg')} ("$hiveName")',
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
                final success = await controller.deleteHive(hiveId);
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
              child: Text(dialogContext.tr('delete_hive'), style: const TextStyle(color: AppConstants.error, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HiveController>();
    final hives = controller.filteredAndSortedHives;

    final filterOptions = [
      {'key': 'All', 'label': context.tr('all')},
      {'key': 'Healthy', 'label': context.tr('healthy')},
      {'key': 'Needs Attention', 'label': context.tr('needs_attention')},
      {'key': 'High Production', 'label': context.tr('high_production')},
      {'key': 'Recently Inspected', 'label': context.tr('recently_inspected')},
    ];

    final sortOptions = [
      {'key': 'Name A-Z', 'label': context.tr('sort_name')},
      {'key': 'Production High-Low', 'label': context.tr('sort_production')},
      {'key': 'Last Inspected', 'label': context.tr('sort_inspected')},
      {'key': 'Date Added', 'label': context.tr('sort_date_added')},
    ];

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: GlobalAppBar(
        extraActions: [
          Padding(
            padding: const EdgeInsets.only(right: AppConstants.space8),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEditHiveScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.primarySoftColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppConstants.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: context.primaryDarkColor),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('add_hive'),
                      style: TextStyle(
                        fontSize: 12,
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
      body: Column(
        children: [
          // Search & Filter Container
          Container(
            color: context.surfaceColor,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space16,
              vertical: AppConstants.space12,
            ),
            child: Column(
              children: [
                // Search Input Field
                TextField(
                  onChanged: (val) => controller.setSearchQuery(val),
                  style: TextStyle(fontSize: 14, color: context.textPrimaryColor),
                  decoration: InputDecoration(
                    hintText: context.tr('search_hives_full_hint'),
                    prefixIcon: Icon(Icons.search_rounded, color: context.textMutedColor, size: 20),
                    suffixIcon: controller.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, size: 18, color: context.textMutedColor),
                            onPressed: () => controller.setSearchQuery(''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    fillColor: context.scaffoldBg,
                  ),
                ),
                const SizedBox(height: AppConstants.space12),

                // Horizontal Filter Chips & Sort Selector
                Row(
                  children: [
                    // Sort Dropdown Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: context.scaffoldBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: controller.selectedSort,
                          dropdownColor: context.surfaceColor,
                          icon: Icon(Icons.sort_rounded, size: 16, color: context.textSecondaryColor),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                          onChanged: (val) {
                            if (val != null) controller.setSort(val);
                          },
                          items: sortOptions.map((opt) {
                            return DropdownMenuItem(
                              value: opt['key']!,
                              child: Text(opt['label']!),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.space8),
                    // Scrollable Filter Chips
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filterOptions.map((opt) {
                            final filterKey = opt['key']!;
                            final filterLabel = opt['label']!;
                            final isSelected = controller.selectedFilter == filterKey;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(
                                  filterLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : context.textSecondaryColor,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppConstants.primary,
                                backgroundColor: context.scaffoldBg,
                                side: BorderSide(
                                  color: isSelected ? AppConstants.primary : context.borderColor,
                                ),
                                showCheckmark: false,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                onSelected: (_) => controller.setFilter(filterKey),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.borderColor),

          // Main List of Hives
          Expanded(
            child: hives.isEmpty
                ? _buildEmptyState(context, controller)
                : ListView.builder(
                    padding: const EdgeInsets.all(AppConstants.space16),
                    itemCount: hives.length,
                    itemBuilder: (context, index) {
                      final hive = hives[index];
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
                        onDelete: () => _showDeleteDialog(context, hive.id, hive.name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, HiveController controller) {
    final hasSearchOrFilter =
        controller.searchQuery.isNotEmpty || controller.selectedFilter != 'All';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppConstants.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 36,
                color: AppConstants.primaryDark,
              ),
            ),
            const SizedBox(height: AppConstants.space16),
            Text(
              hasSearchOrFilter ? context.tr('no_matching_hives') : context.tr('no_hives_yet'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearchOrFilter
                  ? context.tr('no_matching_hives_subtitle')
                  : context.tr('no_hives_subtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.space24),
            if (hasSearchOrFilter)
              OutlinedButton(
                onPressed: () {
                  controller.setSearchQuery('');
                  controller.setFilter('All');
                },
                child: Text(context.tr('clear_filters')),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryDark,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEditHiveScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr('add_first_hive')),
              ),
          ],
        ),
      ),
    );
  }
}

