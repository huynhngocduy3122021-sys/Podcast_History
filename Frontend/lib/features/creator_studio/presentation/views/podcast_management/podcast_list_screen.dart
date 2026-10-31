import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_confirm_dialog.dart';
import 'package:podcast_history/core/widgets/empty_state_widget.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/upload/upload_podcast_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/soundcloud_podcast_card.dart';
import 'package:podcast_history/core/services/audio_player/audio_player_service.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/series/series_management_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/wallet/wallet_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/creator_notification_button.dart';

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
    'Chờ duyệt',
    'Nháp',
    'Bị từ chối',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    Future.microtask(() => ref.read(creatorPodcastsProvider.notifier).loadPodcasts());
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      ref.read(creatorPodcastsProvider.notifier).loadPodcasts();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
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
        actions: [
          // Nút Series ở góc trên bên phải
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SeriesManagementScreen()),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF3ECE4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.outlineDark : const Color(0xFFDFD4C8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_collection_rounded,
                        size: 15,
                        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Series',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Nút Ví tiền ở góc trên bên phải cạnh Series
          Consumer(
            builder: (context, ref, _) {
              final wallet = ref.watch(walletProvider).value;
              final balanceStr = wallet != null
                  ? '${(wallet.available / 1000).toStringAsFixed(0)}k đ'
                  : 'Ví tiền';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF3ECE4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.outlineDark : const Color(0xFFDFD4C8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 15,
                            color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            balanceStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const CreatorNotificationButton(),
          const SizedBox(width: AppSpacing.sm),
        ],
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
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UploadPodcastScreen()),
          );
          ref.read(creatorPodcastsProvider.notifier).loadPodcasts();
          if (res == 'draft_saved') {
            _tabController.animateTo(3);
          }
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
              _buildPodcastList(podcasts, isDark: isDark),
              _buildPodcastList(podcasts, filter: PodcastStatus.published, isDark: isDark),
              _buildPodcastList(podcasts, filter: PodcastStatus.pendingAdmin, isDark: isDark),
              _buildPodcastList(podcasts, filter: PodcastStatus.draft, includePending: false, isDark: isDark),
              _buildPodcastList(podcasts, filter: PodcastStatus.rejected, isDark: isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPodcastList(
    List<CreatorPodcast> all, {
    PodcastStatus? filter,
    bool includePending = false,
    required bool isDark,
  }) {
    final list = filter == null
        ? all
        : (filter == PodcastStatus.pendingAdmin
            ? all.where((p) => p.status == PodcastStatus.pendingAdmin || p.status == PodcastStatus.aiModerating).toList()
            : (includePending
                ? all.where((p) => p.status == PodcastStatus.draft || p.status == PodcastStatus.pendingAdmin).toList()
                : all.where((p) => p.status == filter).toList()));

    return RefreshIndicator(
      onRefresh: () => ref.read(creatorPodcastsProvider.notifier).loadPodcasts(),
      child: list.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: EmptyStateWidget(
                    title: 'Chưa có podcast nào',
                    description: 'Tải lên tập podcast đầu tiên để chia sẻ với người nghe.',
                    actionLabel: 'Tạo podcast',
                    onAction: () async {
                      final res = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UploadPodcastScreen()),
                      );
                      ref.read(creatorPodcastsProvider.notifier).loadPodcasts();
                      if (res == 'draft_saved') {
                        _tabController.animateTo(3);
                      }
                    },
                  ),
                ),
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final pod = list[index];
                return _buildPodcastItem(pod, isDark);
              },
            ),
    );
  }

  String? _submittingPodcastId;

  Future<void> _submitToAdminReview(CreatorPodcast pod) async {
    setState(() => _submittingPodcastId = pod.id);
    try {
      // 1. Kiểm tra nếu có audio bytes đang lưu trong bộ nhớ tạm thời thì tải lên trước
      final cachedBytes = ref.read(audioPlayerServiceProvider.notifier).getCachedBytes(pod.id);
      if (cachedBytes != null && cachedBytes.isNotEmpty && cachedBytes.length <= 100 * 1024 * 1024) {
        final repo = ref.read(creatorRepositoryProvider);
        final name = pod.audioFileName ?? 'audio.mp3';
        final mime = name.endsWith('.wav')
            ? 'audio/wav'
            : (name.endsWith('.m4a') || name.endsWith('.mp4') ? 'audio/mp4' : 'audio/mpeg');
        try {
          await repo.uploadPodcastVideoFile(
            podcastId: pod.id,
            fileBytes: cachedBytes,
            filename: name,
            mimeType: mime,
          );
        } catch (_) {}
      }

      await ref.read(creatorPodcastsProvider.notifier).submitPodcast(pod.id);
      await ref.read(creatorPodcastsProvider.notifier).loadPodcasts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pod.status == PodcastStatus.rejected
                  ? 'Đã gửi lại tập "${pod.title}" đến Admin để kiểm duyệt thành công!'
                  : 'Đã gửi tập "${pod.title}" đến Admin để kiểm duyệt!',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        if (_tabController.index != 0) {
          _tabController.animateTo(2);
        }
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('upload') || errStr.contains('400')) {
        if (mounted) {
          _showUploadAudioDialog(pod);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi gửi duyệt: $e'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _submittingPodcastId = null);
      }
    }
  }

  Future<void> _showUploadAudioDialog(CreatorPodcast pod) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isUploading = false;
        String? statusText;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + AppSpacing.xl,
                top: AppSpacing.lg,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primaryLight, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Text(
                          'Cần tải lên tệp âm thanh',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: isUploading ? null : () => Navigator.of(modalContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Tập podcast "${pod.title}" chưa có tệp âm thanh trên máy chủ. Bạn vui lòng chọn tệp âm thanh (.mp3, .wav, .m4a <= 100MB) để hệ thống tải lên và gửi Admin duyệt ngay.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (statusText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Row(
                        children: [
                          if (isUploading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                            )
                          else
                            const Icon(Icons.info_outline, size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              statusText!,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: isUploading ? 'Đang tải lên...' : 'Chọn tệp âm thanh & Gửi duyệt',
                      icon: isUploading
                          ? null
                          : const Icon(Icons.file_upload_outlined, size: 18),
                      isLoading: isUploading,
                      onPressed: isUploading
                          ? null
                          : () async {
                              try {
                                PlatformFile? file;
                                try {
                                  file = await FilePicker.pickFile(
                                    type: FileType.custom,
                                    allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'mp4'],
                                  );
                                } catch (_) {
                                  file = await FilePicker.pickFile(type: FileType.audio);
                                }
                                if (file == null || file.name.isEmpty) return;

                                List<int>? bytes;
                                try {
                                  bytes = await file.readAsBytes();
                                } catch (_) {}
                                if (bytes == null || bytes.isEmpty) {
                                  throw Exception('Không đọc được dữ liệu tệp.');
                                }
                                if (bytes.length > 100 * 1024 * 1024) {
                                  final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
                                  throw Exception('Tệp ($mb MB) vượt quá giới hạn tối đa 100MB của máy chủ.');
                                }

                                setModalState(() {
                                  isUploading = true;
                                  statusText = 'Đang tải lên tệp ${file!.name}...';
                                });

                                final repo = ref.read(creatorRepositoryProvider);
                                final nameLower = file.name.toLowerCase();
                                String mimeType = 'audio/mpeg';
                                if (nameLower.endsWith('.wav')) {
                                  mimeType = 'audio/wav';
                                } else if (nameLower.endsWith('.m4a') || nameLower.endsWith('.mp4')) {
                                  mimeType = 'audio/mp4';
                                } else if (nameLower.endsWith('.aac')) {
                                  mimeType = 'audio/aac';
                                }

                                final uploadSuccess = await repo.uploadPodcastVideoFile(
                                  podcastId: pod.id,
                                  fileBytes: bytes,
                                  filename: file.name,
                                  mimeType: mimeType,
                                );
                                if (!uploadSuccess) {
                                  throw Exception('Tải tệp âm thanh lên máy chủ thất bại.');
                                }

                                ref.read(audioPlayerServiceProvider.notifier).cacheBytes(pod.id, bytes);

                                setModalState(() {
                                  statusText = 'Đã tải tệp xong! Đang gửi Admin duyệt...';
                                });

                                await ref.read(creatorPodcastsProvider.notifier).submitPodcast(pod.id);
                                await ref.read(creatorPodcastsProvider.notifier).loadPodcasts();

                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã tải lên tệp và gửi tập "${pod.title}" đến Admin kiểm duyệt thành công!'),
                                      backgroundColor: AppColors.success,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              } catch (err) {
                                setModalState(() {
                                  isUploading = false;
                                  statusText = 'Lỗi: $err';
                                });
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Chỉnh sửa toàn bộ tập podcast',
                      type: AppButtonType.secondary,
                      onPressed: isUploading
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              final res = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => UploadPodcastScreen(
                                    editingPodcast: pod,
                                    isResubmit: pod.status == PodcastStatus.rejected,
                                  ),
                                ),
                              );
                              await ref.read(creatorPodcastsProvider.notifier).loadPodcasts();
                              if (res == 'resubmitted' || res == 'submitted') {
                                if (_tabController.index != 0) {
          _tabController.animateTo(2);
        }
                              }
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
  }

  Widget _buildPodcastItem(CreatorPodcast pod, bool isDark) {
    final profile = ref.watch(creatorProfileProvider).value;
    final audioState = ref.watch(audioPlayerServiceProvider);
    final isPlaying = audioState.podcastId == pod.id && audioState.isPlaying;

    return Column(
      children: [
        SoundCloudPodcastCard(
          podcast: pod,
          creatorName: (profile?.name.isNotEmpty == true)
              ? profile!.name
              : 'Creator',
          isPlaying: isPlaying,
          onPlayToggle: () {
            ref.read(audioPlayerServiceProvider.notifier).togglePlay(pod);
          },
          onEdit: () async {
            final currentTab = _tabController.index;
            final res = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UploadPodcastScreen(
                  editingPodcast: pod,
                  isResubmit: pod.status == PodcastStatus.rejected,
                ),
              ),
            );
            await ref.read(creatorPodcastsProvider.notifier).loadPodcasts();

            // Nếu đang ở Tab "Tất cả" (index 0): Luôn giữ nguyên Tab 0
            if (currentTab == 0) {
              _tabController.animateTo(0);
            } else if (res == 'published_to_draft') {
              // Podcast đã đăng chỉnh sửa -> chuyển qua mục Nháp (Tab 3)
              _tabController.animateTo(3);
            } else if (res == 'resubmitted' || res == 'submitted') {
              // Bị từ chối hoặc gửi duyệt -> chuyển sang mục Chờ duyệt (Tab 2)
              _tabController.animateTo(2);
            }
          },
          onDelete: () => _confirmDelete(pod),
          onSubmitReview: (pod.status == PodcastStatus.draft || pod.status == PodcastStatus.rejected)
              ? () => _submitToAdminReview(pod)
              : null,
        ),

        // Hiển thị nút "Chờ duyệt" khi podcast đang ở trạng thái Nháp (DRAFT)
        if (pod.status == PodcastStatus.draft) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9F7F5),
              borderRadius: AppSpacing.roundedSm,
              border: Border.all(
                color: isDark ? AppColors.outlineDark : const Color(0xFFE4DCD3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_document, size: 18, color: AppColors.primaryLight),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bản nháp (Chưa gửi duyệt)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Bấm nút bên để gửi tới Admin kiểm duyệt.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  icon: _submittingPodcastId == pod.id
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 14),
                  label: const Text(
                    'Chờ duyệt',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _submittingPodcastId != null ? null : () => _submitToAdminReview(pod),
                ),
              ],
            ),
          ),
        ],

        // Hiển thị trạng thái Chờ duyệt
        if (pod.status == PodcastStatus.pendingAdmin) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : AppColors.warningContainer,
              borderRadius: AppSpacing.roundedSm,
              border: Border.all(
                color: isDark ? AppColors.outlineDark : const Color(0xFFFFE082),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Đang chờ duyệt nội dung trước khi xuất bản.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFFFCA28) : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
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
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Sửa & Gửi lại',
                        height: 32,
                        type: AppButtonType.destructive,
                        onPressed: () async {
                          final res = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UploadPodcastScreen(
                                editingPodcast: pod,
                                isResubmit: true,
                              ),
                            ),
                          );
                          await ref.read(creatorPodcastsProvider.notifier).loadPodcasts();
                          if (res == 'resubmitted' || res == 'submitted') {
                            if (_tabController.index != 0) {
          _tabController.animateTo(2);
        }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Khiếu nại',
                        height: 32,
                        type: AppButtonType.secondary,
                        onPressed: () => _showAppealDialog(pod),
                      ),
                    ),
                  ],
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
        try {
          await ref.read(creatorPodcastsProvider.notifier).deletePodcast(pod.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã xóa tập "${pod.title}" thành công'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi khi xóa: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
    );
  }

  void _showAppealDialog(CreatorPodcast pod) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Gửi khiếu nại kiểm duyệt',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tập: "${pod.title}"',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Nếu bạn cho rằng nội dung bị từ chối nhầm lẫn, hãy cung cấp thêm bằng chứng lịch sử hoặc giải trình chi tiết cho Admin:',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceMutedLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Nhập nội dung giải trình khiếu nại...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          AppButton(
            label: 'Gửi khiếu nại',
            width: 130,
            onPressed: () async {
              final note = noteCtrl.text.trim();
              if (note.isNotEmpty) {
                final repo = ref.read(creatorRepositoryProvider);
                await repo.submitPodcastAppeal(podcastId: pod.id, note: note);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Đã gửi khiếu nại đến ban quản trị VietCast.'),
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
