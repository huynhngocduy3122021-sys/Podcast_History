import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/comments/studio_comments_screen.dart';

class TrackCommentsSheet extends ConsumerStatefulWidget {
  final CreatorPodcast podcast;
  final double currentProgress; // 0.0 -> 1.0
  final ValueChanged<double>? onSeek;
  final String? highlightComment;

  const TrackCommentsSheet({
    super.key,
    required this.podcast,
    this.currentProgress = 0.0,
    this.onSeek,
    this.highlightComment,
  });

  static Future<void> show({
    required BuildContext context,
    required CreatorPodcast podcast,
    double currentProgress = 0.0,
    ValueChanged<double>? onSeek,
    String? highlightComment,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrackCommentsSheet(
        podcast: podcast,
        currentProgress: currentProgress,
        onSeek: onSeek,
        highlightComment: highlightComment,
      ),
    );
  }

  @override
  ConsumerState<TrackCommentsSheet> createState() => _TrackCommentsSheetState();
}

class _TrackCommentsSheetState extends ConsumerState<TrackCommentsSheet> {
  final TextEditingController _textController = TextEditingController();
  bool _attachTimestamp = true;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final currentSeconds = (widget.podcast.duration.inSeconds * widget.currentProgress).toInt();
    final profile = ref.read(creatorProfileProvider).value;

    final newComment = StudioComment(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      podcastTitle: widget.podcast.title,
      authorName: profile?.name ?? 'Sử Kể Đêm Khuya',
      authorAvatar: profile?.avatarUrl ?? '',
      content: text,
      timestampSeconds: _attachTimestamp ? currentSeconds : 0,
      createdAt: DateTime.now(),
    );

    // Thêm vào state qua controller
    final currentList = ref.read(creatorCommentsProvider).value ?? [];
    ref.read(creatorCommentsProvider.notifier).state = AsyncValue.data([newComment, ...currentList]);

    _textController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_attachTimestamp
            ? 'Đã gửi bình luận tại mốc ${AppFormatters.formatDuration(Duration(seconds: currentSeconds))}!'
            : 'Đã gửi bình luận!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final commentsAsync = ref.watch(creatorCommentsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final currentSec = (widget.podcast.duration.inSeconds * widget.currentProgress).toInt();
    final currentTimestampStr = AppFormatters.formatDuration(Duration(seconds: currentSec));

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.primaryDark : AppColors.primaryLight).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    size: 18,
                    color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bình luận & Mốc thời gian',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        widget.podcast.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Mở trang Quản lý Bình luận',
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StudioCommentsScreen()),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Danh sách bình luận
          Expanded(
            child: commentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Không thể tải bình luận')),
              data: (comments) {
                // Ưu tiên bình luận có liên quan hoặc toàn bộ bình luận mẫu
                final trackComments = comments.where((c) {
                  return c.podcastTitle.contains(widget.podcast.title) ||
                      widget.podcast.title.contains(c.podcastTitle);
                }).toList();

                final displayList = trackComments.isNotEmpty ? trackComments : comments;

                if (displayList.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có bình luận nào. Hãy là người đầu tiên bình luận!',
                      style: TextStyle(color: AppColors.onSurfaceMutedLight),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: displayList.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final c = displayList[index];
                    final isHighlighted = widget.highlightComment != null &&
                        c.content.contains(widget.highlightComment!);

                    final minutes = c.timestampSeconds ~/ 60;
                    final seconds = c.timestampSeconds % 60;
                    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

                    return Container(
                      padding: isHighlighted ? const EdgeInsets.all(8) : EdgeInsets.zero,
                      decoration: isHighlighted
                          ? BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.08),
                              borderRadius: AppSpacing.roundedSm,
                              border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                            )
                          : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: c.authorAvatar.isNotEmpty ? NetworkImage(c.authorAvatar) : null,
                            child: c.authorAvatar.isEmpty ? const Icon(Icons.person, size: 18) : null,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.authorName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    if (c.timestampSeconds > 0)
                                      InkWell(
                                        onTap: () {
                                          final totalSec = widget.podcast.duration.inSeconds;
                                          if (totalSec > 0 && widget.onSeek != null) {
                                            final frac = (c.timestampSeconds / totalSec).clamp(0.0, 1.0);
                                            widget.onSeek!(frac);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Đã nhảy đến mốc $timeStr')),
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isDark ? AppColors.primaryDark : AppColors.primaryLight).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.play_arrow_rounded,
                                                size: 12,
                                                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
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
                                const SizedBox(height: 4),
                                Text(
                                  c.isHidden ? '[Bình luận đã bị ẩn]' : c.content,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: c.isHidden
                                        ? (isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight)
                                        : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                                    fontStyle: c.isHidden ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => ref.read(creatorCommentsProvider.notifier).togglePin(c.id),
                                      child: Row(
                                        children: [
                                          Icon(
                                            c.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                            size: 14,
                                            color: c.isPinned ? AppColors.secondaryLight : (isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            c.isPinned ? 'Đã ghim' : 'Ghim',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: c.isPinned ? AppColors.secondaryLight : (isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    InkWell(
                                      onTap: () => ref.read(creatorCommentsProvider.notifier).toggleHide(c.id),
                                      child: Row(
                                        children: [
                                          Icon(
                                            c.isHidden ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                                            size: 14,
                                            color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            c.isHidden ? 'Hiện lại' : 'Ẩn',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
              border: Border(
                top: BorderSide(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ActionChip(
                        avatar: Icon(
                          _attachTimestamp ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: _attachTimestamp ? (isDark ? AppColors.primaryDark : AppColors.primaryLight) : null,
                        ),
                        label: Text(
                          'Gắn mốc: $currentTimestampStr',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => setState(() => _attachTimestamp = !_attachTimestamp),
                      ),
                      const Spacer(),
                      Text(
                        'Phản hồi với tư cách Creator',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Thêm bình luận cho tập podcast này...',
                            hintStyle: const TextStyle(fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        icon: const Icon(Icons.send_rounded, size: 18),
                        onPressed: _sendComment,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
