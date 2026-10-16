import 'package:intl/intl.dart';

/// Các hàm định dạng tiền tệ, số, thời gian theo chuẩn Việt Nam
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  /// Định dạng tiền VND: 1.000.000 ₫
  static String formatVND(int amount) {
    return _currencyFormat.format(amount).trim();
  }

  /// Định dạng số rút gọn: 12.4K, 1.2M
  static String formatCompactNumber(int number) {
    if (number >= 1000000) {
      final val = (number / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return '${val.endsWith(',0') ? val.substring(0, val.length - 2) : val} Tr';
    } else if (number >= 1000) {
      final val = (number / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return '${val.endsWith(',0') ? val.substring(0, val.length - 2) : val}K';
    }
    return number.toString();
  }

  /// Định dạng thời lượng mm:ss hoặc hh:mm:ss
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  /// Định dạng ngày dd/MM/yyyy
  static String formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  /// Định dạng ngày giờ dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  /// Định dạng thời gian tương đối tiếng Việt
  static String timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return formatDate(dateTime);
  }
}
