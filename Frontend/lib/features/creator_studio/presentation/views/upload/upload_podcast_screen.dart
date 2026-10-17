import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/core/widgets/soundcloud_waveform.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/data/repositories/api_creator_repository.dart';

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
  Uint8List? _coverImageBytes;
  bool _isVideo = false;
  String? _audioFileName;
  bool _isUploadingAudio = false;
  double _uploadProgress = 0.0;
  String? _videoFileName;
  bool _isUploadingVideo = false;
  double _videoUploadProgress = 0.0;
  bool _isSubmitting = false;
  String? _selectedSeriesId;
  String? _selectedPdfFileName;
  List<int>? _pdfFileBytes;
  List<int>? _pickedMediaBytes;

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
      final isVideoFile = edit.audioFileName != null &&
          (edit.audioFileName!.toLowerCase().endsWith('.mp4') ||
              edit.audioFileName!.toLowerCase().endsWith('.mov') ||
              edit.audioFileName!.toLowerCase().endsWith('.mkv') ||
              edit.audioFileName!.toLowerCase().endsWith('.webm') ||
              edit.audioFileName!.toLowerCase().contains('video'));
      _isVideo = isVideoFile;
      if (isVideoFile) {
        _videoFileName = edit.audioFileName;
        _audioFileName = null;
      } else {
        _audioFileName = edit.audioFileName;
        _videoFileName = null;
      }
      _uploadProgress = 1.0;
      _videoUploadProgress = 1.0;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _sourcesController.dispose();
    super.dispose();
  }

  Future<void> _applySelectedMedia(String fileName, {required bool isVideo}) async {
    final cleanName = fileName.trim();
    if (isVideo) {
      setState(() {
        _isUploadingVideo = true;
        _videoUploadProgress = 0.0;
      });

      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 25));
        if (!mounted) return;
        setState(() {
          _videoUploadProgress = i / 10.0;
        });
      }

      if (mounted) {
        setState(() {
          _isUploadingVideo = false;
          _videoFileName = cleanName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật tệp video: $cleanName'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        _isUploadingAudio = true;
        _uploadProgress = 0.0;
      });

      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 25));
        if (!mounted) return;
        setState(() {
          _uploadProgress = i / 10.0;
        });
      }

      if (mounted) {
        setState(() {
          _isUploadingAudio = false;
          _audioFileName = cleanName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật tệp âm thanh: $cleanName'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickAudioDirectly() async {
    try {
      PlatformFile? file;
      try {
        file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        );
      } catch (_) {
        file = await FilePicker.pickFile(type: FileType.audio);
      }
      if (file != null && file.name.isNotEmpty) {
        try {
          final bytes = await file.readAsBytes();
          _pickedMediaBytes = bytes.isNotEmpty ? bytes : null;
        } catch (_) {}
        await _applySelectedMedia(file.name, isVideo: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn tệp âm thanh: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickVideoDirectly() async {
    try {
      PlatformFile? file;
      try {
        file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v'],
        );
      } catch (_) {
        file = await FilePicker.pickFile(type: FileType.video);
      }
      if (file != null && file.name.isNotEmpty) {
        try {
          final bytes = await file.readAsBytes();
          _pickedMediaBytes = bytes.isNotEmpty ? bytes : null;
        } catch (_) {}
        await _applySelectedMedia(file.name, isVideo: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn tệp video: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleUploadAudio() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AudioSourceSelectorSheet(
        initialFileName: _audioFileName,
        isVideo: false,
      ),
    );

    if (selected != null && selected.trim().isNotEmpty) {
      await _applySelectedMedia(selected, isVideo: false);
    }
  }

  Future<void> _handleUploadVideo() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AudioSourceSelectorSheet(
        initialFileName: _videoFileName,
        isVideo: true,
      ),
    );

    if (selected != null && selected.trim().isNotEmpty) {
      await _applySelectedMedia(selected, isVideo: true);
    }
  }

  Future<void> _handleUploadCoverDirectly() async {
    try {
      PlatformFile? file;
      try {
        file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        );
      } catch (_) {
        file = await FilePicker.pickFile(
          type: FileType.image,
        );
      }

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final base64Str = base64Encode(bytes);
          final ext = file.extension?.toLowerCase() ?? 'jpeg';
          final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
          final dataUrl = 'data:$mime;base64,$base64Str';
          setState(() {
            _selectedCoverUrl = dataUrl;
            _coverImageBytes = bytes;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã tải ảnh bìa từ máy lên thành công!'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleSelectCover() async {
    final selectedUrl = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CoverImagePickerSheet(
        currentCoverUrl: _selectedCoverUrl,
      ),
    );

    if (selectedUrl != null && selectedUrl.trim().isNotEmpty) {
      setState(() {
        _selectedCoverUrl = selectedUrl.trim();
        if (_selectedCoverUrl.startsWith('data:image')) {
          try {
            final base64Part = _selectedCoverUrl.split(',').last;
            _coverImageBytes = base64Decode(base64Part);
          } catch (_) {
            _coverImageBytes = null;
          }
        } else {
          _coverImageBytes = null;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật ảnh bìa podcast thành công!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final effectiveMedia = _isVideo ? _videoFileName : _audioFileName;

    if (effectiveMedia == null || effectiveMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isVideo
              ? 'Vui lòng tải lên hoặc chọn tệp video (Video MP4/MOV)'
              : 'Vui lòng tải lên hoặc chọn tệp âm thanh (Audio)'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      CreatorPodcast resultPodcast;
      if (widget.editingPodcast != null) {
        resultPodcast =
            await ref.read(creatorPodcastsProvider.notifier).updatePodcast(
                  id: widget.editingPodcast!.id,
                  title: _titleController.text.trim(),
                  description: _descController.text.trim(),
                  eraTag: _selectedEra,
                  sources: _sourcesController.text.trim(),
                  isExclusive: _isExclusive,
                  coverUrl: _selectedCoverUrl,
                  audioFileName: effectiveMedia,
                  duration: widget.editingPodcast!.duration.inSeconds > 0
                      ? widget.editingPodcast!.duration
                      : const Duration(minutes: 25, seconds: 30),
                  mediaBytes: _pickedMediaBytes,
                );

        // Assign to series if selected
        if (_selectedSeriesId != null && _selectedSeriesId!.isNotEmpty) {
          final repo = ref.read(creatorRepositoryProvider);
          if (repo is ApiCreatorRepository) {
            await repo.assignPodcastToSeries(
              podcastId: resultPodcast.id,
              seriesId: _selectedSeriesId!,
            );
          }
        }

        // Upload PDF Reference if selected
        if (_pdfFileBytes != null && _selectedPdfFileName != null) {
          final repo = ref.read(creatorRepositoryProvider);
          if (repo is ApiCreatorRepository) {
            await repo.uploadPdfReferenceFile(
              podcastId: resultPodcast.id,
              fileBytes: _pdfFileBytes!,
              filename: _selectedPdfFileName!,
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật podcast thành công!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        resultPodcast =
            await ref.read(creatorPodcastsProvider.notifier).createPodcast(
                  title: _titleController.text.trim(),
                  description: _descController.text.trim(),
                  eraTag: _selectedEra,
                  sources: _sourcesController.text.trim(),
                  isExclusive: _isExclusive,
                  coverUrl: _selectedCoverUrl,
                  audioFileName: effectiveMedia,
                  duration: const Duration(minutes: 25, seconds: 30),
                  mediaBytes: _pickedMediaBytes,
                );

        // Assign to series if selected
        if (_selectedSeriesId != null && _selectedSeriesId!.isNotEmpty) {
          final repo = ref.read(creatorRepositoryProvider);
          if (repo is ApiCreatorRepository) {
            await repo.assignPodcastToSeries(
              podcastId: resultPodcast.id,
              seriesId: _selectedSeriesId!,
            );
          }
        }

        // Upload PDF Reference if selected
        if (_pdfFileBytes != null && _selectedPdfFileName != null) {
          final repo = ref.read(creatorRepositoryProvider);
          if (repo is ApiCreatorRepository) {
            await repo.uploadPdfReferenceFile(
              podcastId: resultPodcast.id,
              fileBytes: _pdfFileBytes!,
              filename: _selectedPdfFileName!,
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Podcast đã được gửi lên hệ thống và chuyển vào hàng đợi kiểm duyệt AI!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
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
        actions: [
          if (widget.editingPodcast != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: const Text('Lưu'),
              ),
            ),
        ],
      ),
      body: isLimitReached && widget.editingPodcast == null
          ? _buildLimitReachedView(isDark)
          : Form(
              key: _formKey,
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep == 0) {
                    final hasMedia = _isVideo
                        ? (_videoFileName != null && _videoFileName!.isNotEmpty)
                        : (_audioFileName != null && _audioFileName!.isNotEmpty);
                    if (!hasMedia) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isVideo
                              ? 'Vui lòng tải lên hoặc chọn tệp video (Video MP4/MOV)'
                              : 'Vui lòng tải lên hoặc chọn tệp âm thanh (Audio)'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    setState(() => _currentStep++);
                  } else if (_currentStep == 1) {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
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
                            label: _currentStep == 2
                                ? (widget.editingPodcast != null ? 'Lưu thay đổi' : 'Gửi duyệt & Đăng')
                                : 'Tiếp tục',
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
                    title: Text(_isVideo ? 'Tệp video & Ảnh bìa' : 'Tệp âm thanh & Ảnh bìa'),
                    isActive: _currentStep >= 0,
                    state: (_isVideo
                            ? (_videoFileName != null && _videoFileName!.isNotEmpty)
                            : (_audioFileName != null && _audioFileName!.isNotEmpty))
                        ? StepState.complete
                        : StepState.indexed,
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
                InkWell(
                  onTap: _handleUploadAudio,
                  borderRadius: AppSpacing.roundedSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _audioFileName ?? 'Chọn tệp âm thanh (mp3, m4a, wav)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (_audioFileName != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_outlined, size: 16, color: AppColors.primaryLight),
                        ],
                      ],
                    ),
                  ),
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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    AppButton(
                      label: _audioFileName != null ? 'Tải tệp khác từ máy' : 'Tải lên Audio từ máy',
                      icon: const Icon(Icons.file_upload_outlined, size: 16),
                      height: 38,
                      type: AppButtonType.primary,
                      onPressed: _pickAudioDirectly,
                    ),
                    AppButton(
                      label: 'Chọn mẫu / URL',
                      icon: const Icon(Icons.link_rounded, size: 16),
                      height: 38,
                      type: AppButtonType.secondary,
                      onPressed: _handleUploadAudio,
                    ),
                  ],
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
                InkWell(
                  onTap: _pickVideoDirectly,
                  borderRadius: AppSpacing.roundedSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _videoFileName ?? 'Chọn tệp video podcast (mp4, mov, mkv)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (_videoFileName != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_outlined, size: 16, color: AppColors.secondaryLight),
                        ],
                      ],
                    ),
                  ),
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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    AppButton(
                      label: _videoFileName != null ? 'Tải video khác từ máy' : 'Tải lên Video từ máy',
                      icon: const Icon(Icons.file_upload_outlined, size: 16),
                      height: 38,
                      type: AppButtonType.primary,
                      onPressed: _pickVideoDirectly,
                    ),
                    AppButton(
                      label: 'Chọn mẫu / URL',
                      icon: const Icon(Icons.link_rounded, size: 16),
                      height: 38,
                      type: AppButtonType.secondary,
                      onPressed: _handleUploadVideo,
                    ),
                  ],
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
            InkWell(
              onTap: _handleSelectCover,
              borderRadius: AppSpacing.roundedMd,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: AppSpacing.roundedMd,
                    child: _buildCoverPreviewWidget(isDark),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppButton(
                        label: 'Tải ảnh từ máy',
                        icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                        height: 38,
                        type: AppButtonType.primary,
                        onPressed: _handleUploadCoverDirectly,
                      ),
                      AppButton(
                        label: 'Chọn từ thư viện',
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        height: 38,
                        type: AppButtonType.secondary,
                        onPressed: _handleSelectCover,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Khuyến nghị tỉ lệ 1:1 (vuông), tối thiểu 500x500px, định dạng JPG/PNG.',
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
      ],
    );
  }

  Widget _buildCoverPreviewWidget(bool isDark) {
    if (_coverImageBytes != null) {
      return Image.memory(
        _coverImageBytes!,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
      );
    }
    if (_selectedCoverUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(_selectedCoverUrl.split(',').last);
        return Image.memory(
          bytes,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }
    if (_selectedCoverUrl.isEmpty) {
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: AppSpacing.roundedMd,
          color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        ),
        child: const Center(
          child: Icon(Icons.photo_size_select_actual_rounded, color: AppColors.onSurfaceMutedLight, size: 30),
        ),
      );
    }
    return Image.network(
      _selectedCoverUrl,
      width: 84,
      height: 84,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: AppSpacing.roundedMd,
          gradient: const LinearGradient(
            colors: [Color(0xFF8B2500), Color(0xFFCD3700)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu_rounded, color: Colors.white, size: 28),
            SizedBox(height: 2),
            Text('Sử Việt', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 84,
          height: 84,
          color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
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
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Thuộc Series (Tuyển tập)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.xs),
        Consumer(
          builder: (context, ref, _) {
            final seriesList =
                ref.watch(creatorSeriesProvider).value ?? [];
            return DropdownButtonFormField<String?>(
              initialValue: _selectedSeriesId,
              decoration: const InputDecoration(
                hintText: 'Chọn Series liên quan (tùy chọn)',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Không thuộc Series nào (Tập đơn lẻ)'),
                ),
                ...seriesList.map((s) => DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(s.title),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedSeriesId = val),
            );
          },
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
          hint:
              'Ghi rõ tên sách, tác giả, hồi ký, tài liệu lưu trữ để phục vụ kiểm duyệt...',
          controller: _sourcesController,
          maxLines: 3,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Vui lòng cung cấp nguồn tư liệu để đảm bảo tính xác thực'
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tài liệu PDF đính kèm (Nguồn xác thực)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: Text(_selectedPdfFileName != null
                  ? 'Đổi tệp PDF'
                  : 'Tải lên PDF'),
              onPressed: () async {
                try {
                  PlatformFile? file;
                  try {
                    file = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                  } catch (_) {
                    file = await FilePicker.pickFile(type: FileType.any);
                  }
                  final picked = file;
                  if (picked != null && picked.name.isNotEmpty) {
                    final bytes = await picked.readAsBytes();
                    setState(() {
                      _selectedPdfFileName = picked.name;
                      _pdfFileBytes = bytes;
                    });
                  }
                } catch (_) {}
              },
            ),
          ],
        ),
        if (_selectedPdfFileName != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceVariantDark
                  : AppColors.surfaceVariantLight,
              borderRadius: AppSpacing.roundedSm,
              border: Border.all(
                  color: AppColors.secondaryLight.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_rounded,
                    size: 20, color: AppColors.secondaryLight),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _selectedPdfFileName!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => setState(() {
                    _selectedPdfFileName = null;
                    _pdfFileBytes = null;
                  }),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Chế độ Độc quyền thành viên (Locked)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text(
              'Chỉ người mua gói Hội viên kênh mới được nghe toàn bộ tập này.'),
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

class _AudioSourceSelectorSheet extends StatefulWidget {
  final String? initialFileName;
  final bool isVideo;

  const _AudioSourceSelectorSheet({
    this.initialFileName,
    this.isVideo = false,
  });

  @override
  State<_AudioSourceSelectorSheet> createState() => _AudioSourceSelectorSheetState();
}

class _AudioSourceSelectorSheetState extends State<_AudioSourceSelectorSheet> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialFileName ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaLabel = widget.isVideo ? 'Video' : 'Audio';

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.isVideo ? Icons.video_collection_rounded : Icons.audiotrack_rounded,
                  color: widget.isVideo ? AppColors.secondaryLight : AppColors.primaryLight,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Thay đổi tệp $mediaLabel',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nhập tên tệp / URL trực tuyến, hoặc tải tệp trực tiếp từ thiết bị của bạn.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Tên tệp hoặc URL $mediaLabel',
              hint: widget.isVideo ? 'Ví dụ: tap15_video.mp4 hoặc https://...' : 'Ví dụ: tap15_audio.mp3 hoặc https://...',
              controller: _textController,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Áp dụng tên tệp này',
                height: 40,
                onPressed: () {
                  final text = _textController.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.of(context).pop(text);
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Hoặc tải lên tệp mới từ máy',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Tải lên tệp mới từ máy (.${widget.isVideo ? 'mp4, .mov' : 'mp3, .wav'})',
                type: AppButtonType.secondary,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                height: 40,
                onPressed: () async {
                  try {
                    PlatformFile? file;
                    try {
                      file = await FilePicker.pickFile(
                        type: FileType.custom,
                        allowedExtensions: widget.isVideo
                            ? ['mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v']
                            : ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
                      );
                    } catch (_) {
                      file = await FilePicker.pickFile(
                        type: widget.isVideo ? FileType.video : FileType.audio,
                      );
                    }
                    if (file != null && file.name.isNotEmpty) {
                      if (context.mounted) {
                        Navigator.of(context).pop(file.name);
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi chọn tệp: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverImagePickerSheet extends StatefulWidget {
  final String currentCoverUrl;

  const _CoverImagePickerSheet({required this.currentCoverUrl});

  @override
  State<_CoverImagePickerSheet> createState() => _CoverImagePickerSheetState();
}

class _CoverImagePickerSheetState extends State<_CoverImagePickerSheet> {
  late TextEditingController _urlController;
  late String _previewUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.currentCoverUrl);
    _previewUrl = widget.currentCoverUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleUploadNewImage() async {
    try {
      setState(() => _isUploading = true);
      PlatformFile? file;
      try {
        file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        );
      } catch (_) {
        file = await FilePicker.pickFile(
          type: FileType.image,
        );
      }

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final base64Str = base64Encode(bytes);
          final ext = file.extension?.toLowerCase() ?? 'jpeg';
          final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
          final dataUrl = 'data:$mime;base64,$base64Str';
          if (mounted) {
            Navigator.of(context).pop(dataUrl);
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ảnh: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library_rounded, color: AppColors.primaryLight),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'Ảnh bìa Podcast',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Dán liên kết URL ảnh bìa hoặc tải ảnh mới từ thiết bị của bạn.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

          // Nhập URL ảnh
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Dán liên kết ảnh (URL)',
                  hint: 'https://...',
                  controller: _urlController,
                  onChanged: (val) {
                    setState(() => _previewUrl = val.trim());
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: AppButton(
                  label: 'Áp dụng',
                  height: 48,
                  width: 90,
                  onPressed: () {
                    final text = _urlController.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.of(context).pop(text);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Nút tải ảnh mới
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Tải ảnh bìa mới từ máy (JPG, PNG)',
              type: AppButtonType.secondary,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              isLoading: _isUploading,
              height: 40,
              onPressed: _handleUploadNewImage,
            ),
          ),
          if (_previewUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                borderRadius: AppSpacing.roundedSm,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _previewUrl.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(_previewUrl.split(',').last),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            _previewUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF8B2500), Color(0xFFCD3700)],
                                ),
                              ),
                              child: const Icon(Icons.history_edu_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ảnh bìa xem trước', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          _previewUrl.startsWith('data:image') ? 'Đã tải ảnh lên từ máy tính' : _previewUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_previewUrl),
                    child: const Text('Dùng ảnh này'),
                  ),
                ],
              ),
            ),
          ],

          ],
        ),
      ),
    );
  }
}
