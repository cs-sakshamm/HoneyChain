import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/widgets/global_app_bar.dart';

/// Screen to select Application Language (Flag-free 22-language picker with search)
class LanguageSettingScreen extends StatefulWidget {
  const LanguageSettingScreen({super.key});

  @override
  State<LanguageSettingScreen> createState() => _LanguageSettingScreenState();
}

class _LanguageSettingScreenState extends State<LanguageSettingScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCtrl = context.watch<LanguageController>();
    final searchQuery = _searchController.text.trim().toLowerCase();

    final filteredLanguages = LanguageController.supportedLanguages.where((l) {
      if (searchQuery.isEmpty) return true;
      return l.name.toLowerCase().contains(searchQuery) ||
          l.nativeName.toLowerCase().contains(searchQuery) ||
          l.code.toLowerCase().contains(searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: GlobalAppBar(
        showBackButton: true,
        titleText: langCtrl.tr('select_language'),
      ),
      body: Column(
        children: [
          // Search Field
          Container(
            color: AppConstants.surface,
            padding: const EdgeInsets.all(AppConstants.space16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: langCtrl.tr('search_language_hint'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppConstants.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: AppConstants.textMuted),
                        onPressed: () => setState(() => _searchController.clear()),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                fillColor: AppConstants.background,
              ),
            ),
          ),
          const Divider(height: 1),

          // Flag-free Language List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppConstants.space16),
              itemCount: filteredLanguages.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppConstants.space8),
              itemBuilder: (context, index) {
                final lang = filteredLanguages[index];
                final isSelected = lang.code == langCtrl.currentLanguageCode;

                return Container(
                  decoration: BoxDecoration(
                    color: AppConstants.surface,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    border: Border.all(
                      color: isSelected ? AppConstants.primaryDark : AppConstants.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      lang.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppConstants.primaryDark : AppConstants.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      lang.nativeName,
                      style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppConstants.primaryDark, size: 20)
                        : null,
                    onTap: () {
                      langCtrl.setLanguage(lang.code);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Language changed to ${lang.name}'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
