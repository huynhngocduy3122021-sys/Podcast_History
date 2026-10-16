import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_confirm_dialog.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
        foregroundColor: isDark ? AppColors.onPrimaryDark : AppColors.onPrimaryLight,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm tài khoản'),
        onPressed: () => _showAddAccountDialog(context, ref),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.account_balance_outlined,
              title: 'Chưa liên kết ngân hàng',
              description: 'Thêm tài khoản ngân hàng chính chủ để rút tiền thù lao từ VietCast.',
              actionLabel: 'Thêm tài khoản ngay',
              onAction: () => _showAddAccountDialog(context, ref),
            );
          }

          return ListView.separated(
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      onPressed: () {
                        AppConfirmDialog.show(
                          context,
                          title: 'Xóa tài khoản ngân hàng?',
                          content: 'Tài khoản ${acc.accountNumber} tại ${acc.bankName} sẽ bị gỡ bỏ.',
                          confirmLabel: 'Xóa',
                          isDestructive: true,
                          onConfirm: () => ref.read(bankAccountsProvider.notifier).deleteAccount(acc.id),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final bankCtrl = TextEditingController(text: 'Techcombank');
    final numCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'NGUYEN THE GIANG');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm tài khoản ngân hàng', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: 'Tên ngân hàng', controller: bankCtrl),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: 'Số tài khoản', controller: numCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: 'Chủ tài khoản (Không dấu)', controller: nameCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          AppButton(
            label: 'Lưu tài khoản',
            width: 130,
            onPressed: () {
              if (numCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
                ref.read(bankAccountsProvider.notifier).addAccount(
                      bankCtrl.text.trim(),
                      numCtrl.text.trim(),
                      nameCtrl.text.trim(),
                    );
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}
