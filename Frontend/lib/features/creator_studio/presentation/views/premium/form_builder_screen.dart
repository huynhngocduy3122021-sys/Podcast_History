import 'package:flutter/material.dart';
import 'package:podcast_history/core/widgets/top_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/empty_state_widget.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';

class FormBuilderScreen extends ConsumerStatefulWidget {
  const FormBuilderScreen({super.key});

  @override
  ConsumerState<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends ConsumerState<FormBuilderScreen> {
  String _selectedFilter = 'ALL'; // ALL, OPEN, DRAFT, CLOSED

  @override
  Widget build(BuildContext context) {
    final pollsAsync = ref.watch(creatorPollsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khảo sát & Bình chọn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại danh sách',
            onPressed: () => ref.read(creatorPollsProvider.notifier).loadPolls(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Tạo bình chọn mới', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCreatePollDialog(context),
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterTabs(isDark),
          Expanded(
            child: pollsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorStateWidget(
                message: 'Không thể tải danh sách bình chọn: $e',
                onRetry: () => ref.read(creatorPollsProvider.notifier).loadPolls(),
              ),
              data: (polls) {
                final filtered = polls.where((p) {
                  if (_selectedFilter == 'ALL') return !p.isDeleted;
                  return p.status.toUpperCase() == _selectedFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.poll_outlined,
                    title: _selectedFilter == 'ALL'
                        ? 'Chưa có cuộc bình chọn nào'
                        : 'Không có bình chọn nào ở trạng thái này',
                    description: 'Tạo câu hỏi bình chọn để tương tác và lấy ý kiến của thính giả cho các tập podcast tiếp theo.',
                    actionLabel: 'Tạo bình chọn mới',
                    onAction: () => _showCreatePollDialog(context),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    AppSpacing.sm,
                    AppSpacing.screenMargin,
                    80,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final poll = filtered[index];
                    return _buildPollCard(poll, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    final filters = [
      {'label': 'Tất cả', 'key': 'ALL'},
      {'label': 'Đang mở', 'key': 'OPEN'},
      {'label': 'Bản nháp', 'key': 'DRAFT'},
      {'label': 'Đã đóng', 'key': 'CLOSED'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isSelected = _selectedFilter == f['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  f['label']!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                  ),
                ),
                backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                selectedColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
                  ),
                ),
                onSelected: (_) => setState(() => _selectedFilter = f['key']!),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPollCard(CreatorPoll poll, bool isDark) {
    Color statusColor;
    String statusText;
    switch (poll.status.toUpperCase()) {
      case 'OPEN':
        statusColor = AppColors.success;
        statusText = 'Đang mở bình chọn';
        break;
      case 'DRAFT':
        statusColor = AppColors.warning;
        statusText = 'Bản nháp';
        break;
      case 'CLOSED':
        statusColor = isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight;
        statusText = 'Đã kết thúc';
        break;
      default:
        statusColor = AppColors.tertiaryLight;
        statusText = poll.status;
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

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
          // Header: Status badge & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (poll.createdAt != null)
                Text(
                  dateFormat.format(poll.createdAt!.toLocal()),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Question
          Text(
            poll.question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Options preview
          if (poll.options.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: poll.options.map((opt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.radio_button_unchecked_rounded,
                        size: 15,
                        color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          opt.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),

          // Action Buttons Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Xem kết quả
              if (poll.isOpen || poll.isClosed)
                TextButton.icon(
                  icon: const Icon(Icons.bar_chart_rounded, size: 16),
                  label: const Text('Kết quả'),
                  onPressed: () => _showPollResultsSheet(context, poll.pollId),
                ),

              // Xem danh sách người trả lời
              if (poll.isOpen || poll.isClosed)
                TextButton.icon(
                  icon: const Icon(Icons.people_outline_rounded, size: 16),
                  label: const Text('Người vote'),
                  onPressed: () => _showPollResponsesSheet(context, poll.pollId),
                ),

              // Công bố nếu DRAFT
              if (poll.isDraft)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.successContainer,
                    foregroundColor: AppColors.success,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text('Công bố'),
                  onPressed: () => _confirmPublishPoll(context, poll),
                ),

              // Đóng nếu OPEN
              if (poll.isOpen)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                  icon: const Icon(Icons.lock_clock_rounded, size: 16),
                  label: const Text('Đóng'),
                  onPressed: () => _confirmClosePoll(context, poll),
                ),

              // Nút xóa poll
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.error,
                tooltip: 'Xóa bình chọn',
                onPressed: () => _confirmDeletePoll(context, poll),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- DIALOG: TẠO POLL MỚI ---
  void _showCreatePollDialog(BuildContext context) {
    final questionCtrl = TextEditingController();
    final optionCtrls = [
      TextEditingController(),
      TextEditingController(),
    ];
    bool isPublishing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tạo cuộc bình chọn mới',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Câu hỏi
                    TextField(
                      controller: questionCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Câu hỏi bình chọn *',
                        hintText: 'VD: Bạn muốn tập podcast tiếp theo khám phá triều đại nào?',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Danh sách options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Các lựa chọn trả lời (2 – 20 lựa chọn):',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (optionCtrls.length < 20)
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Thêm lựa chọn', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              setModalState(() {
                                optionCtrls.add(TextEditingController());
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(optionCtrls.length, (idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.secondaryLight.withValues(alpha: 0.15),
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: optionCtrls[idx],
                                decoration: InputDecoration(
                                  hintText: 'Lựa chọn ${idx + 1}',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            if (optionCtrls.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                onPressed: () {
                                  setModalState(() {
                                    optionCtrls.removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // Nút bấm Lưu nháp / Công bố
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: isPublishing
                                ? null
                                : () => _submitPoll(
                                      sheetContext,
                                      questionCtrl,
                                      optionCtrls,
                                      publishNow: false,
                                      onStateChange: (v) => setModalState(() => isPublishing = v),
                                    ),
                            child: const Text('Lưu bản nháp'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: isPublishing
                                ? null
                                : () => _submitPoll(
                                      sheetContext,
                                      questionCtrl,
                                      optionCtrls,
                                      publishNow: true,
                                      onStateChange: (v) => setModalState(() => isPublishing = v),
                                    ),
                            child: isPublishing
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
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitPoll(
    BuildContext sheetContext,
    TextEditingController questionCtrl,
    List<TextEditingController> optionCtrls, {
    required bool publishNow,
    required void Function(bool) onStateChange,
  }) async {
    final question = questionCtrl.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập câu hỏi bình chọn.')),
      );
      return;
    }

    final options = optionCtrls
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần ít nhất 2 lựa chọn có nội dung.')),
      );
      return;
    }

    onStateChange(true);
    try {
      await ref.read(creatorPollsProvider.notifier).createPoll(
            question: question,
            options: options,
            publish: publishNow,
          );
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              publishNow
                  ? 'Đã công bố cuộc bình chọn thành công!'
                  : 'Đã lưu bản nháp cuộc bình chọn!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      onStateChange(false);
    }
  }

  // --- ACTIONS: CONFIRM PUBLISH / CLOSE / DELETE ---
  void _confirmPublishPoll(BuildContext context, CreatorPoll poll) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Công bố cuộc bình chọn?'),
        content: Text('Người nghe sẽ nhìn thấy câu hỏi: "${poll.question}" và có thể tham gia bình chọn ngay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(creatorPollsProvider.notifier).publishPoll(poll.pollId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã công bố bình chọn thành công!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không thể công bố: $e')),
                  );
                }
              }
            },
            child: const Text('Công bố'),
          ),
        ],
      ),
    );
  }

  void _confirmClosePoll(BuildContext context, CreatorPoll poll) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đóng cuộc bình chọn?'),
        content: const Text('Sau khi đóng, người nghe sẽ không thể tiếp tục gửi hay thay đổi câu trả lời.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(creatorPollsProvider.notifier).closePoll(poll.pollId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã đóng cuộc bình chọn!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không thể đóng: $e')),
                  );
                }
              }
            },
            child: const Text('Đóng bình chọn'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePoll(BuildContext context, CreatorPoll poll) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa cuộc bình chọn?'),
        content: const Text('Hành động này sẽ xóa mềm cuộc bình chọn. Dữ liệu câu trả lời vẫn được lưu trữ.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(creatorPollsProvider.notifier).deletePoll(poll.pollId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showTopSnackBar(
                    const SnackBar(content: Text('Đã xóa cuộc bình chọn.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showTopSnackBar(
                    SnackBar(content: Text('Không thể xóa: $e')),
                  );
                }
              }
            },
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

  // --- SHEET: KẾT QUẢ BÌNH CHỌN (RESULTS) ---
  void _showPollResultsSheet(BuildContext context, String pollId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FutureBuilder<PollResultsData>(
          future: ref.read(creatorRepositoryProvider).getPollResults(pollId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
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
                    Text('Lỗi: ${snapshot.error}', textAlign: TextAlign.center),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    results.question,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tổng số lượt phản hồi: ${results.totalResponses}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),

                  ...results.options.map((opt) {
                    final percent = opt.percentage;
                    final ratio = percent / 100.0;
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
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(
                                '${percent.toStringAsFixed(1)}% (${opt.responseCount})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              minHeight: 10,
                              backgroundColor: AppColors.outlineLight.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondaryLight),
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

  // --- SHEET: DANH SÁCH NGƯỜI BÌNH CHỌN (RESPONSES) ---
  void _showPollResponsesSheet(BuildContext context, String pollId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<PollResponseUserItem>>(
          future: ref.read(creatorRepositoryProvider).getPollResponses(pollId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
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
                    Text('Lỗi: ${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
                  ],
                ),
              );
            }

            final responses = snapshot.data ?? [];
            final dateFormat = DateFormat('dd/MM HH:mm');

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Danh sách bình chọn (${responses.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (responses.isEmpty)
                    const Expanded(
                      child: Center(child: Text('Chưa có thính giả nào gửi câu trả lời.')),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: responses.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = responses[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                              child: Text(
                                item.displayName.isNotEmpty
                                    ? item.displayName.characters.first.toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                            title: Text(
                              item.displayName,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Đã chọn: ${item.optionText}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.secondaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: item.submittedAt != null
                                ? Text(
                                    dateFormat.format(item.submittedAt!.toLocal()),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  )
                                : null,
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
  }
}
