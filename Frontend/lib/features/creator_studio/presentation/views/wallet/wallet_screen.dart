import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/theme/app_typography.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/error_state_widget.dart';
import 'package:podcast_history/core/widgets/status_chip.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
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
            tooltip: 'Tài khoản ngân hàng',
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
              : wallet.transactions.where((t) => t.type == _selectedFilterType).toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(walletProvider.notifier).loadWallet(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                // Thẻ số dư chính
                _buildMainBalanceCard(context, wallet, isDark),
                const SizedBox(height: AppSpacing.md),

                // Lưới phụ: Chờ release & Đang giữ
                Row(
                  children: [
                    Expanded(
                      child: _buildSubBalanceCard(
                        'Đang chờ release',
                        wallet.pending,
                        Icons.hourglass_top_rounded,
                        AppColors.warning,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildSubBalanceCard(
                        'Đang giữ (Rút tiền)',
                        wallet.holding,
                        Icons.lock_clock_rounded,
                        AppColors.info,
                        isDark,
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
                            MaterialPageRoute(builder: (_) => const WithdrawScreen()),
                          );
                        },
                      ),
                    ),
                    if (wallet.pending > 0) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: 'Release tiền chờ',
                          type: AppButtonType.secondary,
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await ref.read(walletProvider.notifier).releaseFunds();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Đã giải phóng tiền chờ vào số dư khả dụng thành công!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Lịch sử giao dịch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lịch sử giao dịch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Tổng đã rút: ${AppFormatters.formatVND(wallet.totalWithdrawn)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedLight),
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
                      _buildFilterChip('Đơn đặt podcast', TransactionType.requestEarning),
                      _buildFilterChip('Hội viên kênh', TransactionType.membership),
                      _buildFilterChip('Rút tiền', TransactionType.withdrawal),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Danh sách giao dịch
                if (txs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    alignment: Alignment.center,
                    child: const Text('Chưa có giao dịch nào trong mục này.', style: TextStyle(color: AppColors.onSurfaceMutedLight)),
                  )
                else
                  ...txs.map((tx) => _buildTransactionItem(tx, isDark)),
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

  Widget _buildMainBalanceCard(BuildContext context, WalletState wallet, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              Text(
                'SỐ DƯ KHẢ DỤNG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                ),
              ),
              const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryLight, size: 22),
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
              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubBalanceCard(String title, int amount, IconData icon, Color color, bool isDark) {
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
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                    fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransaction tx, bool isDark) {
    final isIncome = tx.amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isIncome ? AppColors.successContainer : AppColors.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isIncome ? AppColors.success : AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatters.formatDate(tx.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : ''}${AppFormatters.formatVND(tx.amount)}',
                style: AppTypography.tabularNumbers(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isIncome ? AppColors.success : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                ),
              ),
              const SizedBox(height: 2),
              StatusChip(
                label: tx.statusDisplay,
                type: tx.statusType,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
