import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/package_features.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/comments/studio_comments_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/premium/form_builder_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/premium/premium_upgrade_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/registration/creator_registration_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/series/series_management_screen.dart';

class CreatorMoreScreen extends ConsumerWidget {
  final VoidCallback? onTheme;
  final VoidCallback? onLogout;

  const CreatorMoreScreen({super.key, this.onTheme, this.onLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(creatorProfileProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Công cụ & Cài đặt Studio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          _buildMenuSection(
            'Tương tác & Cộng đồng',
            [
              _MenuItem(
                icon: Icons.chat_rounded,
                title: 'Quản lý Bình luận thính giả',
                subtitle: 'Ghim, ẩn và trả lời bình luận theo mốc thời gian',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StudioCommentsScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.video_collection_rounded,
                title: 'Quản lý Series & Tuyển tập',
                subtitle: 'Tạo chuỗi series và gắn các tập podcast liên quan',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SeriesManagementScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.poll_rounded,
                title: 'Biểu mẫu Khảo sát & Ý kiến',
                subtitle: 'Tạo form thu thập ý kiến người nghe',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FormBuilderScreen()),
                ),
              ),
            ],
            isDark,
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildMenuSection(
            'Nâng cấp & Bản quyền',
            [
              if (kPackagesEnabled) _MenuItem(
                icon: Icons.workspace_premium_rounded,
                iconColor: AppColors.secondaryLight,
                title: 'Gói Studio Premium',
                subtitle: profile?.isPremium == true ? 'Đang kích hoạt • Đăng không giới hạn' : 'Đăng không giới hạn, Livestream, Form khảo sát',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumUpgradeScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.badge_rounded,
                title: 'Hồ sơ Creator & Trạng thái duyệt',
                subtitle: 'Xem hồ sơ kênh và kết quả duyệt CC từ Admin',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreatorRegistrationScreen()),
                ),
              ),
            ],
            isDark,
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildMenuSection(
            'Chính sách & Hỗ trợ',
            [
              _MenuItem(
                icon: Icons.menu_book_rounded,
                title: 'Quy chuẩn kiểm duyệt tư liệu lịch sử',
                subtitle: 'Hướng dẫn trích dẫn và tiêu chuẩn xác thực nội dung',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quy chuẩn: Chỉ sử dụng các tài liệu xuất bản chính thức.')),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Trung tâm trợ giúp Creator',
                subtitle: 'Liên hệ đội ngũ hỗ trợ kỹ thuật VietCast',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email hỗ trợ: creator@vietcast.vn')),
                  );
                },
              ),
            ],
            isDark,
          ),
          if (onTheme != null || onLogout != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildMenuSection(
              'Hệ thống & Phiên đăng nhập',
              [
                if (onTheme != null)
                  _MenuItem(
                    icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    title: isDark ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối',
                    subtitle: 'Tùy chỉnh tông màu hiển thị theo chủ đề',
                    onTap: onTheme!,
                  ),
                if (onLogout != null)
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.error,
                    title: 'Đăng xuất tài khoản Creator',
                    subtitle: 'Quay lại màn hình đăng nhập',
                    onTap: onLogout!,
                  ),
              ],
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuSection(String sectionTitle, List<_MenuItem> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedMd,
            side: BorderSide(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: items.map((item) {
              final isLast = items.indexOf(item) == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: (item.iconColor ?? AppColors.tertiaryLight).withValues(alpha: 0.1),
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Icon(item.icon, size: 20, color: item.iconColor ?? AppColors.tertiaryLight),
                    ),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: item.subtitle != null
                        ? Text(item.subtitle!, style: TextStyle(fontSize: 12, color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight))
                        : null,
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: item.onTap,
                  ),
                  if (!isLast) const Divider(height: 1, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
