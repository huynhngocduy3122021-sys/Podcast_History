import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/series/series_management_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/wallet/wallet_screen.dart';

class CreatorLivestreamScreen extends ConsumerStatefulWidget {
  const CreatorLivestreamScreen({super.key});

  @override
  ConsumerState<CreatorLivestreamScreen> createState() =>
      _CreatorLivestreamScreenState();
}

class _CreatorLivestreamScreenState extends ConsumerState<CreatorLivestreamScreen> {
  bool _isLive = false;
  bool _obscureKey = true;
  Timer? _timer;
  int _liveSeconds = 0;
  int _viewerCount = 0;

  final _titleController = TextEditingController(
    text: 'Giao lưu Lịch sử & Kể chuyện cùng Thính giả',
  );
  final _descController = TextEditingController(
    text: 'Cùng thảo luận về các sự kiện hào hùng, giải đáp thắc mắc và chia sẻ góc nhìn lịch sử mới mẻ.',
  );
  String _selectedTopic = 'Chiến sự & Kháng chiến';
  final String _rtmpUrl = 'rtmp://live.vietcast.vn/live';
  final String _streamKey = 'live_cc_vietcast_89a3fe27b14c';

  final List<String> _topics = [
    'Chiến sự & Kháng chiến',
    'Nhân vật & Danh nhân',
    'Triều đại & Phong kiến',
    'Văn hóa & Cổ vật',
    'Bí ẩn chưa có lời giải',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _toggleLive() {
    setState(() {
      _isLive = !_isLive;
      if (_isLive) {
        _liveSeconds = 0;
        _viewerCount = 12;
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return;
          setState(() {
            _liveSeconds++;
            if (_liveSeconds % 5 == 0) {
              _viewerCount += (_liveSeconds % 10 == 0) ? 3 : 1;
            }
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang phát trực tiếp! Thính giả đã có thể tham gia phòng Live.'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        _timer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã kết thúc Livestream. Tổng thời gian: ${_formatLiveTime(_liveSeconds)} • Lượt xem cao nhất: $_viewerCount',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  String _formatLiveTime(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    return h == '00' ? '$m:$s' : '$h:$m:$s';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label vào bộ nhớ tạm!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final wallet = ref.watch(walletProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Livestream Studio'),
        actions: [
          // Nút Series ở góc trên bên phải
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SeriesManagementScreen()),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF3ECE4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.outlineDark : const Color(0xFFDFD4C8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_collection_rounded,
                        size: 15,
                        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Series',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Nút Ví tiền ở góc trên bên phải
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF3ECE4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.outlineDark : const Color(0xFFDFD4C8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 15,
                        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        wallet != null ? '${(wallet.available / 1000).toStringAsFixed(0)}k đ' : 'Ví tiền',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          // Banner Trạng thái phòng phát
          _buildLiveStatusBanner(isDark),
          const SizedBox(height: AppSpacing.lg),

          // Thiết lập thông tin buổi phát
          _buildStreamConfigCard(isDark),
          const SizedBox(height: AppSpacing.lg),

          // Cấu hình RTMP / OBS
          _buildRtmpSetupCard(isDark),
          const SizedBox(height: AppSpacing.lg),

          // Lịch sử phát trực tiếp gần đây
          _buildPastStreamsSection(isDark),
        ],
      ),
    );
  }

  Widget _buildLiveStatusBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _isLive
            ? AppColors.error.withValues(alpha: 0.1)
            : (isDark ? AppColors.surfaceVariantDark : const Color(0xFFFAF6F0)),
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: _isLive
              ? AppColors.error.withValues(alpha: 0.4)
              : (isDark ? AppColors.outlineDark : const Color(0xFFE4DCD3)),
          width: _isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isLive ? AppColors.error : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLive)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      _isLive ? 'ĐANG TRỰC TIẾP' : 'CHƯA LÊN SÓNG',
                      style: TextStyle(
                        color: _isLive ? Colors.white : Colors.grey[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_isLive) ...[
                const Icon(Icons.remove_red_eye_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  '$_viewerCount đang xem',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error),
                ),
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.timer_outlined, size: 16),
                const SizedBox(width: 4),
                Text(
                  _formatLiveTime(_liveSeconds),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _isLive ? _titleController.text : 'Phòng phát trực tiếp chuyên đề Lịch sử',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isLive
                ? 'Đang kết nối tín hiệu RTMP máy chủ. Âm thanh và hình ảnh trực tuyến ổn định.'
                : 'Kết nối OBS Studio, Prism Live hoặc phát trực tiếp từ máy để tương tác cùng thính giả.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: _isLive ? 'Kết thúc Livestream' : 'Bắt đầu phát trực tiếp',
                  icon: Icon(
                    _isLive ? Icons.stop_circle_rounded : Icons.sensors_rounded,
                    size: 18,
                  ),
                  type: _isLive ? AppButtonType.destructive : AppButtonType.primary,
                  onPressed: _toggleLive,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text('Lên lịch'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tính năng lên lịch sự kiện phát sóng sắp ra mắt!')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreamConfigCard(bool isDark) {
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
            children: const [
              Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryLight),
              SizedBox(width: 8),
              Text(
                'Thông tin buổi phát',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Tiêu đề buổi Livestream *',
            controller: _titleController,
            hint: 'Nhập tiêu đề hấp dẫn...',
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Mô tả nội dung & Lộ trình trao đổi',
            controller: _descController,
            hint: 'Tóm tắt các chủ đề sẽ giao lưu...',
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _selectedTopic,
            decoration: const InputDecoration(
              labelText: 'Chủ đề Lịch sử',
              isDense: true,
            ),
            items: _topics
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedTopic = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRtmpSetupCard(bool isDark) {
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
            children: const [
              Icon(Icons.settings_input_antenna_rounded, size: 18, color: AppColors.secondaryLight),
              SizedBox(width: 8),
              Text(
                'Cấu hình kết nối phần mềm phát (OBS / Prism)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // URL Server
          const Text('URL Máy chủ Stream (RTMP Server):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF5F0EB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.outlineDark : const Color(0xFFE4DCD3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _rtmpUrl,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Sao chép URL',
                  onPressed: () => _copyToClipboard(_rtmpUrl, 'URL Máy chủ'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Stream Key
          const Text('Khóa luồng (Stream Key):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF5F0EB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.outlineDark : const Color(0xFFE4DCD3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _obscureKey ? '••••••••••••••••••••••••••••' : _streamKey,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16),
                  tooltip: _obscureKey ? 'Hiện' : 'Ẩn',
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Sao chép Stream Key',
                  onPressed: () => _copyToClipboard(_streamKey, 'Stream Key'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastStreamsSection(bool isDark) {
    final pastStreams = [
      {
        'title': 'Bình luận thế trận trận Như Nguyệt 1077',
        'date': 'Hôm qua, 20:00',
        'duration': '1h 15m',
        'viewers': '1.240',
        'likes': '384',
      },
      {
        'title': 'Hỏi đáp cùng thính giả: Những bí ẩn thời Lý - Trần',
        'date': '20/10/2026',
        'duration': '58m',
        'viewers': '960',
        'likes': '290',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Các buổi Livestream đã phát gần đây',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...pastStreams.map((s) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(
                  color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_rounded, color: AppColors.primaryLight, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['title']!,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s['date']} • Thời lượng: ${s['duration']} • ${s['viewers']} người xem',
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
            )),
      ],
    );
  }
}
