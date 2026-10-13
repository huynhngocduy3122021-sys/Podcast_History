import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Hệ thống Typography theo VietCast_UI_UX_Guidelines.md
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'BeVietnamPro';

  static TextTheme textTheme(bool isDark) {
    final Color onSurface = isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;
    final Color onSurfaceMuted = isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight;

    return TextTheme(
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.25,
        color: onSurface,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: onSurface,
      ),
      labelLarge: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: onSurfaceMuted,
      ),
    );
  }

  /// Style cho số liệu và timestamp: thẳng hàng, tabular figures
  static TextStyle tabularNumbers({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color,
    );
  }
}
