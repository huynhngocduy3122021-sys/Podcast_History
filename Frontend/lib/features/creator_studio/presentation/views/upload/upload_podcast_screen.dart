import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/core/widgets/soundcloud_waveform.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';

class UploadPodcastScreen extends ConsumerStatefulWidget {
  final CreatorPodcast? editingPodcast;

  const UploadPodcastScreen({super.key, this.editingPodcast});

  @override
  ConsumerState<UploadPodcastScreen> createState() => _UploadPodcastScreenState();
}

class _UploadPodcastScreenState extends ConsumerState<UploadPodcastScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Form Fields
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _sourcesController;
  String _selectedEra = '1945–1954';
  bool _isExclusive = false;
  String _selectedCoverUrl = 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=400&q=80';
  bool _isVideo = false;
  String? _audioFileName;
  bool _isUploadingAudio = false;
  double _uploadProgress = 0.0;
  String? _videoFileName;
  bool _isUploadingVideo = false;
  double _videoUploadProgress = 0.0;
  bool _isSubmitting = false;

  final List<String> _eras = [
    '1858–1945',
    '1945–1954',
    '1954–1975',
    '1975–1986',
    '1986–nay',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.editingPodcast;
    _titleController = TextEditingController(text: edit?.title ?? '');
    _descController = TextEditingController(text: edit?.description ?? '');
    _sourcesController = TextEditingController(text: edit?.sources ?? '');
    if (edit != null) {
      _selectedEra = edit.eraTag;
      _isExclusive = edit.isExclusive;
      _selectedCoverUrl = edit.coverUrl;
      _audioFileName = edit.audioFileName ?? 'audio_sample.mp3';
      _uploadProgress = 1.0;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _sourcesController.dispose();
    super.dispose();
  }

  Future<void> _mockUploadAudio() async {
    setState(() {
      _isUploadingAudio = true;
      _uploadProgress = 0.0;
    });

    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() {
        _uploadProgress = i / 10.0;
      });
    }

    setState(() {
      _isUploadingAudio = false;
      _audioFileName = 'vietcast_tap_moi_320kbps.mp3';
    });
  }

  Future<void> _mockUploadVideo() async {
    setState(() {
      _isUploadingVideo = true;
      _videoUploadProgress = 0.0;
    });

    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() {
        _videoUploadProgress = i / 10.0;
      });
    }

    setState(() {
      _isUploadingVideo = false;
      _videoFileName = 'vietcast_podcast_video_1080p.mp4';
      _audioFileName = 'vietcast_podcast_video_1080p.mp4';
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hasMedia = _isVideo ? (_videoFileName != null) : (_audioFileName != null);
    if (!hasMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isVideo
              ? 'Vui lòng tải lên tệp video (Video MP4/MOV)'
              : 'Vui lòng tải lên tệp âm thanh (Audio)'),
        ),
      );
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(creatorPodcastsProvider.notifier).createPodcast(
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            eraTag: _selectedEra,
            sources: _sourcesController.text.trim(),
            isExclusive: _isExclusive,
            coverUrl: _selectedCoverUrl,
            audioFileName: _audioFileName,
            duration: const Duration(minutes: 25, seconds: 30),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Podcast đã được gửi lên hệ thống và chuyển vào hàng đợi kiểm duyệt AI!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = ref.watch(creatorProfileProvider).value;

    final isLimitReached = (profile != null && !profile.isPremium && profile.currentPodcastCount >= profile.maxFreePodcasts);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingPodcast != null ? 'Sửa Podcast' : 'Đăng Podcast mới'),
      ),
      body: isLimitReached && widget.editingPodcast == null
          ? _buildLimitReachedView(isDark)
          : Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 2) {
                    setState(() => _currentStep++);
                  } else {
                    _handleSubmit();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep--);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: _currentStep == 2 ? 'Gửi duyệt & Đăng' : 'Tiếp tục',
                            isLoading: _isSubmitting,
                            onPressed: details.onStepContinue,
                          ),
                        ),
                        if (_currentStep > 0) ...[
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppButton(
                              label: 'Quay lại',
                              type: AppButtonType.secondary,
                              onPressed: details.onStepCancel,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Tệp âm thanh & Ảnh bìa'),
                    isActive: _currentStep >= 0,
                    state: _audioFileName != null ? StepState.complete : StepState.indexed,
                    content: _buildStep1(isDark),
                  ),
                  Step(
                    title: const Text('Thông tin nội dung'),
                    isActive: _currentStep >= 1,
                    state: _titleController.text.isNotEmpty ? StepState.complete : StepState.indexed,
                    content: _buildStep2(isDark),
                  ),
                  Step(
                    title: const Text('Tư liệu & Chế độ phát'),
                    isActive: _currentStep >= 2,
                    state: _sourcesController.text.isNotEmpty ? StepState.complete : StepState.indexed,
                    content: _buildStep3(isDark),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLimitReachedView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock_rounded, size: 64, color: AppColors.secondaryLight),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Đã đạt giới hạn gói Miễn phí (5/5 podcast)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Gói Free cho phép xuất bản tối đa 5 podcast. Hãy nâng cấp lên Studio Premium để đăng không giới hạn và mở khóa tính năng Form khảo sát!',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Nâng cấp Premium ngay',
              onPressed: () {
                ref.read(creatorProfileProvider.notifier).upgradeToPremium();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chúc mừng bạn đã nâng cấp thành công gói Studio Premium!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chọn loại định dạng (Audio hoặc Video)
        const Text('Loại định dạng Podcast', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Audio Podcast'),
                  ],
                ),
                selected: !_isVideo,
                onSelected: (val) {
                  if (val) setState(() => _isVideo = false);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ChoiceChip(
                label: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_camera_back_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Video Podcast'),
                  ],
                ),
                selected: _isVideo,
                onSelected: (val) {
                  if (val) setState(() => _isVideo = true);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Khung Upload Media (Audio hoặc Video)
        if (!_isVideo)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(
                color: _audioFileName != null ? AppColors.success : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
                width: _audioFileName != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _audioFileName != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                  size: 48,
                  color: _audioFileName != null ? AppColors.success : AppColors.primaryLight,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _audioFileName ?? 'Chọn tệp âm thanh (mp3, m4a, wav)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Dung lượng tối đa: 150MB. Khuyến nghị chất lượng 320kbps.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
                if (_isUploadingAudio) ...[
                  const SizedBox(height: AppSpacing.md),
                  LinearProgressIndicator(value: _uploadProgress, color: AppColors.primaryLight),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Đang tải lên ${(_uploadProgress * 100).toInt()}%...',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
                if (_audioFileName != null && !_isUploadingAudio) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                      borderRadius: AppSpacing.roundedSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.graphic_eq_rounded, size: 16, color: AppColors.primaryLight),
                            SizedBox(width: 6),
                            Text(
                              'SoundCloud Waveform Preview: Đã phân tích dải tần',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const SoundCloudWaveform(
                          progress: 0.35,
                          height: 44,
                          showComments: false,
                          isInteractive: true,
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('00:00', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceMutedLight)),
                            Text('25:30 (Độ nét cao 320kbps)', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceMutedLight)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: _audioFileName != null ? 'Thay đổi tệp audio' : 'Tải lên Audio',
                  height: 38,
                  width: 180,
                  type: _audioFileName != null ? AppButtonType.secondary : AppButtonType.primary,
                  onPressed: _mockUploadAudio,
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(
                color: _videoFileName != null ? AppColors.success : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
                width: _videoFileName != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _videoFileName != null ? Icons.check_circle_rounded : Icons.video_call_outlined,
                  size: 48,
                  color: _videoFileName != null ? AppColors.success : AppColors.secondaryLight,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _videoFileName ?? 'Chọn tệp video podcast (mp4, mov, mkv)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Lưu trữ Cloudflare R2 riêng tư. Hỗ trợ độ phân giải tối đa 4K, 500MB.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isUploadingVideo) ...[
                  const SizedBox(height: AppSpacing.md),
                  LinearProgressIndicator(value: _videoUploadProgress, color: AppColors.secondaryLight),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Đang tải lên video ${(_videoUploadProgress * 100).toInt()}%...',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
                if (_videoFileName != null && !_isUploadingVideo) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: AppSpacing.roundedSm,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.play_circle_filled_rounded, size: 48, color: Colors.white70),
                        Positioned(
                          bottom: 8,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('1080p HD • Video Podcast R2', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: _videoFileName != null ? 'Thay đổi tệp video' : 'Tải lên Video',
                  height: 38,
                  width: 180,
                  type: _videoFileName != null ? AppButtonType.secondary : AppButtonType.primary,
                  onPressed: _mockUploadVideo,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),

        // Chọn ảnh bìa
        const Text('Ảnh bìa tập podcast (Tỉ lệ 1:1)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            ClipRRect(
              borderRadius: AppSpacing.roundedMd,
              child: Image.network(_selectedCoverUrl, width: 80, height: 80, fit: BoxFit.cover),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Chọn ảnh bìa từ thư viện',
                height: 38,
                type: AppButtonType.secondary,
                onPressed: () {
                  setState(() {
                    _selectedCoverUrl = 'https://images.unsplash.com/photo-1461360370896-922624d12aa1?auto=format&fit=crop&w=400&q=80';
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Tiêu đề tập podcast',
          hint: 'Ví dụ: Tập 15: Hiệp định Genève 1954 và Vĩ tuyến 17',
          controller: _titleController,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Mô tả tóm tắt nội dung',
          hint: 'Giới thiệu khái quát về sự kiện hoặc nhân vật lịch sử...',
          controller: _descController,
          maxLines: 4,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mô tả' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Giai đoạn lịch sử', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: _eras.map((era) {
            final isSelected = _selectedEra == era;
            return ChoiceChip(
              label: Text(era),
              selected: isSelected,
              selectedColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (selected) {
                if (selected) setState(() => _selectedEra = era);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep3(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Nguồn tư liệu & Sách tham khảo (Bắt buộc)',
          hint: 'Ghi rõ tên sách, tác giả, hồi ký, tài liệu lưu trữ để phục vụ kiểm duyệt...',
          controller: _sourcesController,
          maxLines: 3,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng cung cấp nguồn tư liệu để đảm bảo tính xác thực' : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Chế độ Độc quyền thành viên (Locked)', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Chỉ người mua gói Hội viên kênh mới được nghe toàn bộ tập này.'),
          value: _isExclusive,
          activeThumbColor: AppColors.secondaryLight,
          onChanged: (val) => setState(() => _isExclusive = val),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
            borderRadius: AppSpacing.roundedMd,
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.tertiaryLight),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Podcast sau khi gửi sẽ được AI quét dữ liệu lịch sử tự động, sau đó chuyển tới Admin phê duyệt nếu cần thiết.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
