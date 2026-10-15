import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/api_service.dart';

class CreatorRegistrationScreen extends ConsumerStatefulWidget {
  const CreatorRegistrationScreen({super.key});

  @override
  ConsumerState<CreatorRegistrationScreen> createState() =>
      _CreatorRegistrationScreenState();
}

class _CreatorRegistrationScreenState
    extends ConsumerState<CreatorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: 'Sử Kể Đêm Khuya');
  final _bioCtrl = TextEditingController(
    text: 'Kênh podcast chuyên sâu về lịch sử Việt Nam cận và hiện đại.',
  );
  final _socialCtrl = TextEditingController(
    text: 'https://youtube.com/@sukledemkhuya',
  );
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
            handle: '',
            bio: _bioCtrl.text.trim(),
            category: '',
            socialLink: _socialCtrl.text.trim(),
            sampleVoiceName: '',
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
    } on ApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Khong the gui ho so den may chu.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(creatorProfileProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ Creator & Đăng ký')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          // Banner trạng thái xét duyệt
          if (profile != null) _buildStatusHeader(profile, isDark),
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
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Vui lòng nhập tên kênh'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Giới thiệu kênh & Định hướng nội dung',
                  controller: _bioCtrl,
                  maxLines: 3,
                  validator: (v) => (v == null || v.isEmpty)
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
    Color bg;
    IconData icon;
    String title;
    String desc;

    switch (profile.status) {
      case CreatorStatus.approved:
        bg = AppColors.successContainer;
        icon = Icons.check_circle_rounded;
        title = 'Tài khoản Creator đã được duyệt';
        desc = 'Bạn có đầy đủ quyền đăng podcast, nhận đơn đặt theo yêu cầu và rút tiền từ ví.';
        break;
      case CreatorStatus.pending:
        bg = AppColors.warningContainer;
        icon = Icons.hourglass_top_rounded;
        title = 'Hồ sơ đang chờ Admin xét duyệt';
        desc = 'Thời gian xử lý dự kiến từ 24 - 48 giờ làm việc. Chúng tôi sẽ gửi thông báo ngay khi có kết quả.';
        break;
      case CreatorStatus.rejected:
        bg = AppColors.errorContainer;
        icon = Icons.cancel_rounded;
        title = 'Hồ sơ bị từ chối';
        desc =
            profile.rejectReason ??
            'Hồ sơ thiếu nguồn xác thực hoặc mẫu giọng đọc chưa đạt chuẩn.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: AppSpacing.roundedMd),
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
                Text(desc, style: const TextStyle(fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
