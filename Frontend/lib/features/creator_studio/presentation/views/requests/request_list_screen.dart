import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/theme/app_typography.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/empty_state_widget.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/core/widgets/status_chip.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/requests/request_detail_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/creator_notification_button.dart';

class RequestListScreen extends ConsumerStatefulWidget {
  const RequestListScreen({super.key});

  @override
  ConsumerState<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends ConsumerState<RequestListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Tất cả',
    'Mới nhận',
    'Đang làm',
    'Hoàn tất',
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
    final requestsAsync = ref.watch(creatorRequestsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn đặt Podcast (Custom Request)'),
        actions: const [
          CreatorNotificationButton(),
          SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
          unselectedLabelColor: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
          indicatorColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          onRetry: () => ref.read(creatorRequestsProvider.notifier).loadRequests(),
        ),
        data: (requests) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(requests, null, isDark),
              _buildList(requests, CustomRequestStatus.sent, isDark),
              _buildList(requests, CustomRequestStatus.inProduction, isDark),
              _buildList(requests, CustomRequestStatus.completed, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<PodcastRequest> all, CustomRequestStatus? filter, bool isDark) {
    final list = filter == null ? all : all.where((r) => r.status == filter).toList();

    if (list.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.assignment_outlined,
        title: 'Hộp thư trống',
        description: 'Chưa có đơn đặt podcast nào trong mục này.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final req = list[index];
        return _buildRequestCard(req, isDark);
      },
    );
  }

  Widget _buildRequestCard(PodcastRequest req, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RequestDetailScreen(requestId: req.id),
          ),
        );
      },
      borderRadius: AppSpacing.roundedMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: AppSpacing.roundedMd,
          border: Border.all(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: req.listenerAvatar.isNotEmpty
                          ? NetworkImage(req.listenerAvatar)
                          : null,
                      onBackgroundImageError: req.listenerAvatar.isNotEmpty ? (_, _) {} : null,
                      child: const Icon(Icons.person, size: 16),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.listenerName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          AppFormatters.timeAgo(req.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                StatusChip(
                  label: req.statusDisplay,
                  type: req.statusType,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              req.topic,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              req.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: AppColors.tertiaryLight),
                    const SizedBox(width: 4),
                    Text(
                      AppFormatters.timeAgo(req.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedLight),
                    ),
                    if (req.milestones.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.md),
                      const Icon(Icons.layers_outlined, size: 14, color: AppColors.tertiaryLight),
                      const SizedBox(width: 4),
                      Text(
                        '${req.milestones.length} mốc',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                Text(
                  AppFormatters.formatVND(req.totalBudget),
                  style: AppTypography.tabularNumbers(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
