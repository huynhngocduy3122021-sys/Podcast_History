import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppButtonType { primary, secondary, text, destructive }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final Widget? icon;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = AppSpacing.minTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (type) {
      case AppButtonType.primary:
        backgroundColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
        foregroundColor = isDark ? AppColors.onPrimaryDark : AppColors.onPrimaryLight;
        break;
      case AppButtonType.secondary:
        backgroundColor = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight;
        foregroundColor = isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;
        borderSide = BorderSide(color: isDark ? AppColors.outlineDark : AppColors.outlineLight);
        break;
      case AppButtonType.text:
        backgroundColor = Colors.transparent;
        foregroundColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
        break;
      case AppButtonType.destructive:
        backgroundColor = AppColors.errorContainer;
        foregroundColor = AppColors.error;
        borderSide = const BorderSide(color: AppColors.error);
        break;
    }

    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: effectiveOnPressed == null ? foregroundColor.withValues(alpha: 0.5) : foregroundColor,
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(width ?? 0, height),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.5),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedMd,
            side: borderSide ?? BorderSide.none,
          ),
        ),
        onPressed: effectiveOnPressed,
        child: content,
      ),
    );
  }
}
