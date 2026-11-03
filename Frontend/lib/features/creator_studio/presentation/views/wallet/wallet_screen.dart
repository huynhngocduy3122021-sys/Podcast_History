import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/theme/app_typography.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/core/widgets/status_chip.dart';
import 'package:podcast_history/core/widgets/top_notification.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/wallet/bank_accounts_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/wallet/withdraw_screen.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  TransactionType? _selectedFilterType;

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví & Thu nhập Creator'),
        actions: [
          IconButton(
            tooltip: 'Tài khoản nhận tiền',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BankAccountsScreen()),
              );
            },
          ),
        ],
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          onRetry: () => ref.read(walletProvider.notifier).loadWallet(),
        ),
        data: (wallet) {
          final txs = _selectedFilterType == null
              ? wallet.transactions
              : wallet.transactions
                  .where((t) => t.type == _selectedFilterType)
                  .toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(walletProvider.notifier).loadWallet(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                // Thẻ số dư chính (Available Balance)
                _buildMainBalanceCard(context, wallet, isDark),
                const SizedBox(height: AppSpacing.md),

                // Lưới phụ: Chờ giải ngân & Đang tạm giữ
                Row(
                  children: [
                    Expanded(
                      child: _buildSubBalanceCard(
                        'Chờ giải ngân',
                        wallet.pending,
                        Icons.hourglass_top_rounded,
                        AppColors.warning,
                        isDark,
                        subtitle: 'Từ các đợt đã duyệt',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildSubBalanceCard(
                        'Đang tạm giữ',
                        wallet.holding,
                        Icons.lock_clock_rounded,
                        AppColors.info,
                        isDark,
                        subtitle: 'Lệnh rút đang xử lý',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Nút hành động chính
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Rút tiền ngay',
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WithdrawScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    if (wallet.pending > 0) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: 'Giải ngân tiền chờ',
                          type: AppButtonType.secondary,
                          icon: const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await ref
                                  .read(walletProvider.notifier)
                                  .releaseFunds();
                              messenger.showTopSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Đã giải phóng tiền chờ vào số dư khả dụng thành công!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              messenger.showTopSnackBar(
                                SnackBar(
                                  content: Text('Không thể giải ngân: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Tiêu đề Lịch sử giao dịch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lịch sử giao dịch',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Tổng đã rút: ${AppFormatters.formatVND(wallet.totalWithdrawn)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.onSurfaceMutedLight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Chip bộ lọc giao dịch
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả', null),
                      _buildFilterChip(
                          'Thù lao hợp đồng', TransactionType.requestEarning),
                      _buildFilterChip(
                          'Rút tiền', TransactionType.withdrawal),
                      _buildFilterChip(
                          'Hội viên kênh', TransactionType.membership),
                      _buildFilterChip('Hoàn tiền', TransactionType.refund),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Danh sách giao dịch
                if (txs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    alignment: Alignment.center,
                    child: const Text(
                      'Chưa có giao dịch nào trong mục này.',
                      style: TextStyle(color: AppColors.onSurfaceMutedLight),
                    ),
                  )
                else
                  ...txs.map((tx) => _buildTransactionItem(context, tx, isDark)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, TransactionType? type) {
    final isSelected = _selectedFilterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() => _selectedFilterType = val ? type : null);
        },
      ),
    );
  }

  Widget _buildMainBalanceCard(
      BuildContext context, WalletState wallet, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
            color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SỐ DƯ KHẢ DỤNG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark
                      ? AppColors.onSurfaceMutedDark
                      : AppColors.onSurfaceMutedLight,
                ),
              ),
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.primaryLight, size: 22),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppFormatters.formatVND(wallet.available),
            style: AppTypography.tabularNumbers(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Có thể rút về tài khoản ngân hàng ngay lập tức.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.onSurfaceMutedDark
                  : AppColors.onSurfaceMutedLight,
            ),
          ),
          if (wallet.holding > 0) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng số dư ví (bao gồm tạm giữ):',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.onSurfaceMutedDark
                        : AppColors.onSurfaceMutedLight,
                  ),
                ),
                Text(
                  AppFormatters.formatVND(wallet.total),
                  style: AppTypography.tabularNumbers(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.onSurfaceDark
                        : AppColors.onSurfaceLight,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubBalanceCard(
    String title,
    int amount,
    IconData icon,
    Color color,
    bool isDark, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
            color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.onSurfaceMutedDark
                        : AppColors.onSurfaceMutedLight,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppFormatters.formatVND(amount),
            style: AppTypography.tabularNumbers(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.onSurfaceMutedDark
                    : AppColors.onSurfaceMutedLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
      BuildContext context, WalletTransaction tx, bool isDark) {
    final isIncome = tx.isCredit;

    return InkWell(
      onTap: () => _showTransactionDetails(context, tx, isDark),
      borderRadius: AppSpacing.roundedMd,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: AppSpacing.roundedMd,
          border: Border.all(
              color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isIncome
                    ? AppColors.successContainer
                    : AppColors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: isIncome ? AppColors.success : AppColors.error,
                size: 18,
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
                          tx.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (tx.isContractRelated) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.infoContainer,
                            borderRadius: AppSpacing.roundedPill,
                          ),
                          child: const Text(
                            'Hợp đồng',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (tx.requestTitle != null && tx.requestTitle!.isNotEmpty) ...[
                    Text(
                      '${tx.requestTitle}${tx.milestoneName != null ? ' • ${tx.milestoneName!}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.primaryDark
                            : AppColors.primaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                  ],
                  if (tx.subtitle != null && tx.subtitle!.isNotEmpty) ...[
                    Text(
                      tx.subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.onSurfaceMutedDark
                            : AppColors.onSurfaceMutedLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                  ],
                  Text(
                    AppFormatters.formatDateTime(tx.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.onSurfaceMutedDark
                          : AppColors.onSurfaceMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : ''}${AppFormatters.formatVND(tx.amount)}',
                  style: AppTypography.tabularNumbers(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isIncome
                        ? AppColors.success
                        : (isDark
                            ? AppColors.onSurfaceDark
                            : AppColors.onSurfaceLight),
                  ),
                ),
                const SizedBox(height: 2),
                StatusChip(
                  label: tx.statusDisplay,
                  type: tx.statusType,
                ),
                if (tx.balanceAfter != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Sau GD: ${AppFormatters.formatVND(tx.balanceAfter!)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.onSurfaceMutedDark
                          : AppColors.onSurfaceMutedLight,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(
      BuildContext context, WalletTransaction tx, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isIncome = tx.isCredit;
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.screenMargin,
            right: AppSpacing.screenMargin,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isIncome
                          ? AppColors.successContainer
                          : AppColors.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncome
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: isIncome ? AppColors.success : AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${isIncome ? '+' : ''}${AppFormatters.formatVND(tx.amount)}',
                          style: AppTypography.tabularNumbers(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isIncome
                                ? AppColors.success
                                : (isDark
                                    ? AppColors.onSurfaceDark
                                    : AppColors.onSurfaceLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: tx.statusDisplay,
                    type: tx.statusType,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              _buildDetailRow('Mã giao dịch', tx.id, isDark, isSelectable: true),
              if (tx.rawType != null)
                _buildDetailRow('Loại giao dịch', tx.rawType!, isDark),
              _buildDetailRow(
                'Dòng tiền',
                tx.isCredit ? 'Cộng tiền vào ví (+)' : 'Trừ tiền khỏi ví (-)',
                isDark,
              ),
              if (tx.referenceCode != null && tx.referenceCode!.isNotEmpty)
                _buildDetailRow(
                  'Mã tham chiếu',
                  tx.referenceCode!,
                  isDark,
                  subtitle: tx.referenceCode!.startsWith('CONTRACT_CREATOR:')
                      ? 'Đợt nghiệm thu hợp đồng Escrow'
                      : null,
                  isSelectable: true,
                ),
              if (tx.requestTitle != null && tx.requestTitle!.isNotEmpty)
                _buildDetailRow('Yêu cầu hợp đồng', tx.requestTitle!, isDark),
              if (tx.milestoneName != null && tx.milestoneName!.isNotEmpty)
                _buildDetailRow('Đợt nghiệm thu', tx.milestoneName!, isDark),
              if (tx.membershipPlanName != null && tx.membershipPlanName!.isNotEmpty)
                _buildDetailRow('Gói hội viên', tx.membershipPlanName!, isDark),
              if (tx.payoutAccountMasked != null && tx.payoutAccountMasked!.isNotEmpty)
                _buildDetailRow('Tài khoản nhận', tx.payoutAccountMasked!, isDark),
              if (tx.movement != null && tx.movement!.isNotEmpty)
                _buildDetailRow('Luồng biến động', tx.movement!, isDark),
              if (tx.availableBalanceChange != null)
                _buildDetailRow(
                  'Biến động khả dụng',
                  '${tx.availableBalanceChange! > 0 ? '+' : ''}${AppFormatters.formatVND(tx.availableBalanceChange!)}',
                  isDark,
                ),
              if (tx.heldBalanceChange != null && tx.heldBalanceChange != 0)
                _buildDetailRow(
                  'Biến động tạm giữ',
                  '${tx.heldBalanceChange! > 0 ? '+' : ''}${AppFormatters.formatVND(tx.heldBalanceChange!)}',
                  isDark,
                ),
              if (tx.balanceAfter != null)
                _buildDetailRow(
                  'Số dư sau GD',
                  AppFormatters.formatVND(tx.balanceAfter!),
                  isDark,
                ),
              if (tx.heldBalanceAfter != null && tx.heldBalanceAfter! > 0)
                _buildDetailRow(
                  'Số dư tạm giữ sau GD',
                  AppFormatters.formatVND(tx.heldBalanceAfter!),
                  isDark,
                ),
              _buildDetailRow(
                'Thời gian ghi nhận',
                AppFormatters.formatDateTime(tx.createdAt),
                isDark,
              ),
              if (tx.note != null && tx.note!.isNotEmpty)
                _buildDetailRow('Ghi chú', tx.note!, isDark),

              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Đóng',
                  type: AppButtonType.secondary,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    String? subtitle,
    bool isSelectable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.onSurfaceMutedDark
                    : AppColors.onSurfaceMutedLight,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isSelectable)
                  SelectableText(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  )
                else
                  Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}