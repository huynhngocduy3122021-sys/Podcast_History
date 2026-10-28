import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:podcast_history/core/network/api_client.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/utils/image_url_helper.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';

class PremiumUpgradeScreen extends ConsumerStatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  ConsumerState<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends ConsumerState<PremiumUpgradeScreen> {
  bool _isSubscribing = false;

  Future<void> _handleRefresh() async {
    await Future.wait([
      ref.refresh(creatorSystemPlansProvider.future),
      ref.read(creatorSubscriptionProvider.notifier).loadSubscription(),
      ref.read(creatorProfileProvider.notifier).loadProfile(),
    ]);
  }

  Future<void> _upgradeToPlan(CreatorSystemPlan plan) async {
    setState(() => _isSubscribing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(creatorRepositoryProvider);
      CreatorCheckoutPayment checkout;
      try {
        checkout = await repo.subscribeSystemPlan(plan.planId);
      } on ApiException catch (e) {
        if (e.statusCode == 409) {
          // Xung đột: Có thanh toán gói CC cũ đang PENDING
          if (!mounted) return;
          final shouldCancelAndRetry = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Đơn thanh toán đang chờ'),
              content: const Text(
                'Bạn đang có một mã thanh toán trước đó ở trạng thái chờ.\n\n'
                'Bạn có muốn hủy đơn cũ để tạo mã QR thanh toán mới ngay không?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Để sau'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Hủy đơn cũ & Tạo mới'),
                ),
              ],
            ),
          );

          if (shouldCancelAndRetry == true) {
            await repo.cancelPendingCheckout();
            checkout = await repo.subscribeSystemPlan(plan.planId);
          } else {
            return;
          }
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      final success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CreatorPaymentDialog(
          checkout: checkout,
          planName: plan.name,
        ),
      );

