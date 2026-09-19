import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pill_back_button.dart';

/// Clean Flag-free Indian Language Picker (English + 22 Scheduled Indian Languages)
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
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const PillBackButton(),
                  const SizedBox(width: 14),
                  Text(
                    langCtrl.tr('select_language') == 'select_language' ? 'Select Language' : langCtrl.tr('select_language'),
                    style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimaryColor, letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
            // Search Field
            Container(
              color: context.surfaceColor,
              padding: const EdgeInsets.all(AppConstants.space16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(fontSize: 14, color: context.textPrimaryColor),
                decoration: InputDecoration(
                  hintText: langCtrl.tr('search_language_hint'),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.textMutedColor),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 18, color: context.textMutedColor),
                          onPressed: () => setState(() => _searchController.clear()),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  fillColor: context.scaffoldBg,
                ),
              ),
            ),
            Divider(height: 1, color: context.borderColor),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppConstants.space16),
                itemCount: filteredLanguages.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppConstants.space8),
                itemBuilder: (context, index) {
                  final lang = filteredLanguages[index];
                  final isSelected = lang.code == langCtrl.currentLanguageCode;

                  return Material(
                    color: context.surfaceColor,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                      side: BorderSide(
                        color: isSelected ? context.accentColor : context.borderColor,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        lang.name,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? context.accentColor : context.textPrimaryColor,
                        ),
                      ),
                      subtitle: Text(
                        lang.nativeName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: context.accentColor, size: 20)
                          : null,
                      onTap: () async {
                        await langCtrl.setLanguage(lang.code);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${lang.name} (${lang.nativeName}) selected'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

