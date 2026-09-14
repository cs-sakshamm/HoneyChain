import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HistoryIcon extends StatelessWidget {
  final double size;
  final bool active;
  const HistoryIcon({super.key, this.size = 24.0, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? context.primaryDarkColor : context.textSecondaryColor;
    return Icon(Icons.history_rounded, size: size, color: color);
  }
}
