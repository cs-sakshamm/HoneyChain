import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_extensions.dart'; // Ensure this path is correct for your project

class HistoryIcon extends StatelessWidget {
  final double size;
  final bool active;
  const HistoryIcon({Key? key, this.size = 24.0, this.active = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use primary color when active, otherwise secondary text color.
    final color = active ? context.primaryColor : context.textSecondaryColor;
    return Icon(Icons.history_rounded, size: size, color: color);
  }
}
