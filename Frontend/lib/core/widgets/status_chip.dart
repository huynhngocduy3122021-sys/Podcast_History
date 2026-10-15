import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum StatusType { success, warning, error, info, locked, neutral }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusType type;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.type,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData defaultIcon;

    switch (type) {
      case StatusType.success:
        bg = AppColors.successContainer;
        fg = AppColors.success;
        defaultIcon = Icons.check_circle_rounded;
        break;
      case StatusType.warning:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        defaultIcon = Icons.hourglass_top_rounded;
        break;
      case StatusType.error:
        bg = AppColors.errorContainer;
        fg = AppColors.error;
        defaultIcon = Icons.cancel_rounded;
        break;
      case StatusType.info:
        bg = AppColors.infoContainer;
        fg = AppColors.info;
        defaultIcon = Icons.info_rounded;
        break;
      case StatusType.locked:
        bg = AppColors.surfaceVariantLight;
        fg = AppColors.locked;
        defaultIcon = Icons.lock_rounded;
        break;
      case StatusType.neutral:
        bg = AppColors.surfaceVariantLight;
        fg = AppColors.tertiaryLight;
        defaultIcon = Icons.history_edu_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.roundedPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
