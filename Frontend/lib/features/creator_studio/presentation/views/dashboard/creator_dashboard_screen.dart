import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/package_features.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/theme/app_typography.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/utils/image_url_helper.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/core/widgets/metric_card.dart';
import 'package:podcast_history/core/widgets/soundcloud_waveform.dart';
import 'package:podcast_history/core/widgets/status_chip.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/creator_podcast_player_sheet.dart';

class CreatorDashboardScreen extends ConsumerStatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const CreatorDashboardScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends ConsumerState<CreatorDashboardScreen> {
  int _chartPeriodIndex = 0; // 0: 7 ngày, 1: 4 tuần, 2: 12 tháng

  @override
  Widget build(BuildContext context) {
    final periodStr = _chartPeriodIndex == 0
        ? '7d'
        : (_chartPeriodIndex == 1 ? '4w' : '12m');
    final profileAsync = ref.watch(creatorProfileProvider);
    final podcastsAsync = ref.watch(creatorPodcastsProvider);
    final requestsAsync = ref.watch(creatorRequestsProvider);
    final walletAsync = ref.watch(walletProvider);
    final dashboardAsync = ref.watch(creatorDashboardProvider(periodStr));
    final dashboardData = dashboardAsync.value;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Studio'),
        actions: [
          IconButton(
            tooltip: 'Hội viên kênh',
            icon: const Icon(Icons.stars_rounded, color: AppColors.secondaryLight),
            onPressed: () {
              widget.onNavigateTab?.call(4);
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          onRetry: () {
            ref.read(creatorProfileProvider.notifier).loadProfile();
            ref.invalidate(creatorDashboardProvider(periodStr));
          },
        ),
        data: (profile) {
          final podcasts = podcastsAsync.value ?? [];
          final requests = requestsAsync.value ?? [];
          final wallet = walletAsync.value;
          final totalListens = (dashboardData != null && dashboardData.metrics.views > 0)
              ? dashboardData.metrics.views
              : podcasts.fold<int>(0, (sum, p) => sum + p.listensCount);
          final followersCount = (dashboardData != null && dashboardData.metrics.followers > 0)
              ? dashboardData.metrics.followers
              : profile.followersCount;
          final monthlyRevenue = (dashboardData != null && dashboardData.metrics.earnings > 0)
              ? dashboardData.metrics.earnings.toInt()
              : (wallet?.available ?? 0);

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(creatorProfileProvider.notifier).loadProfile();
              await ref.read(creatorPodcastsProvider.notifier).loadPodcasts();
              await ref.read(creatorRequestsProvider.notifier).loadRequests();
              await ref.read(walletProvider.notifier).loadWallet();
              ref.invalidate(creatorDashboardProvider(periodStr));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                // Header kênh
                _buildChannelHeader(context, profile, isDark),
                const SizedBox(height: AppSpacing.lg),

                // Banner gói Free vs Premium
                if (kPackagesEnabled) ...[
                  _buildPlanLimitBanner(context, profile, isDark),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Lưới chỉ số thống kê (Metrics)
                Text(
                  'Tổng quan ($periodStr)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        title: 'Tổng lượt nghe',
                        value: AppFormatters.formatCompactNumber(totalListens),
                        icon: Icons.headphones_rounded,
                        onTap: () => widget.onNavigateTab?.call(0),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MetricCard(
                        title: 'Người theo dõi',
                        value: AppFormatters.formatCompactNumber(followersCount),
                        icon: Icons.group_rounded,
                        iconColor: AppColors.tertiaryLight,
                        onTap: () => widget.onNavigateTab?.call(0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        title: 'Doanh thu',
                        value: AppFormatters.formatVND(monthlyRevenue),
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: AppColors.success,
                        onTap: () => widget.onNavigateTab?.call(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MetricCard(
                        title: 'Chờ release',
                        value: AppFormatters.formatVND(wallet?.pending ?? 0),
                        icon: Icons.hourglass_bottom_rounded,
                        iconColor: AppColors.warning,
                        onTap: () => widget.onNavigateTab?.call(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Biểu đồ lượt nghe
                _buildGrowthChart(
                  context,
                  totalListens,
                  isDark,
                  dashboardData?.growthSeries ?? const [],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Yêu cầu podcast cần xử lý nhanh
                _buildQuickRequestsSection(context, requests, isDark),
                const SizedBox(height: AppSpacing.xl),

                // Podcast mới đăng & trạng thái
                _buildRecentPodcastsSection(context, podcasts, isDark),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelHeader(BuildContext context, CreatorProfile profile, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2631) : AppColors.surfaceLight,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF25221F), const Color(0xFF151311)]
              : [const Color(0xFFFFFFFF), const Color(0xFFFBF8F3)],
        ),
        borderRadius: AppSpacing.roundedMd,
        image: profile.bannerUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(profile.bannerUrl),
                fit: BoxFit.cover,
                onError: (e, s) {},
                colorFilter: ColorFilter.mode(
                  isDark
                      ? Colors.black.withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.92),
                  isDark ? BlendMode.darken : BlendMode.lighten,
                ),
              )
            : null,
        border: Border.all(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white : AppColors.primaryLight,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.black : AppColors.primaryLight).withValues(alpha: isDark ? 0.3 : 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundImage: profile.avatarUrl.isNotEmpty
                      ? NetworkImage(profile.avatarUrl)
                      : null,
                  onBackgroundImageError: profile.avatarUrl.isNotEmpty ? (_, _) {} : null,
                  backgroundColor: AppColors.surfaceVariantLight,
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : 'C',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.primaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.onSurfaceLight,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF1D9BF0)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.handle,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFFE2E8F0) : AppColors.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (kPackagesEnabled && profile.isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: AppSpacing.roundedPill,
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFFB45309)),
                                SizedBox(width: 4),
                                Text(
                                  'Studio Premium ★',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (kPackagesEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.surfaceVariantLight,
                              borderRadius: AppSpacing.roundedPill,
                              border: Border.all(color: isDark ? Colors.white38 : AppColors.outlineLight),
                            ),
                            child: Text(
                              'Gói Creator Free',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white : AppColors.onSurfaceMutedLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            profile.bio,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFF1F5F9) : AppColors.onSurfaceMutedLight,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: isDark ? Colors.white24 : AppColors.outlineLight.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildHeaderStat('Tracks', '${profile.currentPodcastCount}', isDark),
              const SizedBox(width: AppSpacing.xl),
              _buildHeaderStat('Followers', AppFormatters.formatCompactNumber(profile.followersCount), isDark),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: const Text('Đăng bài mới', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => widget.onNavigateTab?.call(0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.onSurfaceMutedLight,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.onSurfaceLight,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanLimitBanner(BuildContext context, CreatorProfile profile, bool isDark) {
    if (profile.isPremium) return const SizedBox.shrink();

    final remaining = profile.maxFreePodcasts - profile.currentPodcastCount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryLight.withValues(alpha: 0.15),
            AppColors.primaryLight.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.secondaryLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.secondaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded, size: 24, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã đăng ${profile.currentPodcastCount}/${profile.maxFreePodcasts} podcast',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  remaining > 0
                      ? 'Bạn còn $remaining lượt đăng podcast miễn phí.'
                      : 'Đã đạt giới hạn gói Free. Nâng cấp để đăng không giới hạn.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'Nâng cấp',
            height: 36,
            onPressed: () {
              widget.onNavigateTab?.call(4); // Sang tab Thêm / Premium
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthChart(
    BuildContext context,
    int totalListens,
    bool isDark,
    List<GrowthDataPoint> growthSeries,
  ) {
    final hasSeries = growthSeries.isNotEmpty;
    if (totalListens == 0 && !hasSeries) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: AppSpacing.roundedMd,
          border: Border.all(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 40,
                color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Chưa có dữ liệu thống kê tăng trưởng lượt nghe',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final spots = hasSeries
        ? growthSeries
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.value))
            .toList()
        : const [
            FlSpot(0, 3.2),
            FlSpot(1, 4.5),
            FlSpot(2, 4.0),
            FlSpot(3, 6.8),
            FlSpot(4, 5.9),
            FlSpot(5, 8.4),
            FlSpot(6, 9.6),
          ];

    return Container(
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
              const Text(
                'Tăng trưởng lượt nghe',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('7N', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 1, label: Text('4T', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 2, label: Text('12T', style: TextStyle(fontSize: 11))),
                ],
                selected: {_chartPeriodIndex},
                onSelectionChanged: (set) {
                  setState(() => _chartPeriodIndex = set.first);
                },
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (hasSeries && idx >= 0 && idx < growthSeries.length) {
                          final dateStr = growthSeries[idx].date;
                          final display = dateStr.contains('-') ? dateStr.split('-').last : dateStr;
                          return Text(
                            display,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                            ),
                          );
                        }
                        const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                        if (idx >= 0 && idx < days.length) {
                          return Text(
                            days[idx],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isDark ? AppColors.primaryDark : AppColors.primaryLight).withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRequestsSection(BuildContext context, List<PodcastRequest> requests, bool isDark) {
    final pendingRequests = requests.where((r) => r.status == CustomRequestStatus.sent).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Yêu cầu podcast mới từ người nghe',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => widget.onNavigateTab?.call(1), // Sang tab Đơn đặt
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        if (pendingRequests.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_rounded, color: AppColors.success),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Không có đơn yêu cầu mới cần xử lý.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
              ],
            ),
          )
        else
          ...pendingRequests.take(2).map(
            (req) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                            radius: 14,
                            backgroundImage: req.listenerAvatar.isNotEmpty
                                ? NetworkImage(req.listenerAvatar)
                                : null,
                            onBackgroundImageError: req.listenerAvatar.isNotEmpty ? (_, _) {} : null,
                            child: const Icon(Icons.person, size: 14),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            req.listenerName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        AppFormatters.formatVND(req.totalBudget),
                        style: AppTypography.tabularNumbers(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    req.topic,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    req.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: 'Xem chi tiết đơn',
                        height: 36,
                        onPressed: () => widget.onNavigateTab?.call(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentPodcastsSection(BuildContext context, List<CreatorPodcast> podcasts, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tracks vừa xuất bản',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => widget.onNavigateTab?.call(0), // Sang tab Podcast
              child: const Text('Xem tất cả tracks'),
            ),
          ],
        ),
        if (podcasts.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(
                color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.mic_none_rounded,
                    size: 36,
                    color: isDark
                        ? AppColors.onSurfaceMutedDark
                        : AppColors.onSurfaceMutedLight,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Chưa có track nào được tải lên.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.onSurfaceMutedDark
                          : AppColors.onSurfaceMutedLight,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...podcasts.take(3).map(
            (pod) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(
                  color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                ),
              ),
              child: InkWell(
                borderRadius: AppSpacing.roundedMd,
                onTap: () {
                  final profile = ref.read(creatorProfileProvider).value;
                  CreatorPodcastPlayerSheet.show(
                    context: context,
                    podcast: pod,
                    creatorName: (profile?.name.isNotEmpty == true)
                        ? profile!.name
                        : 'Creator',
                  );
                },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: AppSpacing.roundedSm,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              pod.coverUrl.isEmpty
                                  ? Container(
                                      width: 52,
                                      height: 52,
                                      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                                      child: const Icon(Icons.mic_rounded, color: AppColors.onSurfaceMutedLight, size: 24),
                                    )
                                  : pod.coverUrl.startsWith('data:image')
                                      ? Image.memory(
                                          base64Decode(pod.coverUrl.split(',').last),
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 52,
                                            height: 52,
                                            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                                            child: const Icon(Icons.mic_rounded, color: AppColors.onSurfaceMutedLight, size: 24),
                                          ),
                                        )
                                      : Image.network(
                                          resolveImageUrl(pod.coverUrl),
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 52,
                                            height: 52,
                                            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                                            child: const Icon(Icons.mic_rounded, color: AppColors.onSurfaceMutedLight, size: 24),
                                          ),
                                        ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.55),
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pod.title,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  StatusChip(
                                    label: pod.statusDisplay,
                                    type: pod.statusType,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    AppFormatters.formatDuration(pod.duration),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Mini waveform preview kiểu SoundCloud
                    const SoundCloudWaveform(
                      progress: 0.4,
                      height: 30,
                      showComments: false,
                      isInteractive: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
