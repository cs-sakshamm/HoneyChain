import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Production Input Field Component for HoneyChain
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final String? labelText;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const AppTextField({
    super.key,
    this.controller,
    required this.hintText,
    this.labelText,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.space6),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: context.textPrimaryColor,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: context.textMutedColor,
            ),
            helperText: helperText,
            helperStyle: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor),
            errorText: errorText,
            errorStyle: GoogleFonts.inter(fontSize: 12, color: AppConstants.error),
            fillColor: context.surfaceColor,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              borderSide: BorderSide(color: context.borderColor, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              borderSide: const BorderSide(color: AppConstants.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              borderSide: const BorderSide(color: AppConstants.error, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
              borderSide: const BorderSide(color: AppConstants.error, width: 1.5),
            ),
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: prefixIcon,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: suffixIcon,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
      ],
    );
  }
}

