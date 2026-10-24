import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';

class PremiumUpgradeScreen extends ConsumerWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(creatorProfileProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPremium = profile?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói VietCast Studio Premium'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          // Hero Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondaryLight,
                  const Color(0xFF8B6508),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppSpacing.roundedMd,
            ),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 56, color: Colors.white),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'VietCast Studio Premium',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Nâng tầm sáng tạo nội dung lịch sử với các đặc quyền chuyên biệt',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                if (isPremium) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: AppSpacing.roundedPill,
                    ),
                    child: const Text('ĐANG KÍCH HOẠT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const Text('Quyền lợi đặc quyền', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: AppSpacing.md),

          _buildBenefitItem(
            Icons.all_inclusive_rounded,
            'Xuất bản không giới hạn podcast',
            'Không bị giới hạn 5 podcast như gói Miễn phí. Tự do sản xuất chuỗi bài dài tập.',
            isDark,
          ),
          _buildBenefitItem(
            Icons.poll_rounded,
            'Form Builder khảo sát thính giả',
            'Tạo biểu mẫu thu thập ý kiến, bình chọn chủ đề lịch sử tiếp theo từ người nghe.',
            isDark,
          ),
          _buildBenefitItem(
            Icons.live_tv_rounded,
            'Phòng Livestream kể chuyện trực tiếp',
            'Tương tác giọng nói và bình luận realtime cùng cộng đồng người nghe lịch sử.',
            isDark,
          ),
          _buildBenefitItem(
            Icons.verified_user_rounded,
            'Huy hiệu Premium & Ưu tiên duyệt AI',
            'Tăng độ nhận diện thương hiệu kênh và tốc độ thẩm định tư liệu lịch sử nhanh gấp 3 lần.',
            isDark,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Giá gói
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(color: AppColors.secondaryLight, width: 1.5),
            ),
            child: Column(
              children: [
                const Text('Chỉ với', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMutedLight)),
                const SizedBox(height: 4),
                const Text(
                  '199.000 ₫ / tháng',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.secondaryLight),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Hủy gia hạn bất kỳ lúc nào mà không phát sinh thêm phí.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (!isPremium)
            AppButton(
              label: 'Nâng cấp lên Studio Premium',
              onPressed: () {
                ref.read(creatorProfileProvider.notifier).upgradeToPremium();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chúc mừng bạn đã nâng cấp thành công gói Studio Premium!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: AppSpacing.roundedMd,
              ),
              child: const Center(
                child: Text(
                  '✓ Kênh của bạn đã sở hữu mọi đặc quyền Studio Premium',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondaryLight.withValues(alpha: 0.15),
              borderRadius: AppSpacing.roundedSm,
            ),
            child: Icon(icon, size: 20, color: AppColors.secondaryLight),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
