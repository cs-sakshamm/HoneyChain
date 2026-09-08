import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/hive_controller.dart';
import '../widgets/hive_note_card.dart';
import 'add_edit_hive_screen.dart';
import 'hive_details_screen.dart';

import '../../../core/widgets/global_app_bar.dart';

/// Complete "All Hives" screen with search, filtering, sorting, and management
class AllHivesScreen extends StatelessWidget {
  const AllHivesScreen({super.key});

  void _showDeleteDialog(BuildContext context, String hiveId, String hiveName) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete this hive?'),
          content: Text(
            'Are you sure you want to delete "$hiveName"? This action cannot be undone.',
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
                final success = await controller.deleteHive(hiveId);
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
              child: const Text('Delete Hive', style: TextStyle(color: AppConstants.error, fontWeight: FontWeight.w600)),
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
      'All',
      'Healthy',
      'Needs Attention',
      'High Production',
      'Recently Inspected',
    ];

    final sortOptions = [
      'Name A-Z',
      'Production High-Low',
      'Last Inspected',
      'Date Added',
    ];

    return Scaffold(
      backgroundColor: AppConstants.background,
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
                  color: AppConstants.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppConstants.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppConstants.primaryDark),
                    SizedBox(width: 4),
                    Text(
                      'Add Hive',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.primaryDark,
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
            color: AppConstants.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space16,
              vertical: AppConstants.space12,
            ),
            child: Column(
              children: [
                // Search Input Field
                TextField(
                  onChanged: (val) => controller.setSearchQuery(val),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by hive name, ID, or location...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppConstants.textMuted, size: 20),
                    suffixIcon: controller.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppConstants.textMuted),
                            onPressed: () => controller.setSearchQuery(''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    fillColor: AppConstants.background,
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
                        color: AppConstants.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppConstants.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: controller.selectedSort,
                          icon: const Icon(Icons.sort_rounded, size: 16, color: AppConstants.textSecondary),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textPrimary),
                          onChanged: (val) {
                            if (val != null) controller.setSort(val);
                          },
                          items: sortOptions.map((opt) {
                            return DropdownMenuItem(
                              value: opt,
                              child: Text(opt),
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
                          children: filterOptions.map((filter) {
                            final isSelected = controller.selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppConstants.textSecondary,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppConstants.primaryDark,
                                backgroundColor: AppConstants.background,
                                side: BorderSide(
                                  color: isSelected ? AppConstants.primaryDark : AppConstants.border,
                                ),
                                showCheckmark: false,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                onSelected: (_) => controller.setFilter(filter),
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
          const Divider(height: 1),

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
              hasSearchOrFilter ? 'No matching hives found' : 'No hives added yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearchOrFilter
                  ? 'Try adjusting your search query or clear active filters.'
                  : 'Create your first hive to start tracking production and health.',
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
                child: const Text('Clear Filters'),
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
                label: const Text('Add Your First Hive'),
              ),
          ],
        ),
      ),
    );
  }
}
