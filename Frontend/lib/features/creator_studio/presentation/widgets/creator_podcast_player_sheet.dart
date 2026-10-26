import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/services/audio_player/audio_player_service.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/utils/image_url_helper.dart';
import 'package:podcast_history/core/widgets/soundcloud_waveform.dart';
import 'package:podcast_history/core/widgets/status_chip.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/comments/studio_comments_screen.dart';

class CreatorPodcastPlayerSheet extends ConsumerStatefulWidget {
  final CreatorPodcast podcast;
  final String creatorName;
  final bool initialPlaying;
  final double initialProgress;
  final VoidCallback? onPlayToggle;
  final VoidCallback? onEdit;

  const CreatorPodcastPlayerSheet({
    super.key,
    required this.podcast,
    required this.creatorName,
    this.initialPlaying = false,
    this.initialProgress = 0.0,
    this.onPlayToggle,
    this.onEdit,
  });

  static Future<void> show({
    required BuildContext context,
    required CreatorPodcast podcast,
    required String creatorName,
    bool isPlaying = false,
    double progress = 0.0,
    VoidCallback? onPlayToggle,
    VoidCallback? onEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Đóng player',
      backgroundColor: Colors.transparent,
      builder: (_) => CreatorPodcastPlayerSheet(
        podcast: podcast,
        creatorName: creatorName,
        initialPlaying: isPlaying,
        initialProgress: progress,
        onPlayToggle: onPlayToggle,
        onEdit: onEdit,
      ),
    );
  }

  @override
  ConsumerState<CreatorPodcastPlayerSheet> createState() => _CreatorPodcastPlayerSheetState();
}

