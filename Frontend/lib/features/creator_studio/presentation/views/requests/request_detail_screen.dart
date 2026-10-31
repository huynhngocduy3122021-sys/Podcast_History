import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/theme/app_typography.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/core/widgets/status_chip.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/notifications/notification_socket.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;

  const RequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  // Local audio player for previewing submitted audio files
  late final AudioPlayer _audioPlayer;
  String? _currentlyPlayingUrl;
  NotificationSocket? _chatSocket;
  void Function()? _removeChatReconnectListener;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _chatSocket = ref.read(creatorNotificationSocketProvider);
    if (_chatSocket != null) {
      _chatSocket!.listen('/user/queue/contract-chat', (event) {
        if ('${event['type'] ?? ''}' == 'CONTRACT_CHAT_MESSAGE' && mounted) {
          setState(() {});
        }
      });
      _removeChatReconnectListener = _chatSocket!.addReconnectListener(() {
        if (mounted) setState(() {});
      });
    }
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _currentPosition = pos);
      }
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() => _totalDuration = dur);
      }
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _removeChatReconnectListener?.call();
    _chatSocket?.unlisten('/user/queue/contract-chat');
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    try {
      if (_currentlyPlayingUrl == url && _isPlaying) {
        await _audioPlayer.pause();
      } else {
        _currentlyPlayingUrl = url;
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi phát âm thanh: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

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
            : const Center(
                child: Text('Không tìm thấy thông tin đơn đặt podcast.'),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hợp đồng & Đơn đặt podcast'),
        actions: [
          IconButton(
            tooltip: 'Nhắn tin với người nghe',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => _openChat(req),
          ),
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(creatorRequestsProvider.notifier).loadRequests(),
          ),
          if (req.hasEscrow &&
              req.contract != null &&
              (req.contract!.isInProgress || req.contract!.isDisputed))
            IconButton(
              tooltip: 'Tranh chấp / Chấm dứt',
              icon: const Icon(Icons.gavel_rounded, color: AppColors.error),
              onPressed: () => _handleTermination(req),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(creatorRequestsProvider.notifier).loadRequests(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  // 1. Thẻ thông tin trạng thái & Next step Escrow
                  _buildStatusBanner(req, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Stepper quy trình 5 bước Escrow
                  _buildWorkflowStepper(req, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Thông tin đơn hàng & Ngân sách giữ
                  _buildOrderOverview(req, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // 4. Thẻ Hợp đồng điện tử & Ký kết (Chữ ký số & SHA-256)
                  if (req.contract != null) ...[
                    _buildContractCard(req, isDark),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 5. Các mốc thanh toán Escrow (1 - 3 đợt)
                  _buildMilestonesSection(req, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // 6. Lịch sử bàn giao & Phát âm thanh preview
                  if (req.submissions.isNotEmpty ||
                      req.deliveryFileUrl != null) ...[
                    _buildSubmissionsHistory(req, isDark),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 7. Thông tin tranh chấp / chấm dứt nếu có
                  if (req.termination != null ||
                      (req.contract != null && req.contract!.isDisputed)) ...[
                    _buildDisputeSection(req, isDark),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Bar theo State Machine Hợp đồng Escrow
          _buildBottomActionButtons(req, isDark),
        ],
      ),
    );
  }

  Future<void> _openChat(PodcastRequest req) async {
    final controller = TextEditingController();
    final chatScrollController = ScrollController();
    var chatFuture = ref
        .read(creatorRepositoryProvider)
        .getChatMessages(req.id);
    var sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhắn tin với ${req.listenerName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: chatFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Không thể tải tin nhắn: ${snapshot.error}',
                          ),
                        );
                      }
                      final items = List<Map<String, dynamic>>.from(
                        snapshot.data ?? const [],
                      )..sort(_compareChatMessages);
                      if (items.isEmpty) {
                        return const Center(child: Text('Chưa có tin nhắn.'));
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (chatScrollController.hasClients) {
                          chatScrollController.jumpTo(
                            chatScrollController.position.maxScrollExtent,
                          );
                        }
                      });
                      return ListView.separated(
                        controller: chatScrollController,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          final isMine = _isCreatorChatMessage(item);
                          final content =
                              item['content'] ?? item['message'] ?? '';
                          return Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 290),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                                  bottomRight: Radius.circular(isMine ? 4 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMine)
                                    Text(
                                      'Người nghe',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  Text(
                                    '$content',
                                    style: TextStyle(
                                      color: isMine
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) async {
                          await _sendChatMessage(
                            req.id,
                            controller,
                            setSheetState,
                            () => sending,
                            (value) => sending = value,
                            (future) => chatFuture = future,
                          );
                        },
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Gửi tin nhắn',
                      onPressed: sending
                          ? null
                          : () async {
                              await _sendChatMessage(
                                req.id,
                                controller,
                                setSheetState,
                                () => sending,
                                (value) => sending = value,
                                (future) => chatFuture = future,
                              );
                            },
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    chatScrollController.dispose();
  }

  bool _isCreatorChatMessage(Map<String, dynamic> item) {
    final senderId = item['senderId']?.toString();
    final currentUserId = _currentCreatorUserId;
    if (senderId != null &&
        senderId.isNotEmpty &&
        currentUserId != null &&
        senderId == currentUserId) {
      return true;
    }
    if (item['isMine'] == true ||
        item['mine'] == true ||
        item['isCreator'] == true) {
      return true;
    }
    final role = '${item['senderRole'] ?? item['senderType'] ?? ''}'
        .toUpperCase();
    return role == 'CREATOR' || role == 'CC';
  }

  int _compareChatMessages(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final firstDate = DateTime.tryParse(
      '${first['createdAt'] ?? first['sentAt'] ?? ''}',
    );
    final secondDate = DateTime.tryParse(
      '${second['createdAt'] ?? second['sentAt'] ?? ''}',
    );
    if (firstDate == null || secondDate == null) return 0;
    return firstDate.compareTo(secondDate);
  }

  String? get _currentCreatorUserId {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is Map<String, dynamic>) {
        return '${payload['userId'] ?? payload['user_id'] ?? payload['sub'] ?? ''}'
            .trim();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _sendChatMessage(
    String requestId,
    TextEditingController controller,
    StateSetter setSheetState,
    bool Function() isSending,
    void Function(bool) setSending,
    void Function(Future<List<Map<String, dynamic>>>) setFuture,
  ) async {
    final content = controller.text.trim();
    if (content.isEmpty || isSending()) return;
    setSheetState(() => setSending(true));
    try {
      await ref
          .read(creatorRepositoryProvider)
          .sendChatMessage(requestId, content);
      controller.clear();
      setSheetState(
        () => setFuture(
          ref.read(creatorRepositoryProvider).getChatMessages(requestId),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi tin nhắn: $error')),
        );
      }
    } finally {
      setSheetState(() => setSending(false));
    }
  }

  // ==========================================
  // 1. STATUS BANNER
  // ==========================================
  Widget _buildStatusBanner(PodcastRequest req, bool isDark) {
    String nextAction;
    final contract = req.contract;

    if (req.hasEscrow) {
      if (contract == null) {
        if (req.status == CustomRequestStatus.rejected) {
          nextAction = 'Đơn yêu cầu này đã bị từ chối. Ngân sách đã được hoàn trả lại cho thính giả.';
        } else {
          nextAction = 'Bước tiếp theo: Hãy lập đề xuất các đợt bàn giao (1 đến 3 đợt) để tạo hợp đồng điện tử bảo đảm.';
        }
      } else if (contract.isPendingSignature) {
        if (!contract.isCreatorSigned) {
          nextAction = 'Bước tiếp theo: Hợp đồng đã tạo. Vui lòng xem kỹ điều khoản và ký xác nhận điện tử.';
        } else if (!contract.isListenerSigned) {
          nextAction = 'Bước tiếp theo: Bạn đã ký hợp đồng. Đang chờ người nghe ký để hợp đồng có hiệu lực sản xuất.';
        } else {
          nextAction = 'Hợp đồng đã đủ hai chữ ký và sẵn sàng bước vào giai đoạn sản xuất.';
        }
      } else if (contract.isInProgress) {
        if (req.milestones.any((m) => m.isRevisionRequested)) {
          nextAction = 'Chú ý: Người nghe yêu cầu chỉnh sửa ở đợt bàn giao. Vui lòng xem ghi chú và nộp lại bản sửa.';
        } else if (req.milestones.any((m) => m.isSubmitted)) {
          nextAction = 'Bước tiếp theo: Đã nộp bài đợt hiện tại. Đang chờ người nghe nghiệm thu (thời hạn 3 ngày).';
        } else {
          nextAction = 'Bước tiếp theo: Tiến hành sản xuất theo tiêu chí đã cam kết và nộp file bàn giao đúng hạn.';
        }
      } else if (contract.isCompleted) {
        nextAction = 'Chúc mừng! Đơn hàng đã hoàn tất nghiệm thu toàn bộ. 80% thù lao đã được thanh toán vào ví khả dụng.';
      } else if (contract.isDisputed) {
        nextAction = 'Hợp đồng đang trong thời gian ưu tiên thương lượng 3 ngày. Admin đang theo dõi giải quyết.';
      } else if (contract.isTerminated) {
        nextAction = 'Hợp đồng đã chấm dứt theo phán quyết của Admin.';
      } else {
        nextAction = 'Hợp đồng đã hủy.';
      }
    } else {
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
          nextAction =
              'Đơn đang trong diện khiếu nại. Admin đang tiến hành đối soát.';
          break;
        default:
          nextAction = '';
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: req.statusType == StatusType.success
            ? AppColors.successContainer
            : (req.statusType == StatusType.warning
                  ? AppColors.warningContainer
                  : (req.statusType == StatusType.error
                        ? AppColors.errorContainer
                        : AppColors.surfaceVariantLight)),
        borderRadius: AppSpacing.roundedMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (req.hasEscrow) ...[
                    const Icon(
                      Icons.shield_rounded,
                      size: 16,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'ESCROW BẢO ĐẢM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'TRẠNG THÁI HIỆN TẠI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark
                            ? AppColors.onSurfaceMutedDark
                            : AppColors.onSurfaceMutedLight,
                      ),
                    ),
                  ],
                ],
              ),
              StatusChip(label: req.statusDisplay, type: req.statusType),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            nextAction,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. WORKFLOW STEPPER
  // ==========================================
  Widget _buildWorkflowStepper(PodcastRequest req, bool isDark) {
    final steps = [
      'Gửi đơn',
      'Đề xuất mốc',
      'Ký hợp đồng',
      'Sản xuất',
      'Nghiệm thu',
    ];
    int activeIndex = 0;

    final contract = req.contract;
    if (contract == null) {
      activeIndex = req.status == CustomRequestStatus.sent ? 0 : 1;
    } else if (contract.isPendingSignature) {
      activeIndex = 2;
    } else if (contract.isInProgress) {
      activeIndex = 3;
    } else if (contract.isCompleted ||
        (req.milestones.isNotEmpty &&
            req.milestones.every((m) => m.isApproved))) {
      activeIndex = 4;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tiến trình hợp đồng Escrow',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
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
                        ? (isDark
                              ? AppColors.primaryDark
                              : AppColors.primaryLight)
                        : (isDark
                              ? AppColors.outlineDark
                              : AppColors.outlineLight),
                    child: isPassed && !isCurrent
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent
                          ? (isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight)
                          : null,
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

  // ==========================================
  // 3. ORDER OVERVIEW
  // ==========================================
  Widget _buildOrderOverview(PodcastRequest req, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
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
                onBackgroundImageError: req.listenerAvatar.isNotEmpty
                    ? (_, _) {}
                    : null,
                child: const Icon(Icons.person, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.listenerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ngân sách đã giữ an toàn trong ví',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.onSurfaceMutedDark
                                : AppColors.onSurfaceMutedLight,
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
            req.topic,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (req.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              req.description,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.onSurfaceDark
                    : AppColors.onSurfaceLight,
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
              _buildMetaItem(
                'Ngày tạo',
                AppFormatters.formatDate(req.createdAt),
                Icons.calendar_today_outlined,
              ),
              _buildMetaItem(
                'Phân chia',
                '80% CC • 20% App',
                Icons.pie_chart_outline,
              ),
              _buildMetaItem(
                'Ngân sách giữ',
                AppFormatters.formatVND(req.totalBudget),
                Icons.account_balance_wallet_outlined,
                isHighlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.tertiaryLight),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.onSurfaceMutedLight,
              ),
            ),
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

  // ==========================================
  // 4. CONTRACT CARD & SIGNATURE STATUS
  // ==========================================
  Widget _buildContractCard(PodcastRequest req, bool isDark) {
    final contract = req.contract!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: contract.isInProgress
              ? AppColors.primaryLight
              : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
          width: contract.isInProgress ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: AppColors.primaryLight,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Hợp đồng điện tử (v1)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: contract.isInProgress
                      ? AppColors.success.withValues(alpha: 0.12)
                      : (contract.isPendingSignature
                            ? AppColors.warning.withValues(alpha: 0.12)
                            : AppColors.info.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  contract.contractStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: contract.isInProgress
                        ? AppColors.success
                        : (contract.isPendingSignature
                              ? AppColors.warning
                              : AppColors.info),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mã băm SHA-256: ${contract.contentHash.length > 20 ? "${contract.contentHash.substring(0, 10)}...${contract.contentHash.substring(contract.contentHash.length - 8)}" : contract.contentHash}',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          // Trạng thái hai chữ ký
          Row(
            children: [
              Expanded(
                child: _buildSignatureStatus(
                  title: 'Content Creator',
                  isSigned: contract.isCreatorSigned,
                  signedAt: contract.creatorSignedAt,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildSignatureStatus(
                  title: 'Người nghe (Listener)',
                  isSigned: contract.isListenerSigned,
                  signedAt: contract.listenerSignedAt,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Nút xem toàn văn hợp đồng
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Xem văn bản hợp đồng'),
                  onPressed: () => _showContractDialog(req),
                ),
              ),
              if (!contract.isCreatorSigned) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.edit_document, size: 16),
                    label: const Text('Ký hợp đồng'),
                    onPressed: () => _showContractDialog(req, autoSign: true),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureStatus({
    required String title,
    required bool isSigned,
    DateTime? signedAt,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isSigned
            ? AppColors.success.withValues(alpha: 0.08)
            : (isDark
                  ? AppColors.surfaceVariantDark
                  : AppColors.surfaceVariantLight),
        borderRadius: AppSpacing.roundedSm,
        border: Border.all(
          color: isSigned
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSigned ? Icons.verified_rounded : Icons.pending_outlined,
                size: 14,
                color: isSigned ? AppColors.success : Colors.grey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            isSigned
                ? 'Đã ký lúc ${signedAt != null ? DateFormat('HH:mm dd/MM').format(signedAt.toLocal()) : ''}'
                : 'Chưa ký xác nhận',
            style: TextStyle(
              fontSize: 10,
              color: isSigned ? AppColors.success : Colors.grey,
              fontWeight: isSigned ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. MILESTONES (1-3 ĐỢT BÀN GIAO)
  // ==========================================
  Widget _buildMilestonesSection(PodcastRequest req, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Các đợt bàn giao & Mốc thanh toán',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              if (req.milestones.isNotEmpty)
                Text(
                  '${req.milestones.length} đợt',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.onSurfaceMutedDark
                        : AppColors.onSurfaceMutedLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (req.milestones.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    req.status == CustomRequestStatus.sent
                        ? 'Chưa thiết lập đợt bàn giao. Bạn hãy nhấn "Lập đề xuất đợt bàn giao" để chia tiến độ và gửi hợp đồng cho người nghe.'
                        : 'Chưa có thông tin đợt bàn giao.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? AppColors.onSurfaceMutedDark
                          : AppColors.onSurfaceMutedLight,
                    ),
                  ),
                ],
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
                  statusText = 'Đã nghiệm thu';
                  break;
                case 'SUBMITTED':
                  statusColor = AppColors.warning;
                  statusIcon = Icons.hourglass_top_rounded;
                  statusText = 'Chờ duyệt (3 ngày)';
                  break;
                case 'REVISION_REQUESTED':
                  statusColor = AppColors.error;
                  statusIcon = Icons.published_with_changes_rounded;
                  statusText = 'Yêu cầu sửa';
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

              // Creator can submit when contract is IN_PROGRESS and this milestone is NOT_STARTED or REVISION_REQUESTED
              final canSubmitThis =
                  (req.contract?.isInProgress == true ||
                      req.status == CustomRequestStatus.inProduction ||
                      req.status == CustomRequestStatus.accepted) &&
                  (m.status == 'NOT_STARTED' ||
                      m.status == 'REVISION_REQUESTED');

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceVariantLight,
                  borderRadius: AppSpacing.roundedSm,
                  border: Border.all(
                    color: m.isApproved
                        ? AppColors.success.withValues(alpha: 0.3)
                        : (m.isSubmitted
                              ? AppColors.warning.withValues(alpha: 0.3)
                              : (isDark
                                    ? AppColors.outlineDark
                                    : AppColors.outlineLight)),
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
                                'Đợt ${m.order}: ${m.title}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (m.description != null &&
                                  m.description!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  m.description!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.onSurfaceMutedDark
                                        : AppColors.onSurfaceMutedLight,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                    if (req.hasEscrow) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _buildDraftsForMilestone(m.id, isDark),
                    ],
                    if (canSubmitThis) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.upload_file_rounded, size: 14),
                          label: Text(
                            m.status == 'REVISION_REQUESTED'
                                ? 'Nộp lại bài chỉnh sửa'
                                : 'Nộp bài cho đợt này',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () =>
                              _handleDeliver(req, milestoneId: m.id),
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

  Widget _buildDraftsForMilestone(String milestoneId, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref
          .read(creatorRequestsProvider.notifier)
          .getMilestoneDrafts(milestoneId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final drafts = snapshot.data ?? const [];
        if (drafts.isEmpty) {
          return Text(
            'Chưa có bản nháp. Bản upload mới sẽ hiển thị ở đây để theo dõi AI.',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.onSurfaceMutedDark
                  : AppColors.onSurfaceMutedLight,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bản nháp AI (${drafts.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...drafts.map((draft) => _draftTile(milestoneId, draft, isDark)),
          ],
        );
      },
    );
  }

  Widget _draftTile(
    String milestoneId,
    Map<String, dynamic> draft,
    bool isDark,
  ) {
    final status = '${draft['status'] ?? 'PENDING'}'.toUpperCase();
    final confidence = (draft['aiConfidence'] as num?)?.toDouble();
    final statusColor = switch (status) {
      'APPROVED' => AppColors.success,
      'REJECTED' || 'FAILED' => AppColors.error,
      'REVIEW_REQUIRED' => AppColors.warning,
      _ => AppColors.info,
    };
    final draftId = draft['draftId']?.toString() ?? '';
    final canDeliver = status == 'APPROVED' && draftId.isNotEmpty;
    final canCancel =
        draftId.isNotEmpty && status != 'DELIVERED' && status != 'CANCELLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: AppSpacing.roundedSm,
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.audio_file_outlined, size: 18, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bản nháp #${draft['draftNumber'] ?? '-'} • $status',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                if (confidence != null)
                  Text(
                    'Confidence: ${(confidence * 100).toStringAsFixed(0)}% • ${draft['aiLabel'] ?? 'Chưa có kết quả'}',
                    style: const TextStyle(fontSize: 10),
                  ),
                if (draft['aiReason'] != null &&
                    '${draft['aiReason']}'.isNotEmpty)
                  Text(
                    '${draft['aiReason']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                if (draft['errorMessage'] != null &&
                    '${draft['errorMessage']}'.isNotEmpty)
                  Text(
                    '${draft['errorMessage']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppColors.error),
                  ),
              ],
            ),
          ),
          if (canDeliver || canCancel)
            PopupMenuButton<String>(
              tooltip: 'Thao tác draft',
              onSelected: (action) async {
                try {
                  if (action == 'deliver') {
                    await ref
                        .read(creatorRequestsProvider.notifier)
                        .deliverMilestoneDraft(milestoneId, draftId);
                  } else {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Hủy bản nháp?'),
                        content: const Text(
                          'Bản nháp sẽ được đánh dấu hủy và không thể bàn giao.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Không'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Hủy draft'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    await ref
                        .read(creatorRequestsProvider.notifier)
                        .cancelMilestoneDraft(milestoneId, draftId);
                  }
                  if (mounted) setState(() {});
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Không thể thực hiện thao tác draft: $error',
                        ),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                if (canDeliver)
                  const PopupMenuItem(
                    value: 'deliver',
                    child: Text('Bàn giao draft'),
                  ),
                if (canCancel)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Hủy draft'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. SUBMISSIONS HISTORY & AUDIO PLAYER
  // ==========================================
  Widget _buildSubmissionsHistory(PodcastRequest req, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.info, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.info),
              SizedBox(width: AppSpacing.xs),
              Text(
                'Lịch sử bàn giao sản phẩm',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (req.submissions.isNotEmpty)
            ...req.submissions.map((sub) {
              final isCurrentSubPlaying =
                  _currentlyPlayingUrl == sub.mediaUrl && _isPlaying;
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceVariantLight,
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lần nộp #${sub.revisionNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm dd/MM/yyyy')
                              .format(sub.submittedAt.toLocal()),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (sub.note != null && sub.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ghi chú: ${sub.note}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (sub.mediaUrl != null && sub.mediaUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            iconSize: 28,
                            color: AppColors.primaryLight,
                            icon: Icon(
                              isCurrentSubPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                            ),
                            onPressed: () => _playAudio(sub.mediaUrl!),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCurrentSubPlaying
                                      ? 'Đang phát âm thanh...'
                                      : 'Nghe thử bản ghi âm R2',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isCurrentSubPlaying)
                                  LinearProgressIndicator(
                                    value: _totalDuration.inMilliseconds > 0
                                        ? _currentPosition.inMilliseconds /
                                              _totalDuration.inMilliseconds
                                        : 0.0,
                                    backgroundColor: Colors.grey.withValues(
                                      alpha: 0.2,
                                    ),
                                    valueColor: const AlwaysStoppedAnimation(
                                      AppColors.primaryLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            })
          else ...[
            if (req.deliveryNote != null) Text('Ghi chú: ${req.deliveryNote}'),
            if (req.deliveryFileUrl != null)
              Text(
                'Tệp: ${req.deliveryFileUrl}',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 7. DISPUTE & TERMINATION SECTION
  // ==========================================
  Widget _buildDisputeSection(PodcastRequest req, bool isDark) {
    final termination = req.termination;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel_rounded, color: AppColors.error, size: 20),
              SizedBox(width: 6),
              Text(
                'Yêu cầu chấm dứt & Tranh chấp hợp đồng',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Hợp đồng đã đóng băng bước nghiệm thu/giải ngân. Hai bên có 3 ngày thương lượng tự giải quyết.',
            style: TextStyle(fontSize: 12),
          ),
          if (termination != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hạn thương lượng đến: ${DateFormat('HH:mm dd/MM/yyyy').format(termination.negotiationEndsAt.toLocal())}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Quy định Admin: Nếu xác nhận sản phẩm đạt tiêu chuẩn tối thiểu, CC nhận đền công 30% giá trị đợt đó (trừ 10% phí app, CC nhận ròng 90% khoản đền công). Phần còn lại hoàn trả cho người nghe.',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 8. BOTTOM ACTION BUTTONS
  // ==========================================
  Widget _buildBottomActionButtons(PodcastRequest req, bool isDark) {
    final contract = req.contract;

    // Completed
    if (contract?.isCompleted == true ||
        req.status == CustomRequestStatus.completed) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: AppColors.successContainer,
        child: const Center(
          child: Text(
            '✓ Hợp đồng đã hoàn tất và tất toán toàn bộ thù lao vào ví.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ),
      );
    }

    // Rejected
    if (req.status == CustomRequestStatus.rejected) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: AppColors.surfaceVariantLight,
        child: const Center(
          child: Text(
            'Đơn yêu cầu này đã bị từ chối.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceMutedLight,
            ),
          ),
        ),
      );
    }

    // No proposal yet -> Propose Milestones / Reject
    if (contract == null && req.status == CustomRequestStatus.sent) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Từ chối',
                type: AppButtonType.secondary,
                onPressed: () => _handleReject(req),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 4,
              child: AppButton(
                label: 'Lập đề xuất đợt bàn giao',
                onPressed: () => _handleProposeMilestones(req),
              ),
            ),
          ],
        ),
      );
    }

    // Pending signature -> Sign Contract
    if (contract != null && contract.isPendingSignature) {
      if (!contract.isCreatorSigned) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
              ),
            ),
          ),
          child: AppButton(
            label: 'Xem & Ký hợp đồng điện tử',
            onPressed: () => _showContractDialog(req, autoSign: true),
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: AppColors.warningContainer,
          child: const Center(
            child: Text(
              'Bạn đã ký hợp đồng. Đang chờ người nghe ký kết...',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
        );
      }
    }

    // In Progress -> Deliver milestone work
    if (contract?.isInProgress == true ||
        req.status == CustomRequestStatus.inProduction ||
        req.status == CustomRequestStatus.accepted ||
        req.status == CustomRequestStatus.revisionRequested) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
            ),
          ),
        ),
        child: AppButton(
          label: 'Nộp bài / Gửi bản audio hoàn chỉnh',
          onPressed: () => _handleDeliver(req),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ==========================================
  // DIALOG: LẬP ĐỀ XUẤT 1 - 3 ĐỢT BÀN GIAO
  // ==========================================
  void _handleProposeMilestones(PodcastRequest req) {
    final messenger = ScaffoldMessenger.of(context);
    final totalBudget = req.totalBudget;
    int stageCount = 2; // Default 2 stages
    final responseTextController = TextEditingController(
      text: 'Tôi đồng ý sản xuất podcast theo yêu cầu và đề xuất các đợt bàn giao như dưới đây.',
    );

    // Stage inputs. The backend accepts any number of milestones (up to 30).
    final nameControllers = <TextEditingController>[
      TextEditingController(text: 'Đợt 1: Bản nháp podcast & demo giọng'),
      TextEditingController(text: 'Đợt 2: Bản hoàn thiện audio & hậu kỳ'),
      TextEditingController(text: 'Đợt 3: Master audio & nghiệm thu'),
    ];
    final descControllers = <TextEditingController>[
      TextEditingController(
        text: 'Phác thảo kịch bản chi tiết và thu âm demo 3 phút đầu.',
      ),
      TextEditingController(
        text: 'Hoàn thiện toàn bộ bản ghi âm kèm nhạc nền và hiệu ứng.',
      ),
      TextEditingController(
        text: 'Chỉnh sửa âm lượng master chuẩn 320kbps và nghiệm thu.',
      ),
    ];
    final initialP1 = (totalBudget * 0.4).toInt();
    final initialP2 = totalBudget - initialP1;
    final amountControllers = <TextEditingController>[
      TextEditingController(text: totalBudget > 0 ? '$initialP1' : '0'),
      TextEditingController(text: totalBudget > 0 ? '$initialP2' : '0'),
      TextEditingController(text: '0'),
    ];
    final dueDates = <DateTime>[
      DateTime.now().add(const Duration(days: 3)),
      DateTime.now().add(const Duration(days: 7)),
      DateTime.now().add(const Duration(days: 10)),
    ];

    void resizeStages(int requestedCount, StateSetter update) {
      final count = requestedCount.clamp(1, 30);
      while (nameControllers.length < count) {
        final index = nameControllers.length + 1;
        nameControllers.add(TextEditingController(text: 'Đợt $index'));
        descControllers.add(
          TextEditingController(
            text: 'Bàn giao sản phẩm đợt $index theo cam kết.',
          ),
        );
        amountControllers.add(TextEditingController(text: '0'));
        dueDates.add(
          dueDates.isEmpty
              ? DateTime.now().add(const Duration(days: 3))
              : dueDates.last.add(const Duration(days: 3)),
        );
      }
      while (nameControllers.length > count) {
        nameControllers.removeLast().dispose();
        descControllers.removeLast().dispose();
        amountControllers.removeLast().dispose();
        dueDates.removeLast();
      }

      final share = count == 0 ? 0 : totalBudget ~/ count;
      final remainder = totalBudget - (share * count);
      for (var index = 0; index < count; index++) {
        amountControllers[index].text =
            '${share + (index == count - 1 ? remainder : 0)}';
      }
      update(() => stageCount = count);
    }

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          int currentTotal = 0;
          for (int i = 0; i < stageCount; i++) {
            currentTotal +=
                int.tryParse(
                  amountControllers[i].text
                      .replaceAll('.', '')
                      .replaceAll(',', ''),
                ) ??
                0;
          }
          final isBudgetMatching = currentTotal == totalBudget;

          return AlertDialog(
            title: const Text(
              'Lập đề xuất đợt bàn giao (1 - 3 đợt)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngân sách hợp đồng: ${AppFormatters.formatVND(totalBudget)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tổng các đợt: ${AppFormatters.formatVND(currentTotal)} '
                            '(${isBudgetMatching ? "Hợp lệ" : "Chưa khớp, chênh lệch ${AppFormatters.formatVND(totalBudget - currentTotal)}"})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isBudgetMatching
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Lời nhắn
                    AppTextField(
                      label: 'Lời nhắn gửi người nghe',
                      hint: 'Nhập ghi chú phản hồi...',
                      controller: responseTextController,
                      maxLines: 2,
                      readOnly: isSubmitting,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Chọn số đợt
                    Row(
                      children: [
                        const Text(
                          'Số đợt bàn giao: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('1 đợt'),
                          selected: stageCount == 1,
                          onSelected: isSubmitting
                              ? null
                              : (_) => resizeStages(1, setDialogState),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('2 đợt'),
                          selected: stageCount == 2,
                          onSelected: isSubmitting
                              ? null
                              : (_) => resizeStages(2, setDialogState),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('3 đợt'),
                          selected: stageCount == 3,
                          onSelected: isSubmitting
                              ? null
                              : (_) => resizeStages(3, setDialogState),
                        ),
                        const SizedBox(width: 6),
                        if (stageCount > 3)
                          Text(
                            '$stageCount đợt',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        IconButton(
                          tooltip: 'Bớt một đợt',
                          onPressed: isSubmitting || stageCount <= 1
                              ? null
                              : () => resizeStages(
                                  stageCount - 1,
                                  setDialogState,
                                ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          tooltip: 'Thêm một đợt',
                          onPressed: isSubmitting || stageCount >= 30
                              ? null
                              : () => resizeStages(
                                  stageCount + 1,
                                  setDialogState,
                                ),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Danh sách đợt
                    ...List.generate(stageCount, (i) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.08),
                          borderRadius: AppSpacing.roundedSm,
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đợt ${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AppTextField(
                              label: 'Tên đợt',
                              controller: nameControllers[i],
                              readOnly: isSubmitting,
                            ),
                            const SizedBox(height: 6),
                            AppTextField(
                              label: 'Mô tả công việc',
                              controller: descControllers[i],
                              readOnly: isSubmitting,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Số tiền (VND)',
                                    controller: amountControllers[i],
                                    keyboardType: TextInputType.number,
                                    readOnly: isSubmitting,
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: isSubmitting
                                        ? null
                                        : () async {
                                            final minDate = i == 0
                                                ? DateTime.now().add(
                                                    const Duration(days: 1),
                                                  )
                                                : dueDates[i - 1].add(
                                                    const Duration(days: 1),
                                                  );
                                            final initial =
                                                dueDates[i].isAfter(minDate)
                                                ? dueDates[i]
                                                : minDate;
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: initial,
                                              firstDate: minDate,
                                              lastDate: DateTime.now().add(
                                                const Duration(days: 365),
                                              ),
                                            );
                                            if (picked != null) {
                                              setDialogState(() {
                                                dueDates[i] = picked;
                                                for (
                                                  int j = i + 1;
                                                  j < dueDates.length;
                                                  j++
                                                ) {
                                                  if (!dueDates[j].isAfter(
                                                    dueDates[j - 1],
                                                  )) {
                                                    dueDates[j] =
                                                        dueDates[j - 1].add(
                                                          const Duration(
                                                            days: 3,
                                                          ),
                                                        );
                                                  }
                                                }
                                              });
                                            }
                                          },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Hạn nộp (Deadline)',
                                        isDense: true,
                                      ),
                                      child: Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(dueDates[i]),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Hủy'),
              ),
              AppButton(
                label: isSubmitting ? 'Đang gửi...' : 'Gửi đề xuất hợp đồng',
                isLoading: isSubmitting,
                onPressed: (!isBudgetMatching || isSubmitting)
                    ? null
                    : () async {
                        final respText = responseTextController.text.trim();
                        if (respText.isEmpty) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Vui lòng nhập lời nhắn phản hồi gửi người nghe.',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        // Validate strictly increasing due dates in future
                        final now = DateTime.now();
                        DateTime prev = now;
                        for (int i = 0; i < stageCount; i++) {
                          if (!dueDates[i].isAfter(prev)) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Hạn nộp đợt ${i + 1} phải lớn hơn hạn nộp đợt trước và ở tương lai.',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          prev = dueDates[i];
                        }

                        setDialogState(() => isSubmitting = true);
                        try {
                          final stages = List.generate(stageCount, (i) {
                            final amt = int.parse(
                              amountControllers[i].text
                                  .replaceAll('.', '')
                                  .replaceAll(',', ''),
                            );
                            final name =
                                nameControllers[i].text.trim().isNotEmpty
                                ? nameControllers[i].text.trim()
                                : 'Đợt ${i + 1}';
                            final desc =
                                descControllers[i].text.trim().isNotEmpty
                                ? descControllers[i].text.trim()
                                : 'Bàn giao sản phẩm đợt ${i + 1} theo cam kết.';
                            return ContractProposalStageInput(
                              name: name,
                              description: desc,
                              dueAt: dueDates[i],
                              amount: amt,
                            );
                          });

                          await ref
                              .read(creatorRequestsProvider.notifier)
                              .proposeContract(
                                req.id,
                                responseText: respText,
                                milestones: stages,
                              );

                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã gửi đề xuất hợp đồng thành công!',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Lỗi gửi đề xuất: $e'),
                              backgroundColor: AppColors.error,
                            ),
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

  // ==========================================
  // DIALOG: XEM & KÝ HỢP ĐỒNG ĐIỆN TỬ
  // ==========================================
  void _showContractDialog(PodcastRequest req, {bool autoSign = false}) {
    final contract = req.contract;
    if (contract == null) return;

    final messenger = ScaffoldMessenger.of(context);
    bool agreed = autoSign;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.primaryLight,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Hợp đồng sản xuất nội dung số',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 550,
              height: 480,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceVariantDark
                          : AppColors.surfaceVariantLight,
                      borderRadius: AppSpacing.roundedSm,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fingerprint_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'SHA-256: ${contract.contentHash}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Nội dung văn bản hợp đồng
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: AppSpacing.roundedSm,
                        border: Border.all(
                          color: isDark
                              ? AppColors.outlineDark
                              : AppColors.outlineLight,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          contract.contentSnapshot.isNotEmpty
                              ? contract.contentSnapshot
                              : 'Đang tải điều khoản hợp đồng...',
                          style: const TextStyle(fontSize: 12.5, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (!contract.isCreatorSigned) ...[
                    Row(
                      children: [
                        Checkbox(
                          value: agreed,
                          activeColor: AppColors.primaryLight,
                          onChanged: isSubmitting
                              ? null
                              : (val) {
                                  setDialogState(() => agreed = val ?? false);
                                },
                        ),
                        const Expanded(
                          child: Text(
                            'Tôi đã đọc, hiểu rõ và đồng ý toàn bộ điều khoản trong hợp đồng điện tử này.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      color: AppColors.successContainer,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Bạn đã ký hợp đồng lúc ${contract.creatorSignedAt != null ? DateFormat('HH:mm dd/MM/yyyy').format(contract.creatorSignedAt!.toLocal()) : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Đóng'),
              ),
              if (!contract.isCreatorSigned)
                AppButton(
                  label: isSubmitting ? 'Đang ký...' : 'Ký xác nhận điện tử',
                  isLoading: isSubmitting,
                  onPressed: (!agreed || isSubmitting)
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          try {
                            await ref
                                .read(creatorRequestsProvider.notifier)
                                .signContract(
                                  req.id,
                                  contractVersion: contract.contractVersion,
                                  contentHash: contract.contentHash,
                                );
                            if (dialogCtx.mounted)
                              Navigator.of(dialogCtx).pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã ký hợp đồng điện tử thành công!',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Lỗi ký hợp đồng: $e'),
                                backgroundColor: AppColors.error,
                              ),
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

  // ==========================================
  // DIALOG: NỘP SẢN PHẨM BÀN GIAO
  // ==========================================
  void _handleDeliver(PodcastRequest req, {String? milestoneId}) {
    final noteController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    PlatformFile? pickedFile;
    List<int>? pickedBytes;
    bool isSubmitting = false;

    // Determine target milestone
    String? selectedMilestoneId = milestoneId;
    if (selectedMilestoneId == null || selectedMilestoneId.isEmpty) {
      final pending = req.milestones
          .where(
            (m) =>
                m.status == 'NOT_STARTED' || m.status == 'REVISION_REQUESTED',
          )
          .toList();
      selectedMilestoneId = pending.isNotEmpty
          ? pending.first.id
          : (req.milestones.isNotEmpty ? req.milestones.first.id : null);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final byteCount = pickedBytes?.length ?? 0;
          final selectedMilestone = req.milestones
              .where((m) => m.id == selectedMilestoneId)
              .firstOrNull;

          return AlertDialog(
            title: const Text(
              'Nộp bài cho người nghe',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn tệp âm thanh/video hoàn thiện để nộp cho người nghe nghiệm thu.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (req.milestones.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedMilestoneId,
                      decoration: const InputDecoration(
                        labelText: 'Đợt nộp bài',
                        isDense: true,
                      ),
                      items: req.milestones.map((m) {
                        return DropdownMenuItem<String>(
                          value: m.id,
                          child: Text(
                            'Đợt ${m.order}: ${m.title} (${AppFormatters.formatVND(m.amount)})',
                          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceVariantDark
                            : AppColors.surfaceVariantLight,
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.layers_outlined,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đợt ${selectedMilestone.order}: ${selectedMilestone.title}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            AppFormatters.formatVND(selectedMilestone.amount),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // File picker box
                  InkWell(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            try {
                              PlatformFile? file;
                              try {
                                file = await FilePicker.pickFile(
                                  type: FileType.custom,
                                  allowedExtensions: [
                                    'mp3',
                                    'wav',
                                    'm4a',
                                    'aac',
                                    'ogg',
                                    'mp4',
                                  ],
                                );
                              } catch (_) {
                                file = await FilePicker.pickFile(
                                  type: FileType.audio,
                                );
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
                                SnackBar(
                                  content: Text('Lỗi chọn tệp: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                    borderRadius: AppSpacing.roundedSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primaryLight)
                                .withValues(alpha: 0.08),
                        border: Border.all(
                          color: pickedFile != null
                              ? AppColors.success
                              : (isDark
                                    ? AppColors.outlineDark
                                    : AppColors.outlineLight),
                        ),
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pickedFile != null
                                ? Icons.check_circle_rounded
                                : Icons.audio_file_rounded,
                            color: pickedFile != null
                                ? AppColors.success
                                : (isDark
                                      ? AppColors.primaryDark
                                      : AppColors.primaryLight),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickedFile != null
                                      ? pickedFile!.name
                                      : 'Chọn tệp âm thanh (.mp3, .wav, .m4a)',
                                  style: TextStyle(
                                    fontWeight: pickedFile != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (byteCount > 0)
                                  Text(
                                    '${(byteCount / 1024).toStringAsFixed(1)} KB',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
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
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogCtx).pop(),
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
                            const SnackBar(
                              content: Text(
                                'Vui lòng chọn tệp âm thanh trước khi nộp.',
                              ),
                            ),
                          );
                          return;
                        }
                        final note = noteController.text.trim();
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ref
                              .read(creatorRequestsProvider.notifier)
                              .deliverWork(
                                req.id,
                                pickedFile!.name,
                                note.isNotEmpty ? note : 'Bản thu âm hoàn thiện cho đơn đặt podcast.',
                                fileBytes: pickedBytes,
                                filename: pickedFile?.name,
                                milestoneId: selectedMilestoneId,
                              );
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                req.hasEscrow
                                    ? 'Đã tải bản nháp. Hệ thống sẽ kiểm duyệt AI trước khi bạn bàn giao.'
                                    : 'Đã nộp bài thành công! Người nghe có 3 ngày để nghiệm thu.',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Lỗi nộp bài: $e'),
                              backgroundColor: AppColors.error,
                            ),
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

  // ==========================================
  // DIALOG: TRANH CHẤP / CHẤM DỨT HỢP ĐỒNG
  // ==========================================
  void _handleTermination(PodcastRequest req) {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Yêu cầu chấm dứt hợp đồng',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lưu ý: Khi yêu cầu chấm dứt, hợp đồng sẽ chuyển sang trạng thái Tranh chấp. Hai bên có 3 ngày thương lượng trước khi Admin đưa ra quyết định đền công / hoàn tiền.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Lý do chấm dứt hợp đồng',
                    hint: 'Nêu rõ nguyên nhân không thể tiếp tục thực hiện...',
                    controller: reasonController,
                    maxLines: 4,
                    readOnly: isSubmitting,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Hủy'),
              ),
              AppButton(
                label: isSubmitting ? 'Đang gửi...' : 'Gửi yêu cầu chấm dứt',
                type: AppButtonType.secondary,
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reason = reasonController.text.trim();
                        if (reason.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng nhập lý do chấm dứt.'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ref
                              .read(creatorRequestsProvider.notifier)
                              .requestTermination(req.id, reason: reason);
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Đã mở yêu cầu chấm dứt hợp đồng.'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $e'),
                              backgroundColor: AppColors.error,
                            ),
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

  // ==========================================
  // DIALOG: TỪ CHỐI ĐƠN HÀNG
  // ==========================================
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
            title: const Text(
              'Từ chối đơn yêu cầu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ngân sách đang giữ sẽ được hoàn trả lại ví của người nghe. Vui lòng cung cấp lý do từ chối:',
                  ),
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
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogCtx).pop(),
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
                            const SnackBar(
                              content: Text('Vui lòng nhập lý do từ chối.'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ref
                              .read(creatorRequestsProvider.notifier)
                              .rejectRequest(req.id, reason);
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã từ chối đơn yêu cầu và hoàn tiền giữ cho thính giả.',
                              ),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $e'),
                              backgroundColor: AppColors.error,
                            ),
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
