import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:podcast_history/core/widgets/top_notification.dart';
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
    final audioState = ref.read(audioPlayerServiceProvider);
    if (audioState.podcastId == widget.podcast.id && audioState.position.inSeconds > 0) {
      ref.read(creatorRepositoryProvider).recordListeningProgress(
        podcastId: widget.podcast.id,
        progressSeconds: audioState.position.inSeconds,
        completed: audioState.progress >= 0.99,
      );
    }
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

    ScaffoldMessenger.of(context).showTopSnackBar(
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

                          ScaffoldMessenger.of(context).showTopSnackBar(
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
                        ScaffoldMessenger.of(context).showTopSnackBar(
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
                      ScaffoldMessenger.of(context).showTopSnackBar(
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

              // Danh sách bình luận theo mốc thời gian & Nút Bình chọn / Quản lý Studio
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Bình luận theo thời gian',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF8A42),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                        label: const Text('Bình chọn', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showPodcastPollsSheet(context),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF8A42),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
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

  // --- QUẢN LÝ BÌNH CHỌN CHO PODCAST (API /api/creator/polls) ---
  void _showPodcastPollsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8A42).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.poll_rounded, color: Color(0xFFFF8A42), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bình chọn cho Podcast',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.podcast.title,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8A42),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Tạo mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              _showCreatePollDialog(
                                context,
                                onCreated: () => setSheetState(() {}),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),

                      // Danh sách polls lấy từ API
                      Expanded(
                        child: FutureBuilder<List<CreatorPoll>>(
                          future: ref.read(creatorRepositoryProvider).getPolls(podcastId: widget.podcast.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(color: Color(0xFFFF8A42)),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Không thể tải danh sách bình chọn: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () => setSheetState(() {}),
                                      child: const Text('Thử lại', style: TextStyle(color: Color(0xFFFF8A42))),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final polls = snapshot.data ?? [];
                            if (polls.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.how_to_vote_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Chưa có cuộc bình chọn nào',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 6),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        'Tạo câu hỏi và các lựa chọn để người nghe tương tác và tham gia bình chọn trong lúc nghe podcast!',
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFFF8A42),
                                        side: const BorderSide(color: Color(0xFFFF8A42)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: const Text('Tạo bình chọn đầu tiên'),
                                      onPressed: () {
                                        _showCreatePollDialog(
                                          context,
                                          onCreated: () => setSheetState(() {}),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              controller: scrollController,
                              itemCount: polls.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final poll = polls[index];
                                return _buildPollItemCard(context, poll, () => setSheetState(() {}));
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPollItemCard(BuildContext context, CreatorPoll poll, VoidCallback onRefresh) {
    Color statusColor;
    String statusText;
    switch (poll.status.toUpperCase()) {
      case 'OPEN':
        statusColor = AppColors.success;
        statusText = 'Đang mở';
        break;
      case 'DRAFT':
        statusColor = AppColors.warning;
        statusText = 'Bản nháp';
        break;
      case 'CLOSED':
        statusColor = Colors.white54;
        statusText = 'Đã đóng';
        break;
      default:
        statusColor = Colors.white70;
        statusText = poll.status;
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (poll.createdAt != null)
                Text(
                  dateFormat.format(poll.createdAt!.toLocal()),
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            poll.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (poll.options.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: poll.options.map((opt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_unchecked_rounded, size: 14, color: Color(0xFFFF8A42)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          opt.text,
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 4),

          // Action buttons bar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (poll.isOpen || poll.isClosed)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF8A42), visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.bar_chart_rounded, size: 15),
                  label: const Text('Kết quả', style: TextStyle(fontSize: 11.5)),
                  onPressed: () => _showPollResultsSheet(context, poll.pollId),
                ),
              if (poll.isDraft)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.success, visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.publish_rounded, size: 15),
                  label: const Text('Công bố', style: TextStyle(fontSize: 11.5)),
                  onPressed: () async {
                    try {
                      await ref.read(creatorRepositoryProvider).publishPoll(poll.pollId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showTopSnackBar(
                          const SnackBar(content: Text('Đã công bố cuộc bình chọn thành công!')),
                        );
                      }
                      onRefresh();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showTopSnackBar(
                          SnackBar(content: Text('Lỗi công bố: $e')),
                        );
                      }
                    }
                  },
                ),
              if (poll.isOpen)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white60, visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.lock_clock_rounded, size: 15),
                  label: const Text('Đóng', style: TextStyle(fontSize: 11.5)),
                  onPressed: () async {
                    try {
                      await ref.read(creatorRepositoryProvider).closePoll(poll.pollId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showTopSnackBar(
                          const SnackBar(content: Text('Đã đóng cuộc bình chọn!')),
                        );
                      }
                      onRefresh();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showTopSnackBar(
                          SnackBar(content: Text('Lỗi đóng bình chọn: $e')),
                        );
                      }
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 18),
                tooltip: 'Xóa bình chọn',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Xóa cuộc bình chọn?'),
                      content: Text('Bạn có chắc chắn muốn xóa "${poll.question}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Hủy')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ref.read(creatorRepositoryProvider).deletePoll(poll.pollId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showTopSnackBar(
                          const SnackBar(content: Text('Đã xóa cuộc bình chọn.')),
                        );
                      }
                      onRefresh();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showTopSnackBar(
                          SnackBar(content: Text('Lỗi xóa: $e')),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- DIALOG: TẠO BÌNH CHỌN MỚI (GẮN VỚI PODCAST NÀY) ---
  void _showCreatePollDialog(BuildContext context, {VoidCallback? onCreated}) {
    final questionCtrl = TextEditingController();
    final optionCtrls = [
      TextEditingController(),
      TextEditingController(),
    ];
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tạo cuộc bình chọn mới',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    Text(
                      'Tập podcast: ${widget.podcast.title}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),

                    // Câu hỏi
                    TextField(
                      controller: questionCtrl,
                      maxLines: 3,
                      cursorColor: const Color(0xFFFF8A42),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF2A2A30),
                        labelText: 'Câu hỏi bình chọn *',
                        labelStyle: const TextStyle(color: Colors.white70),
                        floatingLabelStyle: const TextStyle(color: Color(0xFFFF8A42)),
                        hintText: 'VD: Bạn đánh giá thế nào về diễn biến lịch sử tập này?',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFFF8A42), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Danh sách options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Các lựa chọn trả lời (2 – 20 lựa chọn):',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                        if (optionCtrls.length < 20)
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF8A42)),
                            icon: const Icon(Icons.add, size: 15),
                            label: const Text('Thêm lựa chọn', style: TextStyle(fontSize: 11.5)),
                            onPressed: () {
                              setDialogState(() {
                                optionCtrls.add(TextEditingController());
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    ...List.generate(optionCtrls.length, (idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: const Color(0xFFFF8A42).withValues(alpha: 0.2),
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF8A42),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: optionCtrls[idx],
                                cursorColor: const Color(0xFFFF8A42),
                                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF2A2A30),
                                  hintText: 'Lựa chọn ${idx + 1}',
                                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.white24),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFFF8A42), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            if (optionCtrls.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    optionCtrls.removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Nút lưu nháp / công bố ngay
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white30),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () => _submitCreatePoll(
                                      sheetCtx,
                                      questionCtrl,
                                      optionCtrls,
                                      publishNow: false,
                                      onSubmittingChange: (v) => setDialogState(() => isSubmitting = v),
                                      onSuccess: onCreated,
                                    ),
                            child: const Text('Lưu bản nháp'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8A42),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () => _submitCreatePoll(
                                      sheetCtx,
                                      questionCtrl,
                                      optionCtrls,
                                      publishNow: true,
                                      onSubmittingChange: (v) => setDialogState(() => isSubmitting = v),
                                      onSuccess: onCreated,
                                    ),
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Công bố ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitCreatePoll(
    BuildContext sheetCtx,
    TextEditingController questionCtrl,
    List<TextEditingController> optionCtrls, {
    required bool publishNow,
    required void Function(bool) onSubmittingChange,
    VoidCallback? onSuccess,
  }) async {
    final question = questionCtrl.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('Vui lòng nhập câu hỏi bình chọn.')),
      );
      return;
    }

    final options = optionCtrls
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(content: Text('Cần ít nhất 2 lựa chọn có nội dung.')),
      );
      return;
    }

    onSubmittingChange(true);
    try {
      final repo = ref.read(creatorRepositoryProvider);
      final created = await repo.createPoll(
        question: question,
        options: options,
        podcastId: widget.podcast.id,
      );

      if (publishNow) {
        await repo.publishPoll(created.pollId);
      }

      if (sheetCtx.mounted) {
        Navigator.pop(sheetCtx);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showTopSnackBar(
          SnackBar(
            content: Text(
              publishNow
                  ? 'Đã công bố cuộc bình chọn thành công!'
                  : 'Đã lưu bản nháp cuộc bình chọn!',
            ),
          ),
        );
      }
      onSuccess?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showTopSnackBar(
          SnackBar(content: Text('Lỗi tạo bình chọn: $e')),
        );
      }
    } finally {
      onSubmittingChange(false);
    }
  }

  // --- MODAL XEM KẾT QUẢ BÌNH CHỌN (GET /api/creator/polls/{pollId}/results) ---
  void _showPollResultsSheet(BuildContext context, String pollId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<PollResultsData>(
          future: ref.read(creatorRepositoryProvider).getPollResults(pollId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFFF8A42))),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                    const SizedBox(height: 8),
                    Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
                  ],
                ),
              );
            }

            final results = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kết quả bình chọn',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    results.question,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tổng số lượt phản hồi: ${results.totalResponses}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF8A42)),
                  ),
                  const SizedBox(height: 14),

                  ...results.options.map((opt) {
                    final percentage = opt.percentage.clamp(0.0, 100.0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  opt.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${opt.responseCount} (${percentage.toStringAsFixed(1)}%)',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100.0,
                              minHeight: 8,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A42)),
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
