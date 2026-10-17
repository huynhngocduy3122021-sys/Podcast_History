import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/theme/app_typography.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_confirm_dialog.dart';
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
  final TextEditingController _chatController = TextEditingController();

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(creatorRequestsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final requests = requestsAsync.value ?? [];
    final req = requests.firstWhere(
      (r) => r.id == widget.requestId,
      orElse: () => requests.first,
    );

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

                // Các mốc thanh toán Escrow
                _buildMilestonesSection(req, isDark),
                const SizedBox(height: AppSpacing.lg),

                // Sản phẩm đã nộp (nếu có)
                if (req.deliveryFileUrl != null || req.deliveryNote != null) ...[
                  _buildDeliverySection(req, isDark),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Khung trao đổi tin nhắn (Chat)
                _buildChatSection(req, isDark),
                const SizedBox(height: AppSpacing.lg),
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
        nextAction = 'Bước tiếp theo: Thực hiện nội dung và nộp bản thu âm trước hạn chót.';
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
    if (req.status == CustomRequestStatus.delivered) activeIndex = 3;
    if (req.status == CustomRequestStatus.completed || req.status == CustomRequestStatus.approved) activeIndex = 4;

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
          const Text('Tiến trình State Machine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                backgroundImage: NetworkImage(req.listenerAvatar),
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
                      'Người nghe đặt bài • Đã thanh toán tạm giữ Escrow',
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            req.description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaItem('Thời lượng mong muốn', '${req.targetDurationMinutes} phút', Icons.timer_outlined),
              _buildMetaItem('Hạn hoàn thành', AppFormatters.formatDate(req.deadline), Icons.calendar_today_outlined),
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
          const Text('Các mốc giải ngân (Escrow Milestones)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: AppSpacing.sm),
          ...req.milestones.map((m) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                borderRadius: AppSpacing.roundedSm,
              ),
              child: Row(
                children: [
                  Icon(
                    m.isApproved ? Icons.check_circle_rounded : (m.isCompleted ? Icons.hourglass_top_rounded : Icons.radio_button_unchecked),
                    size: 18,
                    color: m.isApproved ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      m.title,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    AppFormatters.formatVND(m.amount),
                    style: AppTypography.tabularNumbers(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: m.isApproved ? AppColors.success : null,
                    ),
                  ),
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
          if (req.deliveryNote != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Ghi chú: ${req.deliveryNote}', style: const TextStyle(fontSize: 13)),
          ],
          if (req.deliveryFileUrl != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('File: ${req.deliveryFileUrl}', style: const TextStyle(fontSize: 12, color: AppColors.tertiaryLight)),
          ],
        ],
      ),
    );
  }

  Widget _buildChatSection(PodcastRequest req, bool isDark) {
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
          const Text('Trao đổi & Ghi chú', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: AppSpacing.sm),
          if (req.messages.isEmpty)
            const Text('Chưa có tin nhắn nào.', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedLight))
          else
            ...req.messages.map((msg) {
              return Align(
                alignment: msg.isCreator ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: msg.isCreator
                        ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                        : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight),
                    borderRadius: AppSpacing.roundedMd,
                  ),
                  child: Column(
                    crossAxisAlignment: msg.isCreator ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: msg.isCreator ? Colors.white : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppFormatters.timeAgo(msg.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: msg.isCreator ? Colors.white70 : AppColors.onSurfaceMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: const InputDecoration(
                    hintText: 'Nhắn tin cho người nghe...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primaryLight),
                onPressed: () {
                  final text = _chatController.text.trim();
                  if (text.isNotEmpty) {
                    ref.read(creatorRequestsProvider.notifier).sendMessage(req.id, text);
                    _chatController.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons(PodcastRequest req, bool isDark) {
    if (req.status == CustomRequestStatus.completed) {
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
                onPressed: () async {
                  await ref.read(creatorRequestsProvider.notifier).acceptRequest(req.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã nhận đơn! Bạn có thể bắt đầu sản xuất podcast.')),
                    );
                  }
                },
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

  void _handleReject(PodcastRequest req) {
    final reasonController = TextEditingController();
    final nav = Navigator.of(context);
    AppConfirmDialog.show(
      context,
      title: 'Từ chối đơn yêu cầu',
      content: 'Vui lòng cung cấp lý do từ chối để người nghe được biết và nhận lại tiền cọc Escrow.',
      confirmLabel: 'Từ chối',
      isDestructive: true,
      onConfirm: () async {
        await ref.read(creatorRequestsProvider.notifier).rejectRequest(
              req.id,
              reasonController.text.trim().isEmpty ? 'Tác giả bận lịch sản xuất' : reasonController.text.trim(),
            );
        nav.pop();
      },
    );
  }

  void _handleDeliver(PodcastRequest req) {
    final linkController = TextEditingController();
    final noteController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    PlatformFile? pickedFile;
    List<int>? pickedBytes;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final byteCount = pickedBytes?.length ?? 0;
          return AlertDialog(
            title: const Text('Nộp bài cho người nghe', style: TextStyle(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Người nghe sẽ nghe thử và có quyền Duyệt để giải phóng tiền hoặc Yêu cầu chỉnh sửa.'),
                  const SizedBox(height: AppSpacing.md),
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
                                final selectedName = file.name;
                                final bytes = await file.readAsBytes();
                                setDialogState(() {
                                  pickedFile = file;
                                  pickedBytes = bytes.isNotEmpty ? bytes : null;
                                  if (linkController.text.trim().isEmpty) {
                                    linkController.text = selectedName;
                                  }
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
                                  pickedFile != null ? pickedFile!.name : 'Chọn tệp âm thanh bàn giao (.mp3, .wav, .m4a)',
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
                    label: 'Liên kết âm thanh / Tên tệp bàn giao',
                    hint: 'https://... hoặc tên tệp hoàn thiện',
                    controller: linkController,
                    readOnly: isSubmitting,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Ghi chú bàn giao',
                    hint: 'Mô tả tóm tắt bản thu âm...',
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
                        final link = linkController.text.trim();
                        final note = noteController.text.trim();
                        setDialogState(() {
                          isSubmitting = true;
                        });
                        try {
                          await ref.read(creatorRequestsProvider.notifier).deliverWork(
                                req.id,
                                link.isNotEmpty ? link : (pickedFile?.name ?? 'delivery_${req.id}.mp3'),
                                note.isNotEmpty ? note : 'Bản thu âm hoàn thiện cho đơn đặt podcast.',
                                fileBytes: pickedBytes,
                                filename: pickedFile?.name,
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