      if (success == true && mounted) {
        await _handleRefresh();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Chúc mừng bạn đã nâng cấp thành công gói ${plan.name}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Không thể tạo giao dịch nâng cấp: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubscribing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(creatorProfileProvider).value;
    final plansAsync = ref.watch(creatorSystemPlansProvider);
    final subscriptionAsync = ref.watch(creatorSubscriptionProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final subscription = subscriptionAsync.value;
    final isSubActive = subscription?.isActive ?? false;
    final isPremium = (profile?.isPremium ?? false) || isSubActive;

    // Lấy gói trả phí đang mở bán
    final plans = plansAsync.value ?? [];
    final paidPlan = plans.where((p) => p.isPaid && p.isActive).firstOrNull ??
        plans.where((p) => p.isPaid).firstOrNull;

    // Giá và thời hạn từ API
    final price = paidPlan?.price ?? 199000;
    final formattedPrice = NumberFormat('#,###', 'vi_VN').format(price);
    final durationDays = paidPlan?.durationDays ?? 30;
    final durationText = durationDays == 30
        ? 'tháng'
        : durationDays == 365
            ? 'năm'
            : '$durationDays ngày';

    final planDisplayName = paidPlan?.name.isNotEmpty == true
        ? paidPlan!.name
        : 'VietCast Studio Premium';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói VietCast Studio Premium'),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            // Hero Banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.secondaryLight,
                    Color(0xFF8B6508),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppSpacing.roundedMd,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    planDisplayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    paidPlan?.description.isNotEmpty == true
                        ? paidPlan!.description
                        : 'Nâng tầm sáng tạo nội dung lịch sử với các đặc quyền chuyên biệt',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  if (isPremium) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: const Text(
                        'ĐANG KÍCH HOẠT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            const Text(
              'Quyền lợi đặc quyền',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildBenefitItem(
              Icons.all_inclusive_rounded,
              'Xuất bản không giới hạn podcast',
              'Không bị giới hạn 5 podcast như gói Miễn phí. Tự do sản xuất chuỗi bài dài tập.',
              isDark,
            ),
            _buildBenefitItem(
              Icons.poll_rounded,
              'Form Builder khảo sát thính giả',
              'Tạo biểu mẫu thu thập ý kiến, bình chọn chủ đề lịch sử tiếp theo từ người nghe.',
              isDark,
            ),
            _buildBenefitItem(
              Icons.live_tv_rounded,
              'Phòng Livestream kể chuyện trực tiếp',
              'Tương tác giọng nói và bình luận realtime cùng cộng đồng người nghe lịch sử.',
              isDark,
            ),
            _buildBenefitItem(
              Icons.verified_user_rounded,
              'Huy hiệu Premium & Ưu tiên duyệt AI',
              'Tăng độ nhận diện thương hiệu kênh và tốc độ thẩm định tư liệu lịch sử nhanh gấp 3 lần.',
              isDark,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Thông tin gói hiện tại nếu đã kích hoạt
            if (isPremium && subscription != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.secondaryLight.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars_rounded, color: AppColors.secondaryLight, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Chi tiết gói đăng ký của bạn',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildInfoRow('Tên gói:', subscription.planName ?? planDisplayName),
                    if (subscription.endAt != null)
                      _buildInfoRow(
                        'Hạn sử dụng:',
                        DateFormat('dd/MM/yyyy HH:mm').format(subscription.endAt!.toLocal()),
                      ),
                    _buildInfoRow(
                      'Lượt đăng podcast:',
                      subscription.uploadLimit == null
                          ? 'Không giới hạn'
                          : '${subscription.uploadsRemaining ?? 0} lượt còn lại (đã dùng ${subscription.uploadsUsed})',
                    ),
                    _buildInfoRow(
                      'Phòng Livestream:',
                      subscription.canLivestream ? 'Đã kích hoạt' : 'Chưa hỗ trợ',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Cảnh báo giao dịch PENDING (nếu có)
            if (subscription?.isPendingPayment == true) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bạn đang có một đơn chờ thanh toán',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Mã giao dịch: ${subscription?.lastPaymentReference ?? 'Đang chờ'}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hủy đơn chờ cũ'),
                            content: const Text(
                              'Bạn có muốn hủy đơn thanh toán đang chờ này để tạo lại mã mới?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Không'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Đồng ý hủy'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(creatorRepositoryProvider).cancelPendingCheckout();
                          await _handleRefresh();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Hủy đơn cũ', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Giá gói (nếu chưa kích hoạt)
            if (!isPremium) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.secondaryLight, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Chỉ với',
                      style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMutedLight),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$formattedPrice ₫ / $durationText',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Hủy gia hạn bất kỳ lúc nào mà không phát sinh thêm phí.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            if (!isPremium)
              AppButton(
                label: 'Nâng cấp lên Studio Premium',
                isLoading: _isSubscribing,
                onPressed: paidPlan != null ? () => _upgradeToPlan(paidPlan) : null,
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: AppSpacing.roundedMd,
                ),
                child: const Center(
                  child: Text(
                    '✓ Kênh của bạn đã sở hữu mọi đặc quyền Studio Premium',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondaryLight.withValues(alpha: 0.15),
              borderRadius: AppSpacing.roundedSm,
            ),
            child: Icon(icon, size: 20, color: AppColors.secondaryLight),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog thanh toán SePay cho Creator System Plan
class CreatorPaymentDialog extends ConsumerStatefulWidget {
  final CreatorCheckoutPayment checkout;
  final String planName;

  const CreatorPaymentDialog({
    super.key,
    required this.checkout,
    required this.planName,
  });

  @override
  ConsumerState<CreatorPaymentDialog> createState() => _CreatorPaymentDialogState();
}

class _CreatorPaymentDialogState extends ConsumerState<CreatorPaymentDialog> {
  Timer? _pollTimer;
  late CreatorCheckoutPayment _checkout;
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkout = widget.checkout;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkPayment();
    });
  }

  Future<void> _checkPayment() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final repo = ref.read(creatorRepositoryProvider);
      final latest = await repo.getCheckoutStatus(_checkout.checkoutId);
      if (!mounted) return;
      setState(() {
        _checkout = latest;
        _error = null;
      });
      if (_checkout.isPaid) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
      } else if (_checkout.isExpired) {
        _pollTimer?.cancel();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa kiểm tra được trạng thái thanh toán.');
      }
    } finally {
      if (mounted) {
        _checking = false;
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl = _checkout.qrImageUrl;
    final paymentCode = _checkout.paymentCode;
    final formattedAmount = NumberFormat('#,###', 'vi_VN').format(_checkout.amount);
    final isTerminal = _checkout.isExpired;
    final titleText = _checkout.isPaid
        ? 'Thanh toán thành công'
        : _checkout.isExpired
            ? 'Giao dịch đã hết hạn'
            : 'Thanh toán';

    return AlertDialog(
      title: Text(titleText),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.planName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (qrUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Image.network(
                resolveImageUrl(qrUrl),
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.qr_code_2, size: 160),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppSpacing.roundedSm,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Số tiền:', style: TextStyle(fontSize: 13)),
                      Text(
                        '$formattedAmount ${_checkout.currency}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Nội dung CK:', style: TextStyle(fontSize: 13)),
                      Row(
                        children: [
                          SelectableText(
                            paymentCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Sao chép mã',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: paymentCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép mã thanh toán!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!isTerminal) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Quét mã QR và chờ xác nhận. Hệ thống tự kiểm tra mỗi 3 giây.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Phiên thanh toán đã hết hạn. Vui lòng tạo giao dịch mới.',
                style: TextStyle(fontSize: 12, color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(isTerminal ? 'Đóng' : 'Để sau'),
        ),
        if (!isTerminal)
          FilledButton(
            onPressed: _checking ? null : _checkPayment,
            child: const Text('Kiểm tra ngay'),
          ),
      ],
    );
  }
}
