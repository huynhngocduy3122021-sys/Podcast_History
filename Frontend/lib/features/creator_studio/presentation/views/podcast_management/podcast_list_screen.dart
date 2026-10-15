import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_confirm_dialog.dart';
import 'package:podcast_history/core/widgets/empty_state_widget.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/upload/upload_podcast_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/creator_podcast_player_sheet.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/soundcloud_podcast_card.dart';

class PodcastListScreen extends ConsumerStatefulWidget {
  const PodcastListScreen({super.key});

  @override
  ConsumerState<PodcastListScreen> createState() => _PodcastListScreenState();
}

class _PodcastListScreenState extends ConsumerState<PodcastListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Tất cả',
    'Đã đăng',
    'Đang duyệt AI',
    'Chờ Admin',
    'Nháp',
    'Bị từ chối',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final podcastsAsync = ref.watch(creatorPodcastsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Podcast'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
          unselectedLabelColor: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
          indicatorColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
        foregroundColor: isDark ? AppColors.onPrimaryDark : AppColors.onPrimaryLight,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Đăng podcast'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UploadPodcastScreen()),
          );
        },
      ),
      body: podcastsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          onRetry: () => ref.read(creatorPodcastsProvider.notifier).loadPodcasts(),
        ),
        data: (podcasts) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPodcastList(podcasts, null, isDark),
              _buildPodcastList(podcasts, PodcastStatus.published, isDark),
              _buildPodcastList(podcasts, PodcastStatus.aiModerating, isDark),
              _buildPodcastList(podcasts, PodcastStatus.pendingAdmin, isDark),
              _buildPodcastList(podcasts, PodcastStatus.draft, isDark),
              _buildPodcastList(podcasts, PodcastStatus.rejected, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPodcastList(List<CreatorPodcast> all, PodcastStatus? filter, bool isDark) {
    final list = filter == null ? all : all.where((p) => p.status == filter).toList();

    if (list.isEmpty) {
      return EmptyStateWidget(
        title: 'Chưa có podcast nào',
        description: 'Tải lên tập podcast đầu tiên để chia sẻ với người nghe.',
        actionLabel: 'Tạo podcast',
        onAction: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UploadPodcastScreen()),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final pod = list[index];
        return _buildPodcastItem(pod, isDark);
      },
    );
  }

  String? _activePlayingId;

  Widget _buildPodcastItem(CreatorPodcast pod, bool isDark) {
    final profile = ref.watch(creatorProfileProvider).value;
    final isPlaying = _activePlayingId == pod.id;

    return Column(
      children: [
        SoundCloudPodcastCard(
          podcast: pod,
          creatorName: profile?.name ?? 'Sử Kể Đêm Khuya',
          isPlaying: isPlaying,
          onPlayToggle: () {
            setState(() {
              _activePlayingId = isPlaying ? null : pod.id;
            });
          },
          onEdit: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UploadPodcastScreen(editingPodcast: pod),
              ),
            );
          },
          onDelete: () => _confirmDelete(pod),
        ),

        // Hiển thị thêm nếu là AI Moderating
        if (pod.status == PodcastStatus.aiModerating) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.infoContainer,
              borderRadius: AppSpacing.roundedSm,
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_rounded, size: 18, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'AI đang thẩm định tư liệu lịch sử (${((pod.aiModerationScore ?? 0.9) * 100).toInt()}% độ tin cậy)',
                    style: const TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Hiển thị lý do nếu bị từ chối
        if (pod.status == PodcastStatus.rejected && pod.rejectReason != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: AppSpacing.roundedSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Lý do từ chối kiểm duyệt:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  pod.rejectReason!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Sửa & Gửi lại',
                  height: 32,
                  type: AppButtonType.destructive,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UploadPodcastScreen(editingPodcast: pod),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _confirmDelete(CreatorPodcast pod) {
    AppConfirmDialog.show(
      context,
      title: 'Xóa podcast này?',
      content: 'Tập "${pod.title}" sẽ bị xóa vĩnh viễn khỏi kênh của bạn và không thể phục hồi.',
      confirmLabel: 'Xóa vĩnh viễn',
      isDestructive: true,
      onConfirm: () async {
        await ref.read(creatorPodcastsProvider.notifier).deletePodcast(pod.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xóa tập "${pod.title}"')),
          );
        }
      },
    );
  }
}
