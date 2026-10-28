import 'package:flutter/foundation.dart';

/// Chuyển đổi URL hình ảnh để tránh lỗi CORS trên môi trường Flutter Web
/// khi tải trực tiếp từ Cloudflare R2 bucket (`pub-*.r2.dev`) hoặc các cổng thanh toán (`vietqr.app`).
String resolveImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  final trimmed = url.trim();
  if (trimmed.startsWith('data:image')) return trimmed;
  if (kIsWeb) {
    if (trimmed.contains('.r2.dev') ||
        trimmed.contains('r2.cloudflarestorage.com') ||
        trimmed.contains('vietqr') ||
        trimmed.contains('sepay')) {
      if (!trimmed.contains('images.weserv.nl') && !trimmed.contains('wsrv.nl')) {
        return 'https://images.weserv.nl/?url=${Uri.encodeComponent(trimmed)}';
      }
    }
  }
  return trimmed;
}
