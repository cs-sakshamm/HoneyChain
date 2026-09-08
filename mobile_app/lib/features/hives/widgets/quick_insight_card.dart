import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Clean Q&A text row for Quick Insights
class QuickInsightCard extends StatelessWidget {
  final String question;
  final String answer;
  final String? subtitle;
  final IconData? icon;
  final Color? answerColor;
  final bool isPositiveTrend;

  const QuickInsightCard({
    super.key,
    required this.question,
    required this.answer,
    this.subtitle,
    this.icon,
    this.answerColor,
    this.isPositiveTrend = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.space8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.space16,
        vertical: AppConstants.space12,
      ),
      decoration: BoxDecoration(
        color: AppConstants.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: AppConstants.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppConstants.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: answerColor ?? AppConstants.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppConstants.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
