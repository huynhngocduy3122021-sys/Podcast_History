import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';

class CreatorRegistrationScreen extends ConsumerStatefulWidget {
  const CreatorRegistrationScreen({super.key});

  @override
  ConsumerState<CreatorRegistrationScreen> createState() =>
      _CreatorRegistrationScreenState();
}

class _CreatorRegistrationScreenState
    extends ConsumerState<CreatorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _socialCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _socialCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(creatorProfileProvider.notifier)
          .submitRegistration(
            channelName: _nameCtrl.text.trim(),
            bio: _bioCtrl.text.trim(),
            socialLink: _socialCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hồ sơ đăng ký làm Creator đã được gửi! Ban quản trị sẽ xét duyệt trong 24-48h.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(creatorProfileProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ Creator & Đăng ký')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          if (profile != null && profile.status != CreatorStatus.notRegistered)
            _buildStatusHeader(profile, isDark),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông tin kênh Podcast',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Tên kênh người kể',
                  controller: _nameCtrl,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên kênh'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Giới thiệu kênh & Định hướng nội dung',
                  controller: _bioCtrl,
                  maxLines: 3,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng giới thiệu kênh'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Link mạng xã hội / Kênh tham khảo (YouTube, FB, TikTok...)',
                  controller: _socialCtrl,
                  hint: 'https://...',
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: profile?.status == CreatorStatus.rejected
                      ? 'Gửi lại hồ sơ xét duyệt'
                      : 'Cập nhật hồ sơ Creator',
                  isLoading: _isSubmitting,
                  onPressed: _submitForm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(CreatorProfile profile, bool isDark) {
    late Color background;
    late IconData icon;
    late String title;
    late String description;
    switch (profile.status) {
      case CreatorStatus.notRegistered:
        return const SizedBox.shrink();
      case CreatorStatus.approved:
        background = AppColors.successContainer;
        icon = Icons.check_circle_rounded;
        title = 'Tài khoản Creator đã được duyệt';
        description = 'Bạn có đầy đủ quyền đăng podcast, nhận đơn đặt theo yêu cầu và rút tiền từ ví.';
      case CreatorStatus.pending:
        background = AppColors.warningContainer;
        icon = Icons.hourglass_top_rounded;
        title = 'Hồ sơ đang chờ Admin xét duyệt';
        description = 'Thời gian xử lý dự kiến từ 24 - 48 giờ làm việc. Chúng tôi sẽ gửi thông báo ngay khi có kết quả.';
      case CreatorStatus.rejected:
        background = AppColors.errorContainer;
        icon = Icons.cancel_rounded;
        title = 'Hồ sơ bị từ chối';
        description =
            profile.rejectReason ??
            'Hồ sơ chưa đủ thông tin hoặc nguồn xác thực để xét duyệt.';
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppSpacing.roundedMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: isDark ? AppColors.onSurfaceDark : Colors.black87,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
