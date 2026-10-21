import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/core/widgets/empty_state_widget.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';

class FormBuilderScreen extends ConsumerStatefulWidget {
  const FormBuilderScreen({super.key});

  @override
  ConsumerState<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends ConsumerState<FormBuilderScreen> {
  @override
  Widget build(BuildContext context) {
    final formsAsync = ref.watch(creatorFormsProvider);
    final profile = ref.watch(creatorProfileProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPremium = profile?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biểu mẫu tương tác thính giả'),
      ),
      floatingActionButton: isPremium
          ? FloatingActionButton.extended(
              backgroundColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              foregroundColor: isDark ? AppColors.onPrimaryDark : AppColors.onPrimaryLight,
              icon: const Icon(Icons.add_chart_rounded),
              label: const Text('Tạo biểu mẫu mới'),
              onPressed: () => _showCreateFormDialog(context),
            )
          : null,
      body: !isPremium
          ? _buildLockedView(isDark)
          : formsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorStateWidget(
                onRetry: () => ref.read(creatorFormsProvider.notifier).loadForms(),
              ),
              data: (forms) {
                if (forms.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.poll_outlined,
                    title: 'Chưa có biểu mẫu nào',
                    description: 'Tạo khảo sát để lắng nghe góp ý và bình chọn chủ đề từ người nghe.',
                    actionLabel: 'Tạo biểu mẫu đầu tiên',
                    onAction: () => _showCreateFormDialog(context),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  itemCount: forms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final form = forms[index];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  form.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.successContainer,
                                  borderRadius: AppSpacing.roundedPill,
                                ),
                                child: Text(
                                  '${form.responsesCount} phản hồi',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            form.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text('Danh sách câu hỏi trong form:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: AppSpacing.xs),
                          ...form.questions.map((q) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(_getQuestionIcon(q.type), size: 14, color: AppColors.tertiaryLight),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      q.question,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  IconData _getQuestionIcon(FormQuestionType type) {
    switch (type) {
      case FormQuestionType.shortText:
        return Icons.short_text_rounded;
      case FormQuestionType.singleChoice:
        return Icons.radio_button_checked_rounded;
      case FormQuestionType.rating:
        return Icons.star_rate_rounded;
    }
  }

  Widget _buildLockedView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_person_rounded, size: 64, color: AppColors.secondaryLight),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Tính năng dành cho Studio Premium',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Biểu mẫu tương tác cho phép bạn tạo khảo sát, lấy ý kiến chủ đề lịch sử từ thính giả để xây dựng nội dung chất lượng hơn.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Mở khóa Studio Premium',
              width: 220,
              onPressed: () {
                ref.read(creatorProfileProvider.notifier).upgradeToPremium();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã mở khóa tính năng Form tương tác!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFormDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo biểu mẫu khảo sát', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: 'Tiêu đề biểu mẫu', controller: titleCtrl, hint: 'Ví dụ: Khảo sát thính giả tháng 11'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Mô tả ngắn', controller: descCtrl, maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          AppButton(
            label: 'Tạo form',
            width: 110,
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                ref.read(creatorFormsProvider.notifier).createForm(
                      titleCtrl.text.trim(),
                      descCtrl.text.trim(),
                      [
                        const FormQuestion(
                          id: 'q1',
                          question: 'Giai đoạn lịch sử bạn muốn nghe nhất?',
                          type: FormQuestionType.singleChoice,
                          options: ['1858-1945', '1945-1954', '1954-1975', '1975-1986'],
                        ),
                        const FormQuestion(
                          id: 'q2',
                          question: 'Góp ý thêm cho giọng đọc của kênh:',
                          type: FormQuestionType.shortText,
                        ),
                      ],
                    );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã tạo biểu mẫu khảo sát thành công!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
