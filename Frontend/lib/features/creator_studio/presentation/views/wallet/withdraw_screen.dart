import 'package:flutter/material.dart';
import 'package:podcast_history/core/widgets/top_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/network/api_client.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/theme/app_typography.dart';
import 'package:podcast_history/core/utils/formatters.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/wallet/bank_accounts_screen.dart';

class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  BankAccount? _selectedBank;
  BankAccount? _completedBank;
  int _completedAmount = 0;
  bool _isProcessing = false;
  String _currentStepState = 'FORM'; // FORM -> VALIDATING -> SUCCESS
  String? _transactionId;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _processWithdrawal(int available, BankAccount? bank) async {
    final rawText = _amountController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll('₫', '')
        .trim();
    final amount = int.tryParse(rawText) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('Số tiền rút phải lớn hơn 0 ₫'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (amount > available) {
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('Số tiền rút vượt quá số dư khả dụng hiện tại'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (bank == null) {
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn tài khoản ngân hàng nhận tiền'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (!bank.verified) {
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text(
            'Tài khoản này chưa được Admin xác minh. Vui lòng chọn tài khoản đã xác minh để rút tiền.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isProcessing = true;
      _currentStepState = 'VALIDATING';
    });

    try {
      final transaction = await ref.read(walletProvider.notifier).withdrawMoney(
            amount,
            bank.id,
            '',
          );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _currentStepState = 'SUCCESS';
        _transactionId = transaction.id;
        _completedBank = bank;
        _completedAmount = amount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _currentStepState = 'FORM';
      });
      final errorMsg = e is ApiException
          ? e.message
          : e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      messenger.showTopSnackBar(
        SnackBar(
          content: Text('Không thể xác nhận yêu cầu rút tiền: $errorMsg'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _setAmount(int amount, int available) {
    final clamped = amount.clamp(0, available);
    _amountController.text = clamped.toString();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider).value;
    final accounts = ref.watch(bankAccountsProvider).value ?? [];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final available = wallet?.available ?? 0;

    final verifiedAccounts = accounts.where((a) => a.verified && a.active).toList();
    final activeSelectedBank = _selectedBank != null && accounts.any((a) => a.id == _selectedBank!.id)
        ? accounts.firstWhere((a) => a.id == _selectedBank!.id)
        : (verifiedAccounts.isNotEmpty
            ? verifiedAccounts.firstWhere((a) => a.isDefault, orElse: () => verifiedAccounts.first)
            : (accounts.isNotEmpty ? accounts.first : null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rút tiền về ngân hàng'),
      ),
      body: _currentStepState == 'SUCCESS'
          ? _buildSuccessReceipt(isDark)
          : (_isProcessing
              ? _buildProcessingStateMachine(isDark)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  children: [
                    // Số dư khả dụng
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Số dư khả dụng để rút',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppFormatters.formatVND(available),
                            style: AppTypography.tabularNumbers(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Nhập số tiền
                    AppTextField(
                      label: 'Số tiền muốn rút (VND)',
                      hint: 'Nhập số tiền muốn rút',
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Preset chips nhanh
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip('50.000 ₫', () => _setAmount(50000, available)),
                          _buildPresetChip('100.000 ₫', () => _setAmount(100000, available)),
                          _buildPresetChip('200.000 ₫', () => _setAmount(200000, available)),
                          _buildPresetChip('500.000 ₫', () => _setAmount(500000, available)),
                          _buildPresetChip('Toàn bộ số dư', () => _setAmount(available, available), isHighlight: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Chọn ngân hàng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tài khoản nhận tiền',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: const Text('Quản lý TK'),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const BankAccountsScreen()),
                            );
                            ref.read(bankAccountsProvider.notifier).loadAccounts();
                          },
                        ),
                      ],
                    ),
                    if (accounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                          borderRadius: AppSpacing.roundedMd,
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                                SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Chưa có tài khoản nhận tiền',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Bạn có thể thêm tài khoản ngân hàng. Admin sẽ đối soát trước khi cho phép rút tiền.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Thêm tài khoản'),
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const BankAccountsScreen()),
                                );
                                ref.read(bankAccountsProvider.notifier).loadAccounts();
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<BankAccount>(
                        key: ValueKey(activeSelectedBank?.id ?? 'no_bank'),
                        isExpanded: true,
                        initialValue: activeSelectedBank,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.account_balance_rounded),
                        ),
                        items: accounts.map((acc) {
                          return DropdownMenuItem<BankAccount>(
                            value: acc,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${acc.bankName} - ${acc.accountNumber}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (acc.verified)
                                  const Text(
                                    ' (Đã xác minh)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.info,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  const Text(
                                    ' (Chờ duyệt)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedBank = val;
                          });
                        },
                      ),
                    const SizedBox(height: AppSpacing.lg),

                    // Tóm tắt giao dịch
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Phí dịch vụ rút tiền', 'Miễn phí (0 ₫)'),
                          const SizedBox(height: 6),
                          _buildSummaryRow('Hình thức xử lý', 'Admin duyệt & chuyển khoản vào STK'),
                          const SizedBox(height: 6),
                          _buildSummaryRow('Thời gian xử lý', 'Sau khi Admin đối soát'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    AppButton(
                      label: 'Xác nhận rút tiền',
                      onPressed: () {
                        if (accounts.isEmpty) {
                          ScaffoldMessenger.of(context).showTopSnackBar(
                            const SnackBar(
                              content: Text(
                                'Chưa có tài khoản nhận tiền. Hãy thêm tài khoản ngân hàng trước.',
                              ),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                          return;
                        }
                        _processWithdrawal(available, activeSelectedBank);
                      },
                    ),
                  ],
                )),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: ActionChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            color: isHighlight ? AppColors.primaryLight : null,
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedLight)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildProcessingStateMachine(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Đang gửi yêu cầu và giữ số dư trong ví...',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hệ thống đang tiến hành đối soát và giữ an toàn giao dịch.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessReceipt(bool isDark) {
    return Center(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        shrinkWrap: true,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.successContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Lệnh rút tiền đã được tiếp nhận!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Mã yêu cầu: ${_transactionId ?? ''}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.tertiaryLight),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
            ),
            child: Column(
              children: [
                _buildReceiptRow(
                  'Số tiền rút',
                  AppFormatters.formatVND(_completedAmount),
                  isBold: true,
                ),
                const Divider(),
                _buildReceiptRow('Phương thức nhận', _completedBank?.bankName ?? ''),
                const SizedBox(height: 6),
                _buildReceiptRow('Số tài khoản', _completedBank?.accountNumber ?? ''),
                const SizedBox(height: 6),
                _buildReceiptRow('Chủ tài khoản', _completedBank?.accountHolder ?? ''),
                const SizedBox(height: 6),
                _buildReceiptRow('Loại tiền tệ', _completedBank?.currency ?? 'VND'),
                const SizedBox(height: 6),
                _buildReceiptRow('Thời gian tạo lệnh', AppFormatters.formatDateTime(DateTime.now())),
                const SizedBox(height: 6),
                _buildReceiptRow('Trạng thái', 'Đang chờ Admin chuyển khoản', color: AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: 'Về trang Ví Creator',
            onPressed: () {
              ref.read(walletProvider.notifier).loadWallet();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceMutedLight)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
