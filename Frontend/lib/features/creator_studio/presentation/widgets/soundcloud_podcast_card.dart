import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/theme/app_typography.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/soundcloud_waveform.dart';
import 'package:podcast_history/core/widgets/status_chip.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/creator_podcast_player_sheet.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/track_comments_sheet.dart';

class SoundCloudPodcastCard extends StatefulWidget {
  final CreatorPodcast podcast;
  final String creatorName;
  final VoidCallback? onPlayToggle;
  final VoidCallback? onCardTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isPlaying;

  const SoundCloudPodcastCard({
    super.key,
    required this.podcast,
    required this.creatorName,
    this.onPlayToggle,
    this.onCardTap,
    this.onEdit,
    this.onDelete,
    this.isPlaying = false,
  });

  @override
  State<SoundCloudPodcastCard> createState() => _SoundCloudPodcastCardState();
}

class _SoundCloudPodcastCardState extends State<SoundCloudPodcastCard> {
  double _playbackProgress = 0.28;
  bool _isLiked = false;
  bool _isReposted = false;

  void _openPlayer() {
    if (widget.onCardTap != null) {
      widget.onCardTap!();
      return;
    }
    CreatorPodcastPlayerSheet.show(
      context: context,
      podcast: widget.podcast,
      creatorName: widget.creatorName,
      isPlaying: widget.isPlaying,
      progress: _playbackProgress,
      onPlayToggle: widget.onPlayToggle,
      onEdit: widget.onEdit,
    );
  }

  void _openComments({String? highlight, double? progress}) {
    TrackCommentsSheet.show(
      context: context,
      podcast: widget.podcast,
      currentProgress: progress ?? _playbackProgress,
      onSeek: (newProgress) {
        setState(() => _playbackProgress = newProgress);
      },
      highlightComment: highlight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pod = widget.podcast;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: widget.isPlaying
              ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
              : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
          width: widget.isPlaying ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ảnh bìa Track vuông phong cách SoundCloud với nút Play đè lên
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: AppSpacing.roundedSm,
                      child: pod.coverUrl.isEmpty
                          ? Container(
                              width: 84,
                              height: 84,
                              color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                              child: const Icon(Icons.mic, size: 36, color: AppColors.onSurfaceMutedLight),
                            )
                          : pod.coverUrl.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(pod.coverUrl.split(',').last),
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 84,
                                    height: 84,
                                    color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                                    child: const Icon(Icons.mic, size: 36, color: AppColors.onSurfaceMutedLight),
                                  ),
                                )
                              : Image.network(
                                  pod.coverUrl,
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 84,
                                    height: 84,
                                    color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                                    child: const Icon(Icons.mic, size: 36, color: AppColors.onSurfaceMutedLight),
                                  ),
                                ),
                    ),
                    Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          widget.onPlayToggle?.call();
                          _openPlayer();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isPlaying
                                ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                                : Colors.black.withValues(alpha: 0.5),
                          ),
                          child: Icon(
                            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),

                // Thông tin Artist & Tiêu đề Track
                Expanded(
                  child: InkWell(
                    onTap: _openPlayer,
                    borderRadius: AppSpacing.roundedSm,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.creatorName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 12, color: AppColors.tertiaryLight),
                            ],
                          ),
                          Text(
                            AppFormatters.timeAgo(pod.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pod.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.isPlaying
                              ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                              : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          StatusChip(
                            label: pod.statusDisplay,
                            type: pod.statusType,
                          ),
                          if (pod.isVideo) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const StatusChip(
                              label: 'Video 🎬',
                              type: StatusType.info,
                            ),
                          ],
                          if (pod.isExclusive) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const StatusChip(
                              label: 'Độc quyền 🔒',
                              type: StatusType.locked,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

                // Menu ba chấm
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (val) {
                    if (val == 'edit') widget.onEdit?.call();
                    if (val == 'delete') widget.onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                    const PopupMenuItem(value: 'delete', child: Text('Xóa podcast', style: TextStyle(color: AppColors.error))),
                  ],
                ),
              ],
            ),
          ),

          // Waveform SoundCloud đặc trưng với các comment avatar pins
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                SoundCloudWaveform(
                  progress: _playbackProgress,
                  height: 48,
                  onSeek: (fraction) {
                    setState(() => _playbackProgress = fraction);
                  },
                  comments: [
                    TimedCommentPin(
                      fraction: 0.15,
                      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
                      authorName: 'Hoàng Long',
                      content: 'Đoạn này xúc động quá!',
                      onTap: () => _openComments(highlight: 'Đoạn này xúc động quá!', progress: 0.15),
                    ),
                    TimedCommentPin(
                      fraction: 0.45,
                      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
                      authorName: 'Mai Phương',
                      content: 'Âm thanh pháo kéo chân thực',
                      onTap: () => _openComments(highlight: 'Âm thanh pháo kéo chân thực', progress: 0.45),
                    ),
                    TimedCommentPin(
                      fraction: 0.72,
                      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=150&q=80',
                      authorName: 'Bác Ba',
                      content: 'Ký ức thời khó quên',
                      onTap: () => _openComments(highlight: 'Ký ức thời khó quên', progress: 0.72),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppFormatters.formatDuration(Duration(seconds: (pod.duration.inSeconds * _playbackProgress).toInt())),
                      style: AppTypography.tabularNumbers(
                        fontSize: 10,
                        color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                      ),
                    ),
                    Text(
                      AppFormatters.formatDuration(pod.duration),
                      style: AppTypography.tabularNumbers(
                        fontSize: 10,
                        color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Thanh tương tác xã hội kiểu SoundCloud (Like, Repost, Share, Stats)
          const SizedBox(height: AppSpacing.xs),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Thích',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: _isLiked ? AppColors.primaryLight : (isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight),
                  ),
                  onPressed: () => setState(() => _isLiked = !_isLiked),
                ),
                Text(
                  AppFormatters.formatCompactNumber(pod.likesCount + (_isLiked ? 1 : 0)),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                IconButton(
                  tooltip: 'Repost lên bảng tin',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.repeat_rounded,
                    size: 18,
                    color: _isReposted ? AppColors.success : (isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight),
                  ),
                  onPressed: () {
                    setState(() => _isReposted = !_isReposted);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_isReposted ? 'Đã repost tập lên trang cá nhân!' : 'Đã gỡ repost')),
                    );
                  },
                ),
                const SizedBox(width: AppSpacing.sm),

                InkWell(
                  onTap: () => _openComments(),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppFormatters.formatCompactNumber(pod.commentsCount),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),
                Icon(Icons.headphones_rounded, size: 14, color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight),
                const SizedBox(width: 4),
                Text(
                  AppFormatters.formatCompactNumber(pod.listensCount),
                  style: AppTypography.tabularNumbers(
                    fontSize: 11,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
