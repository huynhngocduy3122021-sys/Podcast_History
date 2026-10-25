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
  List<StudioComment>? _podcastComments;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPodcastComments();
  }

  Future<void> _loadPodcastComments() async {
    if (widget.podcast.status != PodcastStatus.published) {
      if (mounted) {
        setState(() {
          _podcastComments = const [];
          _isLoading = false;
        });
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(creatorRepositoryProvider);
      final list = await repo.getPodcastComments(widget.podcast.id);
      if (mounted) {
        setState(() {
          _podcastComments = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _podcastComments = const [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _toggleLikeComment(StudioComment c) async {
    final wasLiked = c.likedByMe;
    final newLiked = !wasLiked;
    final newCount = newLiked
        ? c.likesCount + 1
        : (c.likesCount > 0 ? c.likesCount - 1 : 0);

    if (_podcastComments != null) {
      setState(() {
        final list = List<StudioComment>.from(_podcastComments!);
        final idx = list.indexWhere((item) => item.id == c.id);
        if (idx != -1) {
          list[idx] = c.copyWith(likedByMe: newLiked, likesCount: newCount);
          _podcastComments = list;
        }
      });
    }

    try {
      final repo = ref.read(creatorRepositoryProvider);
      final res = newLiked
          ? await repo.likeComment(c.id)
          : await repo.unlikeComment(c.id);
      final serverCount = (res['likeCount'] as num?)?.toInt() ?? newCount;
      if (mounted && _podcastComments != null) {
        setState(() {
          final list = List<StudioComment>.from(_podcastComments!);
          final idx = list.indexWhere((item) => item.id == c.id);
          if (idx != -1) {
            list[idx] = list[idx].copyWith(
              likedByMe: newLiked,
              likesCount: serverCount,
            );
            _podcastComments = list;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteComment(StudioComment c) async {
    if (_podcastComments != null) {
      setState(() {
        _podcastComments =
            _podcastComments!.where((item) => item.id != c.id).toList();
      });
    }
    await ref.read(creatorCommentsProvider.notifier).deleteComment(c.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa bình luận')),
      );
    }
  }

  Future<void> _sendComment() async {
    if (widget.podcast.status != PodcastStatus.published) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tập podcast chỉ có thể gửi bình luận sau khi đã được xuất bản.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final currentSeconds =
        (widget.podcast.duration.inSeconds * widget.currentProgress).toInt();
    final profile = ref.read(creatorProfileProvider).value;

    final newComment = StudioComment(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      podcastTitle: widget.podcast.title,
      podcastId: widget.podcast.id,
      authorName: (profile?.name.isNotEmpty == true)
          ? profile!.name
          : 'Creator',
      authorAvatar: profile?.avatarUrl ?? '',
      content: text,
      timestampSeconds: _attachTimestamp ? currentSeconds : 0,
      createdAt: DateTime.now(),
    );

    if (_podcastComments != null) {
      setState(() {
        _podcastComments = [newComment, ..._podcastComments!];
      });
    }

    _textController.clear();
    FocusScope.of(context).unfocus();

    final created = await ref.read(creatorCommentsProvider.notifier).addComment(
      newComment,
      podcastId: widget.podcast.id,
    );
    if (created != null && mounted && _podcastComments != null) {
      setState(() {
        final list = List<StudioComment>.from(_podcastComments!);
        final idx = list.indexWhere((c) => c.id == newComment.id);
        if (idx != -1) {
          list[idx] = created;
          _podcastComments = list;
        }
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _attachTimestamp
                ? 'Đã gửi bình luận tại mốc ${AppFormatters.formatDuration(Duration(seconds: currentSeconds))}!'
                : 'Đã gửi bình luận!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final commentsAsync = ref.watch(creatorCommentsProvider);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final isPublished = widget.podcast.status == PodcastStatus.published;

    final currentSec =
        (widget.podcast.duration.inSeconds * widget.currentProgress).toInt();
    final currentTimestampStr = AppFormatters.formatDuration(
      Duration(seconds: currentSec),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 150 || constraints.maxWidth < 150) {
          return const SizedBox.shrink();
        }

        final availableHeight = media.size.height;
        final targetHeight = (availableHeight * 0.75).clamp(
          250.0,
          (availableHeight - bottomInset - 30).clamp(250.0, availableHeight),
        );

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: targetHeight,
            child: Material(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
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
                    color:
                        (isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight)
                            .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.primaryDark
                        : AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bình luận & Mốc thời gian',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.podcast.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.onSurfaceMutedDark
                              : AppColors.onSurfaceMutedLight,
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
                      MaterialPageRoute(
                        builder: (_) => const StudioCommentsScreen(),
                      ),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Builder(
                    builder: (context) {
                      List<StudioComment> displayList;
                      if (_podcastComments != null) {
                        displayList = _podcastComments!;
                      } else {
                        final all = commentsAsync.value ?? [];
                        final trackComments = all.where((c) {
                          return c.podcastId == widget.podcast.id ||
                              c.podcastTitle.contains(widget.podcast.title) ||
                              widget.podcast.title.contains(c.podcastTitle);
                        }).toList();
                        displayList =
                            trackComments.isNotEmpty ? trackComments : all;
                      }

                      if (displayList.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              isPublished
                                  ? 'Chưa có bình luận nào. Hãy là người đầu tiên bình luận!'
                                  : 'Tập podcast chưa xuất bản nên chưa có bình luận từ thính giả.',
                              style: const TextStyle(
                                  color: AppColors.onSurfaceMutedLight),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: displayList.length,
                        separatorBuilder: (_, _) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final c = displayList[index];
                          final isHighlighted =
                              widget.highlightComment != null &&
                              c.content.contains(widget.highlightComment!);

                          final minutes = c.timestampSeconds ~/ 60;
                          final seconds = c.timestampSeconds % 60;
                          final timeStr =
                              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

                          return Container(
                            padding: isHighlighted
                                ? const EdgeInsets.all(8)
                                : EdgeInsets.zero,
                            decoration: isHighlighted
                                ? BoxDecoration(
                                    color: AppColors.primaryLight.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: AppSpacing.roundedSm,
                                    border: Border.all(
                                      color: AppColors.primaryLight.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  )
                                : null,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: c.authorAvatar.isNotEmpty
                                      ? NetworkImage(c.authorAvatar)
                                      : null,
                                  onBackgroundImageError:
                                      c.authorAvatar.isNotEmpty
                                          ? (_, _) {}
                                          : null,
                                  child: const Icon(Icons.person, size: 18),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            c.authorName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          if (c.timestampSeconds > 0)
                                            InkWell(
                                              onTap: () {
                                                final totalSec = widget
                                                    .podcast
                                                    .duration
                                                    .inSeconds;
                                                if (totalSec > 0 &&
                                                    widget.onSeek != null) {
                                                  final frac =
                                                      (c.timestampSeconds /
                                                              totalSec)
                                                          .clamp(0.0, 1.0);
                                                  widget.onSeek!(frac);
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Đã nhảy đến mốc $timeStr',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      (isDark
                                                              ? AppColors
                                                                  .primaryDark
                                                              : AppColors
                                                                  .primaryLight)
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.play_arrow_rounded,
                                                      size: 12,
                                                      color: isDark
                                                          ? AppColors
                                                              .primaryDark
                                                          : AppColors
                                                              .primaryLight,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      timeStr,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isDark
                                                            ? AppColors
                                                                .primaryDark
                                                            : AppColors
                                                                .primaryLight,
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
                                              color: isDark
                                                  ? AppColors
                                                      .onSurfaceMutedDark
                                                  : AppColors
                                                      .onSurfaceMutedLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        c.isHidden
                                            ? '[Bình luận đã bị ẩn]'
                                            : c.content,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.35,
                                          color: c.isHidden
                                              ? (isDark
                                                  ? AppColors
                                                      .onSurfaceMutedDark
                                                  : AppColors
                                                      .onSurfaceMutedLight)
                                              : (isDark
                                                  ? AppColors.onSurfaceDark
                                                  : AppColors.onSurfaceLight),
                                          fontStyle: c.isHidden
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () => _toggleLikeComment(c),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  c.likedByMe
                                                      ? Icons.favorite_rounded
                                                      : Icons
                                                          .favorite_border_rounded,
                                                  size: 14,
                                                  color: c.likedByMe
                                                      ? AppColors.primaryLight
                                                      : (isDark
                                                          ? AppColors
                                                              .onSurfaceMutedDark
                                                          : AppColors
                                                              .onSurfaceMutedLight),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${c.likesCount}',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: c.likedByMe
                                                        ? AppColors.primaryLight
                                                        : (isDark
                                                            ? AppColors
                                                                .onSurfaceMutedDark
                                                            : AppColors
                                                                .onSurfaceMutedLight),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          InkWell(
                                            onTap: () => ref
                                                .read(
                                                  creatorCommentsProvider
                                                      .notifier,
                                                )
                                                .togglePin(c.id),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  c.isPinned
                                                      ? Icons.push_pin_rounded
                                                      : Icons.push_pin_outlined,
                                                  size: 14,
                                                  color: c.isPinned
                                                      ? AppColors.secondaryLight
                                                      : (isDark
                                                          ? AppColors
                                                              .onSurfaceMutedDark
                                                          : AppColors
                                                              .onSurfaceMutedLight),
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  c.isPinned
                                                      ? 'Đã ghim'
                                                      : 'Ghim',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: c.isPinned
                                                        ? AppColors
                                                            .secondaryLight
                                                        : (isDark
                                                            ? AppColors
                                                                .onSurfaceMutedDark
                                                            : AppColors
                                                                .onSurfaceMutedLight),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          InkWell(
                                            onTap: () => ref
                                                .read(
                                                  creatorCommentsProvider
                                                      .notifier,
                                                )
                                                .toggleHide(c.id),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  c.isHidden
                                                      ? Icons.visibility_rounded
                                                      : Icons
                                                          .visibility_off_outlined,
                                                  size: 14,
                                                  color: isDark
                                                      ? AppColors
                                                          .onSurfaceMutedDark
                                                      : AppColors
                                                          .onSurfaceMutedLight,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  c.isHidden
                                                      ? 'Hiện lại'
                                                      : 'Ẩn',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: isDark
                                                      ? AppColors
                                                          .onSurfaceMutedDark
                                                      : AppColors
                                                          .onSurfaceMutedLight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          InkWell(
                                            onTap: () => _deleteComment(c),
                                            child: Row(
                                              children: const [
                                                Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 14,
                                                  color: AppColors.error,
                                                ),
                                                SizedBox(width: 2),
                                                Text(
                                                  'Xóa',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: AppColors.error,
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2525),
              border: Border(top: const BorderSide(color: Color(0xFF5A504B))),
            ),
            child: SafeArea(
              top: false,
              bottom: bottomInset == 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ActionChip(
                        avatar: Icon(
                          _attachTimestamp
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: _attachTimestamp
                              ? (isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primaryLight)
                              : null,
                        ),
                        label: Text(
                          'Gắn mốc: $currentTimestampStr',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => setState(
                          () => _attachTimestamp = !_attachTimestamp,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Phản hồi với tư cách Creator',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.onSurfaceMutedDark
                              : AppColors.onSurfaceMutedLight,
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
                          enabled: isPublished,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: isPublished
                                ? 'Thêm bình luận cho tập podcast này...'
                                : 'Tập podcast chưa xuất bản, không thể bình luận.',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF191717),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFF5A504B),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFF5A504B),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFFB3261E),
                              ),
                            ),
                          ),
                          onSubmitted: (_) => isPublished ? _sendComment() : null,
                        ),
                      ),
                      for (final emoji in const [
                        '\u{1F525}',
                        '\u{1F44B}',
                        '\u{1F979}',
                      ])
                        InkWell(
                          onTap: () {
                            if (!isPublished) return;
                            _textController.text =
                                '${_textController.text}$emoji';
                            _textController
                                .selection = TextSelection.fromPosition(
                              TextPosition(offset: _textController.text.length),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, size: 18),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: isPublished
                              ? const Color(0xFFB3261E)
                              : Colors.white24,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isPublished ? _sendComment : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
      },
    );
  }
}
