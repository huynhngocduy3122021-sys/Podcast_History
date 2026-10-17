import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/core/widgets/empty_state_widget.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';

class SeriesManagementScreen extends ConsumerStatefulWidget {
  const SeriesManagementScreen({super.key});

  @override
  ConsumerState<SeriesManagementScreen> createState() =>
      _SeriesManagementScreenState();
}

class _SeriesManagementScreenState
    extends ConsumerState<SeriesManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(creatorSeriesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Series Podcast'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor:
            isDark ? AppColors.primaryDark : AppColors.primaryLight,
        foregroundColor:
            isDark ? AppColors.onPrimaryDark : AppColors.onPrimaryLight,
        icon: const Icon(Icons.playlist_add_rounded),
        label: const Text('Tạo Series mới'),
        onPressed: () => _showCreateSeriesDialog(context),
      ),
      body: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          onRetry: () =>
              ref.read(creatorSeriesProvider.notifier).loadSeries(),
        ),
        data: (seriesList) {
          if (seriesList.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(creatorSeriesProvider.notifier).loadSeries(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: EmptyStateWidget(
                      icon: Icons.video_collection_outlined,
                      title: 'Chưa có chuỗi Series nào',
                      description:
                          'Tạo chuỗi series theo chủ đề để người nghe dễ dàng theo dõi các tập liên quan.',
                      actionLabel: 'Tạo Series đầu tiên',
                      onAction: () => _showCreateSeriesDialog(context),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(creatorSeriesProvider.notifier).loadSeries(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              itemCount: seriesList.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final series = seriesList[index];
                return _buildSeriesCard(context, series, isDark);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeriesCard(
    BuildContext context,
    CreatorSeries s,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.primaryDark
                          : AppColors.primaryLight)
                      .withValues(alpha: 0.15),
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: isDark
                      ? AppColors.primaryDark
                      : AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Slug: /${s.slug}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.onSurfaceMutedDark
                            : AppColors.onSurfaceMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariantLight,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  s.status,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tertiaryLight,
                  ),
                ),
              ),
            ],
          ),
          if (s.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.description,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.onSurfaceMutedDark
                    : AppColors.onSurfaceMutedLight,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: AppColors.onSurfaceMutedLight,
              ),
              const SizedBox(width: 4),
              Text(
                'Khởi tạo: ${AppFormatters.formatDate(s.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceMutedLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateSeriesDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Tạo Series Podcast Mới',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Tiêu đề Series',
                controller: titleCtrl,
                hint: 'Ví dụ: Kháng chiến chống Mỹ cứu nước',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tiêu đề series'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Slug (Đường dẫn)',
                controller: slugCtrl,
                hint: 'Ví dụ: khang-chien-chong-my',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Mô tả tóm tắt Series',
                controller: descCtrl,
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          AppButton(
            label: 'Tạo Series',
            width: 120,
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final title = titleCtrl.text.trim();
                final slug = slugCtrl.text.trim().isNotEmpty
                    ? slugCtrl.text.trim()
                    : title.toLowerCase().replaceAll(' ', '-');

                await ref.read(creatorSeriesProvider.notifier).createSeries(
                      title: title,
                      slug: slug,
                      categoryId: '',
                      description: descCtrl.text.trim(),
                    );

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã tạo series "$title" thành công!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
