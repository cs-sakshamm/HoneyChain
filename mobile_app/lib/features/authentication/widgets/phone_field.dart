import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';

/// A HoneyChain-styled phone field: a tappable country selector (flag, dial
/// code, ISO) fused to the number field with perfectly matched height,
/// borders and vertical alignment. The selected country's calling code is
/// rendered by this widget — the user never types it, so it can never be
/// duplicated inside the number.
class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final CountryInfo country;
  final ValueChanged<CountryInfo> onCountryChanged;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final String label;

  const PhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.label = 'Mobile number',
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocus() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  BorderSide get _borderSide => BorderSide(
        color: _focused ? context.colors.primary : context.borderColor,
        width: _focused ? 1.5 : 1.0,
      );


  Future<void> _pickCountry() async {
    if (!widget.enabled) return;
    final selected = await showModalBottomSheet<CountryInfo>(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.borderRadiusLarge)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            padding: const EdgeInsets.symmetric(vertical: AppConstants.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppConstants.space16),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppConstants.space24),
                  child: Row(
                    children: [
                      Icon(Icons.public_rounded,
                          size: 20, color: context.honeyAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Select country',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.space12),
                Divider(height: 1, color: context.borderColor),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: kSupportedCountries.length,
                    itemBuilder: (listContext, index) {
                      final c = kSupportedCountries[index];
                      final isSelected = c.isoCode == widget.country.isoCode;
                      return Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          leading: Text(c.flag,
                              style: const TextStyle(fontSize: 22)),
                          title: Text(
                            c.name,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? context.honeyAccent
                                  : context.textPrimaryColor,
                            ),
                          ),
                          subtitle: Text(
                            '${c.isoCode} · ${c.dialCode}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondaryColor,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_rounded,
                                  color: context.honeyAccent, size: 20)
                              : null,
                          onTap: () => Navigator.pop(sheetContext, c),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && selected.isoCode != widget.country.isoCode) {
      widget.onCountryChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digitsOnly = widget.country.nsnMaxLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.space6),
        ],
        // Single fused container = guaranteed identical height, border and
        // baseline alignment for both halves on every platform.
        Container(
          height: AppConstants.inputHeight,
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            border: Border.fromBorderSide(_borderSide),
          ),
          child: Row(
            children: [
              // ── Country selector half ──
              InkWell(
                onTap: _pickCountry,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppConstants.borderRadiusSmall),
                ),
                child: Container(
                  height: AppConstants.inputHeight,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.space12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.country.flag,
                          style: const TextStyle(fontSize: 17)),
                      const SizedBox(width: 6),
                      Text(
                        widget.country.dialCode,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: context.textSecondaryColor),
                    ],
                  ),
                ),
              ),

              // ── Separator line between calling code and number ──
              Container(
                width: 1,
                height: 24,
                color: context.borderColor,
              ),

              // ── Number half ──
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-()]')),
                    LengthLimitingTextInputFormatter(digitsOnly + 4),
                  ],
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: context.textPrimaryColor,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.country.nsnHint,
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: context.textMutedColor,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    filled: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
