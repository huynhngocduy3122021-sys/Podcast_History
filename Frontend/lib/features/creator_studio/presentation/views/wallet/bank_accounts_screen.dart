import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/empty_state_widget.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';

class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(bankAccountsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản nhận tiền'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(bankAccountsProvider.notifier).loadAccounts(),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lỗi: $e'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
                onPressed: () => ref.read(bankAccountsProvider.notifier).loadAccounts(),
              ),
            ],
          ),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(bankAccountsProvider.notifier).loadAccounts(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  const SizedBox(height: 40),
                  EmptyStateWidget(
                    icon: Icons.account_balance_outlined,
                    title: 'Chưa liên kết ngân hàng',
                    description: 'Tài khoản nhận tiền được Admin đối soát và cấp để đảm bảo an toàn giải ngân.',
                    actionLabel: 'Tải lại danh sách',
                    onAction: () => ref.read(bankAccountsProvider.notifier).loadAccounts(),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(bankAccountsProvider.notifier).loadAccounts(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final acc = accounts[index];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: AppSpacing.roundedMd,
                    border: Border.all(
                      color: acc.isDefault
                          ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                          : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
                      width: acc.isDefault ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.infoContainer,
                          borderRadius: AppSpacing.roundedSm,
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: AppColors.info, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  acc.bankName,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                if (acc.isDefault) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.successContainer,
                                      borderRadius: AppSpacing.roundedPill,
                                    ),
                                    child: const Text('Mặc định', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                                if (acc.verified) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.infoContainer,
                                      borderRadius: AppSpacing.roundedPill,
                                    ),
                                    child: const Text('Đã xác minh', style: TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              acc.accountNumber,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              acc.accountHolder,
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
