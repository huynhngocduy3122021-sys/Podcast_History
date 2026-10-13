import 'package:flutter/material.dart';

/// Hệ thống khoảng cách 4dp scale và bo góc theo VietCast_UI_UX_Guidelines.md
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Lề màn hình chuẩn
  static const double screenMargin = 16.0;

  // Vùng chạm tối thiểu
  static const double minTouchTarget = 48.0;

  // Bo góc
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0; // card, button, podcast cover
  static const double radiusLg = 16.0;
  static const double radiusBottomSheet = 24.0;
  static const double radiusPill = 999.0; // chip

  // Border Radius
  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius roundedBottomSheet = BorderRadius.vertical(top: Radius.circular(radiusBottomSheet));
  static const BorderRadius roundedPill = BorderRadius.all(Radius.circular(radiusPill));
}