class _CreatorPodcastPlayerSheetState extends ConsumerState<CreatorPodcastPlayerSheet> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(audioPlayerServiceProvider.notifier);
      final current = ref.read(audioPlayerServiceProvider);
      if (current.podcastId != widget.podcast.id) {
        if (widget.initialPlaying) {
          notifier.play(widget.podcast);
        }
      } else if (!current.isPlaying && widget.initialPlaying) {
        notifier.resume();
      }
      if (widget.podcast.status == PodcastStatus.published) {
        ref
            .read(creatorPodcastsProvider.notifier)
            .refreshPodcastStats(widget.podcast.id);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _setProgress(double val) {
    ref.read(audioPlayerServiceProvider.notifier).seekFraction(val);
  }

  void _seekBySeconds(int seconds) {
    ref.read(audioPlayerServiceProvider.notifier).seekBySeconds(seconds);
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final audioState = ref.read(audioPlayerServiceProvider);
    final isCurrent = audioState.podcastId == widget.podcast.id;
    final progress = isCurrent ? audioState.progress : widget.initialProgress;
    final duration = (isCurrent && audioState.duration > Duration.zero)
        ? audioState.duration
        : widget.podcast.duration;
    final currentSeconds = (duration.inSeconds * progress).toInt();
    final profile = ref.read(creatorProfileProvider).value;

    final newComment = StudioComment(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      podcastTitle: widget.podcast.title,
      podcastId: widget.podcast.id,
      authorName: profile?.name ?? widget.creatorName,
      authorAvatar: profile?.avatarUrl ?? '',
      content: text,
      timestampSeconds: currentSeconds,
      createdAt: DateTime.now(),
    );

    ref.read(creatorCommentsProvider.notifier).addComment(
      newComment,
      podcastId: widget.podcast.id,
    );

    _commentController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi bình luận tại mốc ${AppFormatters.formatDuration(Duration(seconds: currentSeconds))}!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final podcasts = ref.watch(creatorPodcastsProvider).value;
    final pod = podcasts?.cast<CreatorPodcast?>().firstWhere(
          (p) => p?.id == widget.podcast.id,
          orElse: () => null,
        ) ??
        widget.podcast;
    final audioState = ref.watch(audioPlayerServiceProvider);
    final isCurrent = audioState.podcastId == pod.id;
    final isPlaying = isCurrent && audioState.isPlaying;
    final progress = isCurrent ? audioState.progress : widget.initialProgress;
    final totalDuration = (isCurrent && audioState.duration > Duration.zero)
        ? audioState.duration
        : (ref.watch(audioPlayerServiceProvider.notifier).getKnownDuration(pod.id) ?? pod.duration);
    final currentPosition = isCurrent
        ? audioState.position
        : (progress > 0 ? Duration(seconds: (totalDuration.inSeconds * progress).toInt()) : Duration.zero);
    final currentTimestampStr = AppFormatters.formatDuration(currentPosition);
    final totalTimestampStr = AppFormatters.formatDuration(totalDuration);

    final commentsAsync = ref.watch(creatorCommentsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      builder: (_, scrollController) => Material(
        color: const Color(0xFF121212),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF381513),
                Color(0xFF1E1D1B),
                Color(0xFF15191E),
              ],
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Header bar: Thu nhỏ & Đang phát
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Thu nhỏ',
                    color: Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                  ),
                  const Text(
                    'Đang phát (Studio Preview)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.onEdit != null)
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onEdit?.call();
                      },
                      tooltip: 'Chỉnh sửa podcast',
                      color: Colors.white70,
                      icon: const Icon(Icons.edit_note_rounded, size: 24),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),

              // Thông tin Track: Bìa ảnh lớn + Tên + Kênh + Tag
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: pod.coverUrl.isEmpty
                            ? Container(
                                width: 68,
                                height: 68,
                                color: AppColors.surfaceVariantDark,
                                child: const Icon(Icons.mic, color: Colors.white54, size: 32),
                              )
                            : pod.coverUrl.startsWith('data:image')
                                ? Image.memory(
                                    base64Decode(pod.coverUrl.split(',').last),
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 68,
                                      height: 68,
                                      color: AppColors.surfaceVariantDark,
                                      child: const Icon(Icons.mic, color: Colors.white54, size: 32),
                                    ),
                                  )
                                : Image.network(
                                    resolveImageUrl(pod.coverUrl),
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 68,
                                      height: 68,
                                      color: AppColors.surfaceVariantDark,
                                      child: const Icon(Icons.mic, color: Colors.white54, size: 32),
                                    ),
                                  ),
                      ),
                      if (pod.isVideo)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black45,
                            ),
                            child: const Center(
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pod.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              widget.creatorName,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 8),
                            StatusChip(
                              label: pod.statusDisplay,
                              type: pod.statusType,
                            ),
                            if (pod.isVideo) ...[
                              const SizedBox(width: 6),
                              const StatusChip(
                                label: 'Video 🎬',
                                type: StatusType.info,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Hiển thị mốc thời gian kỹ thuật số lớn
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentTimestampStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('|', style: TextStyle(color: Colors.white30, fontSize: 28)),
                  ),
                  Text(
                    totalTimestampStr,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dải sóng âm thanh SoundCloud Waveform tương tác
              SoundCloudWaveform(
                progress: progress.clamp(0.0, 1.0),
                height: 56,
                playedColor: const Color(0xFFFF6B1A),
                unplayedColor: Colors.white30,
                onSeek: (frac) => _setProgress(frac),
                comments: const [],
              ),
              const SizedBox(height: 8),

              // Thanh trượt tiến độ phát
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFFF6B1A),
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: const Color(0x33FF6B1A),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  min: 0,
                  max: 1,
                  onChanged: (val) => _setProgress(val),
                ),
              ),
              const SizedBox(height: 12),

              // Các nút điều khiển phát chính (Tua 10s, Play/Pause to tròn, Tiến 10s)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _seekBySeconds(-10),
                    color: Colors.white,
                    icon: const Icon(Icons.replay_10_rounded, size: 30),
                    tooltip: 'Lùi 10 giây',
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      fixedSize: const Size(60, 60),
                    ),
                    onPressed: () async {
                      try {
                        if (widget.onPlayToggle != null) {
                          widget.onPlayToggle!();
                        } else {
                          await ref.read(audioPlayerServiceProvider.notifier).togglePlay(pod);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          final errStr = e.toString();
                          final isCors = errStr.contains('WebAudioError') ||
                              errStr.contains('CORS') ||
                              errStr.contains('MEDIA_ELEMENT_ERROR') ||
                              errStr.contains('Code: 4');
                          final hasMedia = (pod.videoUrl != null && pod.videoUrl!.isNotEmpty) ||
                              (pod.audioFileName != null && pod.audioFileName!.isNotEmpty);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isCors
                                    ? 'Trình duyệt chặn phát âm thanh do chính sách CORS của Cloudflare R2. Vui lòng cấu hình CORS cho bucket R2 hoặc thử trên ứng dụng Mobile.'
                                    : (hasMedia
                                        ? 'Không thể phát âm thanh: ${errStr.replaceAll('Exception:', '').trim()}'
                                        : 'Tập podcast "${pod.title}" chưa có tệp âm thanh trên máy chủ.'),
                              ),
                              backgroundColor: AppColors.error,
                              duration: const Duration(seconds: 6),
                            ),
                          );
                        }
                      }
                    },
                    tooltip: isPlaying ? 'Tạm dừng' : 'Phát',
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => _seekBySeconds(10),
                    color: Colors.white,
                    icon: const Icon(Icons.forward_10_rounded, size: 30),
                    tooltip: 'Tiến 10 giây',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Khung nhập bình luận tại đúng mốc thời gian đang nghe
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B1A).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentTimestampStr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF8A42),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Bình luận tại mốc này...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, size: 18, color: Color(0xFFFF6B1A)),
                      onPressed: _submitComment,
                      tooltip: 'Gửi bình luận',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Thanh thao tác Like, Comment, Share, More
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _PlayerAction(
                    icon: pod.likedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: '${pod.likesCount}',
                    active: pod.likedByMe,
                    onTap: () {
                      if (pod.status != PodcastStatus.published) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Podcast chỉ có thể thích sau khi đã phát hành.',
                            ),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        return;
                      }
                      ref
                          .read(creatorPodcastsProvider.notifier)
                          .toggleLike(pod.id);
                    },
                  ),
                  _PlayerAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '${pod.commentsCount}',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StudioCommentsScreen()),
                      );
                    },
                  ),
                  _PlayerAction(
                    icon: Icons.ios_share_rounded,
                    label: 'Chia sẻ',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã sao chép liên kết tập "${pod.title}"')),
                      );
                    },
                  ),
                  _PlayerAction(
                    icon: Icons.headphones_rounded,
                    label: '${pod.listensCount}',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),

              // Danh sách bình luận theo mốc thời gian
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bình luận theo thời gian',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF8A42)),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Quản lý Studio', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StudioCommentsScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              commentsAsync.when(
                loading: () => const Center(
                  child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white)),
                ),
                error: (_, _) => const Text('Không thể tải bình luận', style: TextStyle(color: Colors.white54)),
                data: (allComments) {
                  final displayComments = allComments.take(5).toList();
                  if (displayComments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Chưa có bình luận nào.', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return Column(
                    children: displayComments.map((c) {
                      final cMinutes = c.timestampSeconds ~/ 60;
                      final cSeconds = c.timestampSeconds % 60;
                      final cTimeStr = '${cMinutes.toString().padLeft(2, '0')}:${cSeconds.toString().padLeft(2, '0')}';

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: c.authorAvatar.isNotEmpty ? NetworkImage(c.authorAvatar) : null,
                              onBackgroundImageError: c.authorAvatar.isNotEmpty ? (_, _) {} : null,
                              backgroundColor: AppColors.primaryLight,
                              child: const Icon(Icons.person, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c.authorName,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          if (pod.duration.inSeconds > 0) {
                                            _setProgress(c.timestampSeconds / pod.duration.inSeconds);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF6B1A).withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.play_arrow_rounded, size: 12, color: Color(0xFFFF8A42)),
                                              Text(
                                                cTimeStr,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFFF8A42),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (c.isPinned) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFFFBBF24)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    c.content,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _PlayerAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFFFF6B1A) : Colors.white70,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFFFF6B1A) : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
