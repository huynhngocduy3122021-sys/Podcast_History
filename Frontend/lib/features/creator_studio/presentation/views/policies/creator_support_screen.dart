import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';

/// Màn hình Trung tâm trợ giúp Creator & Hỗ trợ kỹ thuật VietCast
class CreatorSupportScreen extends StatelessWidget {
  const CreatorSupportScreen({super.key});

  static const String supportEmail = 'chanhnghia04@gmail.com';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trung tâm trợ giúp Creator'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
          vertical: AppSpacing.md,
        ),
        children: [
          // Banner đầu trang
          _buildHeaderBanner(isDark),
          const SizedBox(height: AppSpacing.lg),

          // Kênh liên hệ chính thức
          _buildSectionTitle('Kênh liên hệ trực tiếp', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildContactCard(
            icon: Icons.email_rounded,
            title: 'Email Hỗ trợ Kỹ thuật & Kiểm duyệt',
            value: supportEmail,
            subtitle: 'Tiếp nhận báo lỗi kỹ thuật, thẩm định tư liệu và giải đáp thắc mắc',
            isDark: isDark,
            onTap: () => _copyEmail(context),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Thời gian cam kết xử lý (SLA)
          _buildSectionTitle('Thời gian xử lý cam kết (SLA)', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildSlaContainer(isDark),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.secondaryDark : AppColors.secondaryLight).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              size: 28,
              color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hỗ trợ kỹ thuật & Vận hành Kênh',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Đội ngũ VietCast luôn sẵn sàng giải đáp và xử lý các vấn đề kỹ thuật của bạn.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlaContainer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Column(
        children: [
          _buildSlaRow(
            'Sự cố kỹ thuật & Tải lên file:',
            'Dưới 04 giờ làm việc',
            AppColors.success,
            isDark,
          ),
          const Divider(height: 16),
          _buildSlaRow(
            'Kiểm duyệt & Kháng nghị podcast:',
            '12 – 24 giờ làm việc',
            AppColors.info,
            isDark,
          ),
          const Divider(height: 16),
          _buildSlaRow(
            'Tranh chấp hợp đồng (Dispute):',
            '3 – 5 ngày làm việc',
            AppColors.warning,
            isDark,
          ),
          const Divider(height: 16),
          _buildSlaRow(
            'Rút tiền doanh thu ví Creator:',
            '24 – 48 giờ làm việc',
            AppColors.secondaryLight,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSlaRow(String label, String value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _copyEmail(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: supportEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép email: $supportEmail'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
