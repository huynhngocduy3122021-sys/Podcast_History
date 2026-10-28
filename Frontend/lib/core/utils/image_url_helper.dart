import 'package:flutter/foundation.dart';

/// Chuyển đổi URL hình ảnh để tránh lỗi CORS trên môi trường Flutter Web
/// khi tải trực tiếp từ Cloudflare R2 bucket (`pub-*.r2.dev`).
String resolveImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  final trimmed = url.trim();
  if (trimmed.startsWith('data:image')) return trimmed;
  if (kIsWeb) {
    if (trimmed.contains('.r2.dev') ||
        trimmed.contains('r2.cloudflarestorage.com') ||
        trimmed.contains('vietqr.app')) {
      if (!trimmed.contains('images.weserv.nl')) {
        return 'https://images.weserv.nl/?url=${Uri.encodeComponent(trimmed)}';
      }
    }
  }
  return trimmed;
}
