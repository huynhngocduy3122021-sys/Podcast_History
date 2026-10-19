import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/empty_state_widget.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';

class StudioCommentsScreen extends ConsumerWidget {
  const StudioCommentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(creatorCommentsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Bình luận'),
      ),
      body: commentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          onRetry: () => ref.read(creatorCommentsProvider.notifier).loadComments(),
        ),
        data: (comments) {
          if (comments.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chưa có bình luận nào',
              description: 'Khi thính giả thảo luận về các tập podcast, bình luận sẽ xuất hiện ở đây.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            itemCount: comments.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final c = comments[index];
              return _buildCommentCard(context, ref, c, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildCommentCard(BuildContext context, WidgetRef ref, StudioComment c, bool isDark) {
    final minutes = c.timestampSeconds ~/ 60;
    final seconds = c.timestampSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: c.isPinned
              ? AppColors.secondaryLight
              : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
          width: c.isPinned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner ghim
          if (c.isPinned) ...[
            const Row(
              children: [
                Icon(Icons.push_pin_rounded, size: 14, color: AppColors.secondaryLight),
                SizedBox(width: 4),
                Text(
                  'Đã ghim bởi tác giả',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondaryLight),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],

          // Tập podcast liên quan
          Row(
            children: [
              const Icon(Icons.mic_none_rounded, size: 14, color: AppColors.tertiaryLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  c.podcastTitle,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.tertiaryLight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariantLight,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  'Mốc $timeStr',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.tertiaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Tác giả bình luận
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: c.authorAvatar.isNotEmpty
                    ? NetworkImage(c.authorAvatar)
                    : null,
                onBackgroundImageError: c.authorAvatar.isNotEmpty ? (_, _) {} : null,
                child: const Icon(Icons.person, size: 14),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                c.authorName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              Text(
                AppFormatters.timeAgo(c.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Nội dung
          Text(
            c.isHidden ? '[Bình luận này đã bị ẩn bởi tác giả]' : c.content,
            style: TextStyle(
              fontSize: 13,
              fontStyle: c.isHidden ? FontStyle.italic : FontStyle.normal,
              color: c.isHidden ? AppColors.onSurfaceMutedLight : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: Icon(
                  c.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  size: 16,
                  color: AppColors.secondaryLight,
                ),
                label: Text(c.isPinned ? 'Bỏ ghim' : 'Ghim'),
                onPressed: () => ref.read(creatorCommentsProvider.notifier).togglePin(c.id),
              ),
              TextButton.icon(
                icon: Icon(
                  c.isHidden ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                  size: 16,
                  color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                ),
                label: Text(c.isHidden ? 'Hiện' : 'Ẩn'),
                onPressed: () => ref.read(creatorCommentsProvider.notifier).toggleHide(c.id),
              ),
              TextButton.icon(
                icon: const Icon(Icons.reply_rounded, size: 16, color: AppColors.primaryLight),
                label: const Text('Trả lời'),
                onPressed: () => _showReplyDialog(context, c),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                label: const Text('Xóa', style: TextStyle(color: AppColors.error)),
                onPressed: () async {
                  await ref.read(creatorCommentsProvider.notifier).deleteComment(c.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã xóa bình luận!')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(BuildContext context, StudioComment c) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Trả lời ${c.authorName}', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nội dung: "${c.content}"', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedLight)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: replyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Nhập câu trả lời từ tác giả kênh...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          AppButton(
            label: 'Gửi trả lời',
            width: 120,
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã gửi phản hồi thành công!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
