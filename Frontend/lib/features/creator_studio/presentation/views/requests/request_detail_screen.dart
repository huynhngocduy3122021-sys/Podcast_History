import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/theme/app_typography.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/core/widgets/status_chip.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;

  const RequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(creatorRequestsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final requests = requestsAsync.value ?? [];
    final req = requests.where((r) => r.id == widget.requestId).firstOrNull;

    if (req == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết đơn yêu cầu')),
        body: requestsAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const Center(child: Text('Không tìm thấy thông tin đơn đặt podcast.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn yêu cầu'),
        actions: [
          IconButton(
            tooltip: 'Khiếu nại / Báo cáo',
            icon: const Icon(Icons.report_problem_outlined, color: AppColors.error),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yêu cầu trợ giúp đã được gửi đến Admin VietCast.')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                // Thẻ thông tin trạng thái & Next step
                _buildStatusBanner(req, isDark),
                const SizedBox(height: AppSpacing.lg),

                // Stepper quy trình
                _buildWorkflowStepper(req, isDark),
                const SizedBox(height: AppSpacing.lg),

                // Thông tin đơn hàng
                _buildOrderOverview(req, isDark),
                const SizedBox(height: AppSpacing.lg),

                // Các mốc thanh toán Escrow (Dữ liệu thực từ Backend)
                _buildMilestonesSection(req, isDark),
                const SizedBox(height: AppSpacing.lg),

                // Sản phẩm đã nộp (nếu có từ Backend)
                if (req.deliveryFileUrl != null || req.deliveryNote != null) ...[
                  _buildDeliverySection(req, isDark),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),

          // Bottom Action Bar theo State Machine
          _buildBottomActionButtons(req, isDark),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(PodcastRequest req, bool isDark) {
    String nextAction;
    switch (req.status) {
      case CustomRequestStatus.sent:
        nextAction = 'Bước tiếp theo: Hãy kiểm tra yêu cầu và quyết định Nhận hoặc Từ chối.';
        break;
      case CustomRequestStatus.accepted:
      case CustomRequestStatus.inProduction:
        nextAction = 'Bước tiếp theo: Thực hiện nội dung và nộp bản thu âm cho mốc thanh toán.';
        break;
      case CustomRequestStatus.delivered:
        nextAction = 'Bước tiếp theo: Đang chờ người nghe thẩm định và giải ngân mốc thanh toán.';
        break;
      case CustomRequestStatus.revisionRequested:
        nextAction = 'Bước tiếp theo: Người nghe yêu cầu chỉnh sửa. Vui lòng xem ghi chú và cập nhật.';
        break;
      case CustomRequestStatus.completed:
        nextAction = 'Đơn đặt đã hoàn thành xuất sắc! Toàn bộ thù lao đã được thanh toán vào ví.';
        break;
      case CustomRequestStatus.rejected:
        nextAction = 'Đơn đã bị từ chối.';
        break;
      case CustomRequestStatus.disputed:
        nextAction = 'Đơn đang trong diện khiếu nại. Admin đang tiến hành đối soát.';
        break;
      default:
        nextAction = '';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: req.statusType == StatusType.success
            ? AppColors.successContainer
            : (req.statusType == StatusType.warning ? AppColors.warningContainer : AppColors.surfaceVariantLight),
        borderRadius: AppSpacing.roundedMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRẠNG THÁI HIỆN TẠI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                ),
              ),
              StatusChip(
                label: req.statusDisplay,
                type: req.statusType,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            nextAction,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStepper(PodcastRequest req, bool isDark) {
    final steps = ['Gửi đơn', 'Tiếp nhận', 'Sản xuất', 'Nộp bài', 'Nghiệm thu'];
    int activeIndex = 0;
    if (req.status == CustomRequestStatus.sent) activeIndex = 0;
    if (req.status == CustomRequestStatus.accepted) activeIndex = 1;
    if (req.status == CustomRequestStatus.inProduction) activeIndex = 2;
    if (req.status == CustomRequestStatus.delivered || req.milestones.any((m) => m.isSubmitted)) activeIndex = 3;
    if (req.status == CustomRequestStatus.completed ||
        req.status == CustomRequestStatus.approved ||
        (req.milestones.isNotEmpty && req.milestones.every((m) => m.isApproved))) {
      activeIndex = 4;
    }

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
          const Text('Tiến trình thực hiện', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isPassed = index <= activeIndex;
              final isCurrent = index == activeIndex;
              return Column(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isPassed
                        ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                        : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
                    child: isPassed && !isCurrent
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? (isDark ? AppColors.primaryDark : AppColors.primaryLight) : null,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderOverview(PodcastRequest req, bool isDark) {
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
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: req.listenerAvatar.isNotEmpty
                    ? NetworkImage(req.listenerAvatar)
                    : null,
                onBackgroundImageError: req.listenerAvatar.isNotEmpty ? (_, _) {} : null,
                child: const Icon(Icons.person, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.listenerName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      'Người nghe đặt podcast • Tạm giữ Escrow',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            req.topic,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (req.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              req.description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaItem('Thời gian tạo', AppFormatters.formatDate(req.createdAt), Icons.calendar_today_outlined),
              _buildMetaItem('Trạng thái', req.statusDisplay, Icons.info_outline),
              _buildMetaItem('Tổng ngân sách', AppFormatters.formatVND(req.totalBudget), Icons.payments_outlined, isHighlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.tertiaryLight),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceMutedLight)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isHighlight ? AppColors.success : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestonesSection(PodcastRequest req, bool isDark) {
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
                'Các mốc giải ngân (Escrow Milestones)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              if (req.milestones.isNotEmpty)
                Text(
                  '${req.milestones.length} mốc',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (req.milestones.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                req.status == CustomRequestStatus.sent
                    ? 'Chưa thiết lập mốc giải ngân. Khi bạn chấp thuận đơn hàng, mốc giải ngân sẽ được khởi tạo.'
                    : 'Chưa có mốc giải ngân nào.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                ),
              ),
            )
          else
            ...req.milestones.map((m) {
              Color statusColor;
              IconData statusIcon;
              String statusText;

              switch (m.status) {
                case 'APPROVED':
                  statusColor = AppColors.success;
                  statusIcon = Icons.check_circle_rounded;
                  statusText = 'Đã giải ngân';
                  break;
                case 'SUBMITTED':
                  statusColor = AppColors.warning;
                  statusIcon = Icons.hourglass_top_rounded;
                  statusText = 'Chờ duyệt';
                  break;
                case 'REVISION_REQUESTED':
                  statusColor = AppColors.error;
                  statusIcon = Icons.published_with_changes_rounded;
                  statusText = 'Cần sửa đổi';
                  break;
                case 'DISPUTED':
                  statusColor = AppColors.error;
                  statusIcon = Icons.gavel_rounded;
                  statusText = 'Khiếu nại';
                  break;
                default:
                  statusColor = AppColors.tertiaryLight;
                  statusIcon = Icons.pending_actions_rounded;
                  statusText = 'Chưa nộp';
              }

              final canSubmitThis = (req.status == CustomRequestStatus.accepted ||
                      req.status == CustomRequestStatus.inProduction ||
                      req.status == CustomRequestStatus.revisionRequested) &&
                  (m.status == 'NOT_STARTED' || m.status == 'REVISION_REQUESTED');

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                  borderRadius: AppSpacing.roundedSm,
                  border: Border.all(
                    color: m.isApproved
                        ? AppColors.success.withValues(alpha: 0.3)
                        : (m.isSubmitted
                            ? AppColors.warning.withValues(alpha: 0.3)
                            : (isDark ? AppColors.outlineDark : AppColors.outlineLight)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, size: 18, color: statusColor),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mốc ${m.order}: ${m.title}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              if (m.description != null && m.description!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  m.description!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.formatVND(m.amount),
                              style: AppTypography.tabularNumbers(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: m.isApproved ? AppColors.success : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (canSubmitThis) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.upload_file_rounded, size: 14),
                          label: Text(
                            m.status == 'REVISION_REQUESTED' ? 'Nộp lại bài' : 'Nộp bài cho mốc này',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _handleDeliver(req, milestoneId: m.id),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDeliverySection(PodcastRequest req, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.info, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.info),
              SizedBox(width: AppSpacing.xs),
              Text('Bản podcast đã nộp cho người nghe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.info)),
            ],
          ),
          if (req.deliveryNote != null && req.deliveryNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Ghi chú: ${req.deliveryNote}', style: const TextStyle(fontSize: 13)),
          ],
          if (req.deliveryFileUrl != null && req.deliveryFileUrl!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.audio_file_outlined, size: 16, color: AppColors.tertiaryLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    req.deliveryFileUrl!,
                    style: const TextStyle(fontSize: 12, color: AppColors.tertiaryLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons(PodcastRequest req, bool isDark) {
    if (req.status == CustomRequestStatus.completed ||
        (req.milestones.isNotEmpty && req.milestones.every((m) => m.isApproved))) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: AppColors.successContainer,
        child: const Center(
          child: Text(
            '✓ Đơn hàng đã hoàn thành và tất toán toàn bộ.',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success),
          ),
        ),
      );
    }

    if (req.status == CustomRequestStatus.rejected) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: AppColors.surfaceVariantLight,
        child: const Center(
          child: Text(
            'Đơn yêu cầu này đã bị từ chối.',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.onSurfaceMutedLight),
          ),
        ),
      );
    }

    if (req.status == CustomRequestStatus.sent) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(top: BorderSide(color: isDark ? AppColors.outlineDark : AppColors.outlineLight)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Từ chối đơn',
                type: AppButtonType.secondary,
                onPressed: () => _handleReject(req),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Chấp nhận đơn',
                onPressed: () => _handleAccept(req),
              ),
            ),
          ],
        ),
      );
    }

    if (req.status == CustomRequestStatus.accepted ||
        req.status == CustomRequestStatus.inProduction ||
        req.status == CustomRequestStatus.revisionRequested) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(top: BorderSide(color: isDark ? AppColors.outlineDark : AppColors.outlineLight)),
        ),
        child: AppButton(
          label: 'Nộp bài / Gửi bản audio hoàn chỉnh',
          onPressed: () => _handleDeliver(req),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _handleAccept(PodcastRequest req) {
    final noteController = TextEditingController(text: 'Creator đồng ý nhận thực hiện đơn đặt podcast.');
    final messenger = ScaffoldMessenger.of(context);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Chấp nhận đơn đặt podcast', style: TextStyle(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bạn đang nhận sản xuất podcast theo yêu cầu của thính giả.'),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.successContainer.withValues(alpha: 0.5),
                      borderRadius: AppSpacing.roundedSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chủ đề: ${req.topic}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          'Ngân sách: ${AppFormatters.formatVND(req.totalBudget)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Lời nhắn gửi người nghe',
                    hint: 'Nhập ghi chú phản hồi...',
                    controller: noteController,
                    maxLines: 2,
                    readOnly: isSubmitting,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Hủy'),
              ),
              AppButton(
                label: isSubmitting ? 'Đang xử lý...' : 'Xác nhận nhận đơn',
                width: 150,
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ref.read(creatorRequestsProvider.notifier).acceptRequest(
                                req.id,
                                responseText: noteController.text.trim(),
                              );
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Đã nhận đơn thành công! Bạn có thể bắt đầu sản xuất.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Lỗi nhận đơn: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleReject(PodcastRequest req) {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Từ chối đơn yêu cầu', style: TextStyle(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vui lòng cung cấp lý do từ chối để người nghe được biết.'),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Lý do từ chối',
                    hint: 'Ví dụ: Tác giả bận lịch sản xuất...',
                    controller: reasonController,
                    maxLines: 3,
                    readOnly: isSubmitting,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Hủy'),
              ),
              AppButton(
                label: isSubmitting ? 'Đang gửi...' : 'Từ chối',
                type: AppButtonType.secondary,
                width: 120,
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reason = reasonController.text.trim();
                        if (reason.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập lý do từ chối.')),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ref.read(creatorRequestsProvider.notifier).rejectRequest(req.id, reason);
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Đã từ chối đơn yêu cầu.')),
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleDeliver(PodcastRequest req, {String? milestoneId}) {
    final noteController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    PlatformFile? pickedFile;
    List<int>? pickedBytes;
    bool isSubmitting = false;

    // Determine target milestone
    String? selectedMilestoneId = milestoneId;
    if (selectedMilestoneId == null || selectedMilestoneId.isEmpty) {
      final pending = req.milestones.where((m) => m.status == 'NOT_STARTED' || m.status == 'REVISION_REQUESTED').toList();
      selectedMilestoneId = pending.isNotEmpty ? pending.first.id : (req.milestones.isNotEmpty ? req.milestones.first.id : null);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final byteCount = pickedBytes?.length ?? 0;

          // Find milestone name
          final selectedMilestone = req.milestones.where((m) => m.id == selectedMilestoneId).firstOrNull;

          return AlertDialog(
            title: const Text('Nộp bài cho người nghe', style: TextStyle(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chọn tệp âm thanh hoàn thiện để nộp cho người nghe nghiệm thu.'),
                  const SizedBox(height: AppSpacing.sm),
                  if (req.milestones.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedMilestoneId,
                      decoration: const InputDecoration(
                        labelText: 'Mốc thanh toán nộp bài',
                        isDense: true,
                      ),
                      items: req.milestones.map((m) {
                        return DropdownMenuItem<String>(
                          value: m.id,
                          child: Text('Mốc ${m.order}: ${m.title} (${AppFormatters.formatVND(m.amount)})'),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (val) {
                              setDialogState(() => selectedMilestoneId = val);
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else if (selectedMilestone != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_outlined, size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mốc ${selectedMilestone.order}: ${selectedMilestone.title}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            AppFormatters.formatVND(selectedMilestone.amount),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Nút chọn file âm thanh
                  InkWell(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            try {
                              PlatformFile? file;
                              try {
                                file = await FilePicker.pickFile(
                                  type: FileType.custom,
                                  allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'mp4'],
                                );
                              } catch (_) {
                                file = await FilePicker.pickFile(type: FileType.audio);
                              }
                              if (file != null && file.name.isNotEmpty) {
                                final bytes = await file.readAsBytes();
                                setDialogState(() {
                                  pickedFile = file;
                                  pickedBytes = bytes.isNotEmpty ? bytes : null;
                                });
                              }
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Lỗi chọn tệp: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          },
                    borderRadius: AppSpacing.roundedSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.primaryDark : AppColors.primaryLight).withValues(alpha: 0.08),
                        border: Border.all(
                          color: pickedFile != null ? AppColors.success : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
                        ),
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pickedFile != null ? Icons.check_circle_rounded : Icons.audio_file_rounded,
                            color: pickedFile != null ? AppColors.success : (isDark ? AppColors.primaryDark : AppColors.primaryLight),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickedFile != null ? pickedFile!.name : 'Chọn tệp âm thanh (.mp3, .wav, .m4a)',
                                  style: TextStyle(
                                    fontWeight: pickedFile != null ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (byteCount > 0)
                                  Text(
                                    '${(byteCount / 1024).toStringAsFixed(1)} KB',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.upload_file_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Ghi chú bàn giao',
                    hint: 'Mô tả tóm tắt bản thu âm bàn giao...',
                    controller: noteController,
                    maxLines: 3,
                    readOnly: isSubmitting,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Hủy'),
              ),
              AppButton(
                label: isSubmitting ? 'Đang nộp...' : 'Nộp ngay',
                width: 120,
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (pickedBytes == null || pickedFile == null) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Vui lòng chọn tệp âm thanh trước khi nộp.')),
                          );
                          return;
                        }
                        final note = noteController.text.trim();
                        setDialogState(() {
                          isSubmitting = true;
                        });
                        try {
                          await ref.read(creatorRequestsProvider.notifier).deliverWork(
                                req.id,
                                pickedFile!.name,
                                note.isNotEmpty ? note : 'Bản thu âm hoàn thiện cho đơn đặt podcast.',
                                fileBytes: pickedBytes,
                                filename: pickedFile?.name,
                                milestoneId: selectedMilestoneId,
                              );
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Đã nộp bài thành công! Đang chờ người nghe duyệt.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                          });
                          messenger.showSnackBar(
                            SnackBar(content: Text('Lỗi nộp bài: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}
