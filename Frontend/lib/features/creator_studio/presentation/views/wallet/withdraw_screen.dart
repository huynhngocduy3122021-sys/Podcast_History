import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final TextEditingController _pinController = TextEditingController();
  BankAccount? _selectedBank;
  bool _isProcessing = false;
  String _currentStepState = 'FORM'; // FORM -> VALIDATING -> PROCESSING -> SUCCESS
  String? _transactionId;

  @override
  void dispose() {
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _processWithdrawal(int available) async {
    final amount = int.tryParse(_amountController.text.replaceAll('.', '').replaceAll(' ', '')) ?? 0;
    if (amount < 50000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền rút tối thiểu là 50.000 ₫')),
      );
      return;
    }
    if (amount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền rút vượt quá số dư khả dụng')),
      );
      return;
    }
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn tài khoản ngân hàng nhận tiền')),
      );
      return;
    }
    if (_pinController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã PIN bảo mật 6 số')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isProcessing = true;
      _currentStepState = 'VALIDATING';
    });

    // Mô phỏng State Machine: VALIDATING -> HOLDING -> PROCESSING -> SUCCESS
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _currentStepState = 'HOLDING');

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _currentStepState = 'PROCESSING');

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    try {
      await ref.read(walletProvider.notifier).withdrawMoney(
            amount,
            _selectedBank!.id,
            _pinController.text,
          );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _currentStepState = 'SUCCESS';
        _transactionId = 'VC-WD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _currentStepState = 'FORM';
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Rút tiền thất bại: $e. Số tiền đã được hoàn lại ví.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider).value;
    final accounts = ref.watch(bankAccountsProvider).value ?? [];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_selectedBank == null && accounts.isNotEmpty) {
      _selectedBank = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
    }

    final available = wallet?.available ?? 0;

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
                      hint: 'Tối thiểu 50.000 ₫',
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _amountController.text = available.toString();
                          },
                          child: const Text('Rút toàn bộ số dư'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Chọn ngân hàng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tài khoản nhận tiền', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const BankAccountsScreen()),
                            );
                          },
                          child: const Text('Quản lý TK'),
                        ),
                      ],
                    ),
                    if (accounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.warningContainer,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Text('Chưa có tài khoản ngân hàng. Vui lòng bấm Quản lý TK để thêm.'),
                      )
                    else
                      DropdownButtonFormField<BankAccount>(
                        initialValue: _selectedBank,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.account_balance_rounded),
                        ),
                        items: accounts.map((acc) {
                          return DropdownMenuItem<BankAccount>(
                            value: acc,
                            child: Text('${acc.bankName} - ${acc.accountNumber}', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedBank = val),
                      ),
                    const SizedBox(height: AppSpacing.lg),

                    // Xác thực PIN bảo mật
                    AppTextField(
                      label: 'Mã PIN bảo mật rút tiền (6 chữ số)',
                      hint: 'Nhập mã PIN...',
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      prefixIcon: const Icon(Icons.pin_rounded),
                    ),
                    const SizedBox(height: AppSpacing.xl),

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
                          _buildSummaryRow('Thời gian xử lý dự kiến', '24h làm việc (24/7)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    AppButton(
                      label: 'Xác nhận rút tiền',
                      onPressed: () => _processWithdrawal(available),
                    ),
                  ],
                )),
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
            Text(
              _getProcessingStatusTitle(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hệ thống đang tiến hành đối soát và tạm giữ giao dịch theo State Machine an toàn.',
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

  String _getProcessingStatusTitle() {
    switch (_currentStepState) {
      case 'VALIDATING':
        return '1/3: Đang xác thực số dư và tài khoản ngân hàng...';
      case 'HOLDING':
        return '2/3: Đang tạm giữ tiền trong quỹ thanh khoản...';
      case 'PROCESSING':
        return '3/3: Đang gửi lệnh chuyển khoản Napas 247...';
      default:
        return 'Đang xử lý giao dịch...';
    }
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
            'Mã giao dịch: $_transactionId',
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
                _buildReceiptRow('Số tiền rút', '${_amountController.text} ₫', isBold: true),
                const Divider(),
                _buildReceiptRow('Ngân hàng nhận', _selectedBank?.bankName ?? ''),
                const SizedBox(height: 6),
                _buildReceiptRow('Số tài khoản', _selectedBank?.accountNumber ?? ''),
                const SizedBox(height: 6),
                _buildReceiptRow('Chủ tài khoản', _selectedBank?.accountHolder ?? ''),
                const SizedBox(height: 6),
                _buildReceiptRow('Thời gian tạo lệnh', AppFormatters.formatDateTime(DateTime.now())),
                const SizedBox(height: 6),
                _buildReceiptRow('Trạng thái', 'Đang giải ngân', color: AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: 'Về trang Ví Creator',
            onPressed: () => Navigator.of(context).pop(),
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
