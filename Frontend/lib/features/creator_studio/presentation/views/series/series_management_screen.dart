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
    return InkWell(
      onTap: () => _showSeriesPodcastsSheet(context, s),
      borderRadius: AppSpacing.roundedMd,
      child: Container(
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
                  color: s.status == 'ARCHIVED'
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.surfaceVariantLight,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  s.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: s.status == 'ARCHIVED'
                        ? AppColors.error
                        : AppColors.tertiaryLight,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (action) {
                  if (action == 'view') {
                    _showSeriesPodcastsSheet(context, s);
                  } else if (action == 'edit') {
                    _showEditSeriesDialog(context, s);
                  } else if (action == 'archive') {
                    _confirmDeleteSeries(context, s);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_play_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Xem danh sách tập'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Chỉnh sửa Series'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Lưu trữ Series', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
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
    ),
  );
}

  void _showCreateSeriesDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedCategoryId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Tạo Series Podcast Mới',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Tiêu đề Series *',
                    controller: titleCtrl,
                    hint: 'Ví dụ: Kháng chiến chống Mỹ cứu nước',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tiêu đề series'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Consumer(
                    builder: (context, ref, _) {
                      final categoriesAsync = ref.watch(categoriesProvider);
                      return categoriesAsync.when(
                        data: (categories) {
                          if (categories.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          selectedCategoryId ??= categories.first.id;
                          return DropdownButtonFormField<String>(
                            initialValue: selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'Danh mục chủ đề *',
                              isDense: true,
                              prefixIcon:
                                  Icon(Icons.category_outlined, size: 20),
                            ),
                            items: categories
                                .map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setDialogState(() => selectedCategoryId = val);
                            },
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Vui lòng chọn danh mục'
                                : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, st) => const SizedBox.shrink(),
                      );
                    },
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
                        categoryId: selectedCategoryId ?? '',
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
      ),
    );
  }

  void _showEditSeriesDialog(BuildContext context, CreatorSeries series) {
    final titleCtrl = TextEditingController(text: series.title);
    final slugCtrl = TextEditingController(text: series.slug);
    final descCtrl = TextEditingController(text: series.description);
    final formKey = GlobalKey<FormState>();
    String? selectedCategoryId = series.categoryId.isNotEmpty ? series.categoryId : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Chỉnh sửa Series Podcast',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Tiêu đề Series *',
                    controller: titleCtrl,
                    hint: 'Ví dụ: Kháng chiến chống Mỹ cứu nước',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tiêu đề series'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Consumer(
                    builder: (context, ref, _) {
                      final categoriesAsync = ref.watch(categoriesProvider);
                      return categoriesAsync.when(
                        data: (categories) {
                          if (categories.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          selectedCategoryId ??= categories.first.id;
                          return DropdownButtonFormField<String>(
                            initialValue: selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'Danh mục chủ đề *',
                              isDense: true,
                              prefixIcon:
                                  Icon(Icons.category_outlined, size: 20),
                            ),
                            items: categories
                                .map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setDialogState(() => selectedCategoryId = val);
                            },
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Vui lòng chọn danh mục'
                                : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (err, st) => const SizedBox.shrink(),
                      );
                    },
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            AppButton(
              label: 'Lưu thay đổi',
              width: 130,
              onPressed: () async {
                if (formKey.currentState?.validate() == true) {
                  final title = titleCtrl.text.trim();
                  final slug = slugCtrl.text.trim().isNotEmpty
                      ? slugCtrl.text.trim()
                      : title.toLowerCase().replaceAll(' ', '-');

                  final updated = await ref
                      .read(creatorSeriesProvider.notifier)
                      .updateSeries(
                        seriesId: series.id,
                        title: title,
                        slug: slug,
                        categoryId: selectedCategoryId ?? '',
                        description: descCtrl.text.trim(),
                        coverUrl: series.coverUrl,
                      );

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          updated != null
                              ? 'Đã cập nhật series "$title" thành công!'
                              : 'Không thể cập nhật series. Vui lòng thử lại.',
                        ),
                        backgroundColor: updated != null
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSeries(BuildContext context, CreatorSeries series) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Lưu trữ Series',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Bạn có chắc chắn muốn lưu trữ series "${series.title}" không?\n\n'
          'Các tập podcast thuộc series này sẽ không bị xóa mà trở thành tập đơn lẻ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          AppButton(
            label: 'Lưu trữ Series',
            type: AppButtonType.destructive,
            width: 140,
            onPressed: () async {
              final ok = await ref
                  .read(creatorSeriesProvider.notifier)
                  .deleteSeries(series.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Đã lưu trữ series "${series.title}" thành công!'
                          : 'Lỗi lưu trữ series. Vui lòng thử lại.',
                    ),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSeriesPodcastsSheet(BuildContext context, CreatorSeries series) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.video_collection_rounded,
                      color: AppColors.primaryLight),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      series.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              if (series.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  series.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.onSurfaceMutedDark
                        : AppColors.onSurfaceMutedLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Các tập podcast trong Series',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: FutureBuilder<List<CreatorPodcast>>(
                  future: ref
                      .read(creatorSeriesProvider.notifier)
                      .getSeriesPodcasts(series.id),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final podcasts = snapshot.data ?? [];
                    if (podcasts.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có tập podcast nào được gắn vào series này.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollCtrl,
                      itemCount: podcasts.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final pod = podcasts[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            pod.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Thời lượng: ${AppFormatters.formatDuration(pod.duration)} • ${pod.status.name}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
