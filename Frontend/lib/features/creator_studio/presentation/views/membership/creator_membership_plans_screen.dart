import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/wallet/wallet_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/creator_notification_button.dart';

class CreatorMembershipPlansScreen extends ConsumerStatefulWidget {
  const CreatorMembershipPlansScreen({super.key});

  @override
  ConsumerState<CreatorMembershipPlansScreen> createState() =>
      _CreatorMembershipPlansScreenState();
}

class _CreatorMembershipPlansScreenState
    extends ConsumerState<CreatorMembershipPlansScreen> {
  bool _isActionLoading = false;

  Future<void> _handleSelectTemplate(CreatorPlanTemplate template) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isActionLoading = true);
    try {
      await ref
          .read(creatorChannelPlansProvider.notifier)
          .selectTemplate(template.code);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Đã kích hoạt Gói thành viên cho kênh!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Không thể kích hoạt gói: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showEditPriceDialog(CreatorChannelPlan plan) {
    final controller = TextEditingController(text: plan.price.toInt().toString());
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Đặt giá cho Gói thành viên'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bạn có thể tùy chỉnh giá bán riêng cho kênh của mình. Giá tối thiểu là 1.000 VNĐ.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Giá gói (VNĐ)',
                      suffixText: 'VNĐ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Chọn nhanh:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [25000, 50000, 75000, 100000].map((val) {
                      return ActionChip(
                        label: Text(AppFormatters.formatVND(val)),
                        onPressed: () {
                          controller.text = val.toString();
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final price = double.tryParse(controller.text.trim()) ?? 0.0;
                    if (price < 1000) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Giá gói tối thiểu là 1.000 VNĐ.')),
                      );
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(dialogCtx).pop();
                    setState(() => _isActionLoading = true);
                    try {
                      await ref
                          .read(creatorChannelPlansProvider.notifier)
                          .updatePrice(plan.planId, price);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text('Đã cập nhật giá Gói thành viên thành ${AppFormatters.formatVND(price.toInt())}!'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.error,
                          content: Text('Cập nhật giá thất bại: $e'),
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isActionLoading = false);
                    }
                  },
                  child: const Text('Lưu thay đổi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final myPlansAsync = ref.watch(creatorChannelPlansProvider);
    final templatesAsync = ref.watch(creatorPlanTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói Hội viên Kênh'),
        actions: const [
          CreatorNotificationButton(),
          SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(creatorChannelPlansProvider.notifier).loadPlans();
              ref.invalidate(creatorPlanTemplatesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                // Banner giới thiệu
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF382319), const Color(0xFF1E1714)]
                          : [const Color(0xFFFFF2E6), const Color(0xFFFDE1CF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF754530) : const Color(0xFFF3BF9B),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.loyalty_rounded,
                          color: AppColors.primaryLight,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hội viên Kênh (Channel Membership)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mở bán các gói hội viên để người nghe đăng ký theo tháng. Hội viên được nghe podcast độc quyền (Members-Only) và gửi yêu cầu nội dung.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Gói thành viên kênh

                templatesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('Lỗi tải gói mẫu: $error'),
                    ),
                  ),
                  data: (templates) {
                    final myPlans = myPlansAsync.value ?? [];
                    final activePlan = myPlans.cast<CreatorChannelPlan?>().firstWhere(
                      (p) => p?.isActive == true,
                      orElse: () => null,
                    );

                    final defaultTemplate = templates.isNotEmpty ? templates.first : null;
                    final isCurrentlyActive = activePlan != null;
                    final displayPrice = isCurrentlyActive
                        ? activePlan.price
                        : (defaultTemplate?.suggestedPrice ?? 50000.0);
                    final durationDays = isCurrentlyActive
                        ? activePlan.durationDays
                        : (defaultTemplate?.durationDays ?? 30);
                    final benefit = (defaultTemplate != null && defaultTemplate.benefit.isNotEmpty)
                        ? defaultTemplate.benefit
                        : 'Member được xem video private của kênh.';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF211F1D) : const Color(0xFFF9F7F3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrentlyActive
                              ? (isDark ? const Color(0xFF4C3626) : const Color(0xFFEAD8C7))
                              : (isDark ? const Color(0xFF332F2B) : const Color(0xFFEDC9AF)),
                          width: isCurrentlyActive ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                color: isCurrentlyActive
                                    ? AppColors.primaryLight
                                    : AppColors.secondaryLight,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Gói thành viên',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isCurrentlyActive
                                        ? AppColors.primaryLight
                                        : null,
                                  ),
                                ),
                              ),
                              Text(
                                '${AppFormatters.formatVND(displayPrice.toInt())} / $durationDays ngày',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isCurrentlyActive
                                      ? AppColors.primaryLight
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    benefit,
                                    style: const TextStyle(fontSize: 12, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isCurrentlyActive) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: AppColors.success,
                                    ),
                                    label: const Text('Gói đang mở bán (ACTIVE)'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _showEditPriceDialog(activePlan),
                                  icon: const Icon(Icons.edit_outlined, size: 15),
                                  label: const Text('Đổi giá'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryLight,
                                    side: const BorderSide(color: AppColors.primaryLight),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (_isActionLoading || defaultTemplate == null)
                                    ? null
                                    : () => _handleSelectTemplate(defaultTemplate),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Chọn kích hoạt gói này'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Card điều hướng sang ví
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF2ECE4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Kiểm tra doanh thu & số dư hội viên trong Ví Creator',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (_isActionLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
