import 'package:flutter/material.dart';

/// Bảng màu chuẩn VietCast theo VietCast_UI_UX_Guidelines.md
class AppColors {
  AppColors._();

  // --- Light Theme ---
  static const Color primaryLight = Color(0xFFB3261E); // Đỏ son
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color secondaryLight = Color(0xFFB8860B); // Vàng đồng
  static const Color tertiaryLight = Color(0xFF1F3A4D); // Xanh mực
  static const Color backgroundLight = Color(0xFFFBF7F0); // Giấy cũ
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1EADF);
  static const Color outlineLight = Color(0xFFD8CFC0);
  static const Color onSurfaceLight = Color(0xFF141312); // Chữ chính đậm rõ nét
  static const Color onSurfaceMutedLight = Color(0xFF4A443E); // Tăng tương phản cao để đọc rõ

  // --- Dark Theme ---
  static const Color primaryDark = Color(0xFFE8665D);
  static const Color onPrimaryDark = Color(0xFF3A0906);
  static const Color secondaryDark = Color(0xFFE0B84A);
  static const Color tertiaryDark = Color(0xFF7FA8C4);
  static const Color backgroundDark = Color(0xFF12100E);
  static const Color surfaceDark = Color(0xFF1C1917);
  static const Color surfaceVariantDark = Color(0xFF2A2623);
  static const Color outlineDark = Color(0xFF4A443F);
  static const Color onSurfaceDark = Color(0xFFF5EFE6);
  static const Color onSurfaceMutedDark = Color(0xFFD4CDC3); // Tăng sáng để đọc rõ

  // --- Semantic Colors (Light & chung) ---
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFB45309); // Hổ phách sẫm, độ tương phản cao dễ đọc
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF1F6FB2);
  static const Color locked = Color(0xFF8A7A5C);

  // Semantic light backgrounds for chips
  static const Color successContainer = Color(0xFFE8F5E9);
  static const Color warningContainer = Color(0xFFFFF3E0);
  static const Color errorContainer = Color(0xFFFFEBEE);
  static const Color infoContainer = Color(0xFFE1F5FE);
}
