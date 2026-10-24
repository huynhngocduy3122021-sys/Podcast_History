import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';
import 'package:podcast_history/core/widgets/app_button.dart';
import 'package:podcast_history/core/widgets/app_text_field.dart';
import 'package:podcast_history/features/creator_studio/presentation/controllers/creator_controller.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/core/services/audio_player/audio_player_service.dart';
import 'package:podcast_history/core/utils/image_url_helper.dart';

class UploadPodcastScreen extends ConsumerStatefulWidget {
  final CreatorPodcast? editingPodcast;
  final bool isResubmit;

  const UploadPodcastScreen({
    super.key,
    this.editingPodcast,
    this.isResubmit = false,
  });

  @override
  ConsumerState<UploadPodcastScreen> createState() => _UploadPodcastScreenState();
}

class _UploadPodcastScreenState extends ConsumerState<UploadPodcastScreen> {
  bool get _isResubmitting =>
      widget.isResubmit || (widget.editingPodcast?.status == PodcastStatus.rejected);

  int _currentStep = 0;
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();
  static const String _otherSeriesKey = '__other__';

  // Form Fields
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _sourcesController;
  late TextEditingController _customSeriesController;
  String? _selectedCategoryId;
  String _selectedEra = 'Lịch sử';
  bool _isExclusive = false;
  String _selectedCoverUrl = 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=400&q=80';
  Uint8List? _coverImageBytes;
  String? _audioFileName;
  bool _isUploadingAudio = false;
  double _uploadProgress = 0.0;
  bool _isSubmitting = false;
  String? _selectedSeriesId;
  String? _selectedPdfFileName;
  List<int>? _pdfFileBytes;
  List<int>? _pickedMediaBytes;
  Duration? _detectedDuration;

  Future<void> _detectDurationFromBytes(List<int> bytes) async {
    try {
      final notifier = ref.read(audioPlayerServiceProvider.notifier);
      final dur = await notifier.probeDuration(
        'temp_upload_${DateTime.now().millisecondsSinceEpoch}',
        bytes: bytes,
      );
      if (dur != null && dur > Duration.zero && mounted) {
        setState(() {
          _detectedDuration = dur;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final edit = widget.editingPodcast;
    _titleController = TextEditingController(text: edit?.title ?? '');
    _descController = TextEditingController(text: edit?.description ?? '');
    _sourcesController = TextEditingController(text: edit?.sources ?? '');
    _customSeriesController = TextEditingController();
    if (edit != null) {
      _selectedCategoryId = edit.categoryId;
      _selectedSeriesId = edit.seriesId;
      _selectedEra = edit.eraTag;
      _isExclusive = edit.isExclusive;
      _selectedCoverUrl = edit.coverUrl.isNotEmpty ? edit.coverUrl : _selectedCoverUrl;
      _audioFileName = edit.audioFileName ??
          (edit.videoUrl != null || edit.mediaType != null ? 'audio.mp3' : null);
      _uploadProgress = 1.0;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _sourcesController.dispose();
    _customSeriesController.dispose();
    super.dispose();
  }

  Future<void> _applySelectedMedia(String fileName) async {
    final cleanName = fileName.trim();
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

  Future<void> _pickAudioDirectly() async {
    try {
      PlatformFile? file;
      try {
        file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'mp4'],
        );
      } catch (_) {
        file = await FilePicker.pickFile(type: FileType.audio);
      }
      if (file != null && file.name.isNotEmpty) {
        try {
          final bytes = await file.readAsBytes();
          _pickedMediaBytes = bytes.isNotEmpty ? bytes : null;
          if (_pickedMediaBytes != null) {
            unawaited(_detectDurationFromBytes(_pickedMediaBytes!));
          }
        } catch (_) {}
        await _applySelectedMedia(file.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn tệp âm thanh: $e'), backgroundColor: AppColors.error),
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
        onFilePicked: (file, bytes) {
          _pickedMediaBytes = bytes.isNotEmpty ? bytes : null;
          if (_pickedMediaBytes != null) {
            unawaited(_detectDurationFromBytes(_pickedMediaBytes!));
          }
        },
      ),
    );

    if (selected != null && selected.trim().isNotEmpty) {
      await _applySelectedMedia(selected);
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
          final ext = file.extension?.toLowerCase() ?? 'jpeg';
          final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
          final base64Str = base64Encode(bytes);
          final dataUrl = 'data:$mime;base64,$base64Str';

          setState(() {
            _coverImageBytes = bytes;
            _selectedCoverUrl = dataUrl;
          });

          // Nếu đang chỉnh sửa podcast đã có trên server, gọi API upload ảnh bìa ngay lập tức: POST /api/creator/podcasts/{id}/thumbnail
          if (widget.editingPodcast != null) {
            try {
              final repo = ref.read(creatorRepositoryProvider);
              final uploaded = await repo.uploadPodcastThumbnailFile(
                podcastId: widget.editingPodcast!.id,
                fileBytes: bytes,
                filename: file.name.isNotEmpty ? file.name : 'cover.$ext',
                mimeType: mime,
              );
              if (uploaded != null && uploaded.coverUrl.isNotEmpty) {
                setState(() {
                  _selectedCoverUrl = uploaded.coverUrl;
                });
              }
            } catch (err) {
              debugPrint('Lỗi upload thumbnail lên server: $err');
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã tải ảnh bìa lên thành công!'),
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
      final trimmed = selectedUrl.trim();
      setState(() {
        _selectedCoverUrl = trimmed;
        if (trimmed.startsWith('data:image')) {
          try {
            final base64Part = trimmed.split(',').last;
            _coverImageBytes = base64Decode(base64Part);
          } catch (_) {
            _coverImageBytes = null;
          }
        } else {
          _coverImageBytes = null;
        }
      });

      // Nếu đang chỉnh sửa podcast và vừa chọn ảnh máy tính, gọi API upload ngay
      if (widget.editingPodcast != null && _coverImageBytes != null) {
        try {
          final repo = ref.read(creatorRepositoryProvider);
          final uploaded = await repo.uploadPodcastThumbnailFile(
            podcastId: widget.editingPodcast!.id,
            fileBytes: _coverImageBytes!,
            filename: 'cover.jpg',
            mimeType: trimmed.startsWith('data:image/png') ? 'image/png' : 'image/jpeg',
          );
          if (uploaded != null && uploaded.coverUrl.isNotEmpty) {
            setState(() {
              _selectedCoverUrl = uploaded.coverUrl;
            });
          }
        } catch (err) {
          debugPrint('Lỗi upload thumbnail lên server: $err');
        }
      }

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

  Future<void> _handleSubmit({bool submitForReview = false}) async {
    final effectiveMedia = _audioFileName;

    if (effectiveMedia == null || effectiveMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng tải lên hoặc chọn tệp âm thanh (Audio)'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _currentStep = 0);
      return;
    }

    const maxUploadBytes = 100 * 1024 * 1024;
    if (_pickedMediaBytes != null && _pickedMediaBytes!.length > maxUploadBytes) {
      final sizeMb = (_pickedMediaBytes!.length / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tệp âm thanh ($sizeMb MB) vượt quá giới hạn tối đa của hệ thống (100MB). Vui lòng chọn tệp nhỏ hơn 100MB.',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
      setState(() => _currentStep = 0);
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _step2FormKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề tập podcast'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _currentStep = 1);
      return;
    }

    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      _step2FormKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mô tả tóm tắt nội dung'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _currentStep = 1);
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn danh mục chủ đề'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _currentStep = 1);
      return;
    }

    final sources = _sourcesController.text.trim();
    if (sources.isEmpty) {
      _step3FormKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cung cấp nguồn tư liệu để đảm bảo tính xác thực'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _currentStep = 2);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(creatorRepositoryProvider);

      // Xử lý tạo Series mới nếu chọn "Khác"
      String? effectiveSeriesId = _selectedSeriesId;
      if (_selectedSeriesId == _otherSeriesKey) {
        final customSeriesName = _customSeriesController.text.trim();
        if (customSeriesName.isNotEmpty) {
          final slug = customSeriesName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');
          try {
            final createdSeries = await ref.read(creatorSeriesProvider.notifier).createSeries(
              title: customSeriesName,
              slug: slug.isNotEmpty ? slug : 'series-${DateTime.now().millisecondsSinceEpoch}',
              categoryId: _selectedCategoryId ?? '00000000-0000-0000-0000-000000000001',
              description: 'Tuyển tập $customSeriesName',
            );
            if (createdSeries != null) {
              effectiveSeriesId = createdSeries.id;
              _selectedSeriesId = createdSeries.id;
            }
          } catch (err) {
            debugPrint('Lỗi tạo series mới: $err');
          }
        } else {
          effectiveSeriesId = null;
        }
      }

      if (widget.editingPodcast != null) {
        final bool shouldSubmit = submitForReview || _isResubmitting;

        final resultPodcast =
            await ref.read(creatorPodcastsProvider.notifier).updatePodcast(
                  id: widget.editingPodcast!.id,
                  title: _titleController.text.trim(),
                  description: _descController.text.trim(),
                  eraTag: _selectedEra,
                  categoryId: _selectedCategoryId,
                  seriesId: effectiveSeriesId,
                  sources: _sourcesController.text.trim(),
                  isExclusive: _isExclusive,
                  coverUrl: _selectedCoverUrl,
                  audioFileName: effectiveMedia,
                  duration: _detectedDuration ??
                      (widget.editingPodcast!.duration.inSeconds > 0
                          ? widget.editingPodcast!.duration
                          : const Duration(minutes: 30)),
                  mediaBytes: _pickedMediaBytes,
                  autoSubmit: false,
                );

        if (_detectedDuration != null) {
          ref.read(audioPlayerServiceProvider.notifier).setKnownDuration(resultPodcast.id, _detectedDuration!);
        }

        // Upload Thumbnail (POST /api/creator/podcasts/{id}/thumbnail) nếu có ảnh bìa mới được chọn từ thiết bị
        if (_coverImageBytes != null && _coverImageBytes!.isNotEmpty) {
          try {
            final ext = _selectedCoverUrl.startsWith('data:image/png') ? 'png' : 'jpg';
            final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
            final withThumb = await repo.uploadPodcastThumbnailFile(
              podcastId: resultPodcast.id,
              fileBytes: _coverImageBytes!,
              filename: 'cover.$ext',
              mimeType: mime,
            );
            if (withThumb != null && withThumb.coverUrl.isNotEmpty) {
              _selectedCoverUrl = withThumb.coverUrl;
            }
          } catch (thumbErr) {
            debugPrint('Lỗi upload ảnh bìa: $thumbErr');
          }
        }

        // Upload PDF Reference if selected
        if (_pdfFileBytes != null && _selectedPdfFileName != null) {
          await repo.uploadPdfReferenceFile(
            podcastId: resultPodcast.id,
            fileBytes: _pdfFileBytes!,
            filename: _selectedPdfFileName!,
          );
        }

        if (_pickedMediaBytes != null && _pickedMediaBytes!.isNotEmpty) {
          ref.read(audioPlayerServiceProvider.notifier).cacheBytes(resultPodcast.id, _pickedMediaBytes!);
        }

        if (shouldSubmit) {
          await ref.read(creatorPodcastsProvider.notifier).submitPodcast(resultPodcast.id);
        }

        await ref.read(creatorPodcastsProvider.notifier).loadPodcasts();

        if (mounted) {
          final wasPublished = widget.editingPodcast?.status == PodcastStatus.published;
          final wasPending = widget.editingPodcast?.status == PodcastStatus.pendingAdmin;
          final wasDraft = widget.editingPodcast?.status == PodcastStatus.draft;

          String message = 'Cập nhật podcast thành công!';
          String popResult = 'updated';

          if (shouldSubmit) {
            message = 'Đã gửi lại tập "${resultPodcast.title}" cho Admin duyệt thành công!';
            popResult = 'resubmitted';
          } else if (wasPublished) {
            message = 'Tập podcast đã được chuyển về mục Bản nháp. Hãy bấm "Chờ Admin duyệt" để gửi Admin kiểm duyệt lại.';
            popResult = 'published_to_draft';
          } else if (wasPending) {
            message = 'Đã cập nhật tập "${resultPodcast.title}" (vẫn ở mục Chờ Admin duyệt)!';
            popResult = 'pending_updated';
          } else if (wasDraft) {
            message = 'Đã cập nhật Bản nháp "${resultPodcast.title}" thành công!';
            popResult = 'draft_updated';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.of(context).pop(popResult);
        }
      } else {
        // Step 4: POST /api/creator/podcasts (Draft)
        final draftPodcast = await repo.createPodcast(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          eraTag: _selectedEra,
          categoryId: _selectedCategoryId,
          sources: _sourcesController.text.trim(),
          isExclusive: _isExclusive,
          coverUrl: _selectedCoverUrl,
          audioFileName: effectiveMedia,
          duration: _detectedDuration ?? const Duration(minutes: 30),
          mediaBytes: null,
          seriesId: null,
          autoSubmit: false,
        );

        final podcastId = draftPodcast.id;
        if (_detectedDuration != null) {
          ref.read(audioPlayerServiceProvider.notifier).setKnownDuration(podcastId, _detectedDuration!);
        }

        // Step 4.5: POST /api/creator/podcasts/{id}/thumbnail (Upload ảnh bìa nếu chọn từ thiết bị)
        if (_coverImageBytes != null && _coverImageBytes!.isNotEmpty) {
          try {
            final ext = _selectedCoverUrl.startsWith('data:image/png') ? 'png' : 'jpg';
            final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
            final withThumb = await repo.uploadPodcastThumbnailFile(
              podcastId: podcastId,
              fileBytes: _coverImageBytes!,
              filename: 'cover.$ext',
              mimeType: mime,
            );
            if (withThumb != null && withThumb.coverUrl.isNotEmpty) {
              _selectedCoverUrl = withThumb.coverUrl;
            }
          } catch (thumbErr) {
            debugPrint('Lỗi upload ảnh bìa: $thumbErr');
          }
        }

        // Step 5: PUT /api/creator/podcasts/{id}/series (Optional)
        if (effectiveSeriesId != null && effectiveSeriesId.isNotEmpty) {
          await repo.assignPodcastToSeries(
            podcastId: podcastId,
            seriesId: effectiveSeriesId,
          );
        }

        // Step 6: POST /api/creator/podcasts/{id}/video (Mandatory)
        if (_pickedMediaBytes != null && _pickedMediaBytes!.isNotEmpty) {
          final nameLower = effectiveMedia.toLowerCase();
          String mimeType = 'video/mp4';
          if (nameLower.endsWith('.mp3')) {
            mimeType = 'audio/mpeg';
          } else if (nameLower.endsWith('.m4a')) {
            mimeType = 'audio/mp4';
          } else if (nameLower.endsWith('.wav')) {
            mimeType = 'audio/wav';
          } else if (nameLower.endsWith('.aac')) {
            mimeType = 'audio/aac';
          } else if (nameLower.endsWith('.webm')) {
            mimeType = 'video/webm';
          } else if (nameLower.endsWith('.mov')) {
            mimeType = 'video/quicktime';
          }

          final uploaded = await repo.uploadPodcastVideoFile(
            podcastId: podcastId,
            fileBytes: _pickedMediaBytes!,
            filename: effectiveMedia,
            mimeType: mimeType,
          );
          if (!uploaded) {
            throw Exception('Không thể tải tệp âm thanh lên máy chủ. Vui lòng kiểm tra dung lượng tệp (tối đa 100MB) và thử lại.');
          }
        }

        // Step 7 & 8: PDF Reference (Optional)
        if (_pdfFileBytes != null && _selectedPdfFileName != null) {
          await repo.uploadPdfReferenceFile(
            podcastId: podcastId,
            fileBytes: _pdfFileBytes!,
            filename: _selectedPdfFileName!,
          );
        }

        // Step 9: Verify
        final verified = await repo.getPodcastById(podcastId);
        if (verified == null) {
          throw Exception('Không tìm thấy podcast vừa tạo trên máy chủ.');
        }

        if (_pickedMediaBytes != null && _pickedMediaBytes!.isNotEmpty) {
          ref.read(audioPlayerServiceProvider.notifier).cacheBytes(podcastId, _pickedMediaBytes!);
        }

        // Tải lại danh sách podcast để podcast hiển thị ngay ở mục Nháp
        await ref.read(creatorPodcastsProvider.notifier).loadPodcasts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã lưu podcast vào mục Bản nháp! Hãy bấm "Chờ Admin duyệt" ở danh sách để gửi kiểm duyệt.',
              ),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.of(context).pop('draft_saved');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
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
        title: Text(
          _isResubmitting
              ? 'Sửa & Gửi lại Podcast'
              : (widget.editingPodcast != null ? 'Sửa Podcast' : 'Đăng Podcast mới'),
        ),
        actions: [
          if (widget.editingPodcast != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _isSubmitting ? null : () => _handleSubmit(submitForReview: _isResubmitting),
                icon: Icon(
                  _isResubmitting ? Icons.send_rounded : Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(_isResubmitting ? 'Gửi duyệt' : 'Lưu'),
              ),
            ),
        ],
      ),
      body: isLimitReached && widget.editingPodcast == null
          ? _buildLimitReachedView(isDark)
          : Column(
              children: [
                if (widget.editingPodcast?.status == PodcastStatus.rejected &&
                    widget.editingPodcast?.rejectReason != null &&
                    widget.editingPodcast!.rejectReason!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: AppSpacing.roundedSm,
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.error),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lý do từ chối kiểm duyệt của Admin:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.editingPodcast!.rejectReason!,
                                style: const TextStyle(fontSize: 13, color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Stepper(
                    currentStep: _currentStep,
                    onStepTapped: (step) {
                      if (widget.editingPodcast != null || step < _currentStep) {
                        setState(() => _currentStep = step);
                      }
                    },
                    onStepContinue: () {
                      if (_currentStep == 0) {
                        final hasMedia = _audioFileName != null && _audioFileName!.isNotEmpty;
                        if (!hasMedia) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng tải lên hoặc chọn tệp âm thanh (Audio)'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        setState(() => _currentStep++);
                      } else if (_currentStep == 1) {
                        final isValid = _step2FormKey.currentState?.validate() ?? false;
                        final title = _titleController.text.trim();
                        final desc = _descController.text.trim();
                        if (!isValid || title.isEmpty || desc.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng nhập đầy đủ tiêu đề và mô tả tập podcast'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng chọn danh mục chủ đề'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        setState(() => _currentStep++);
                      } else {
                        _handleSubmit(submitForReview: _isResubmitting);
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
                                    ? (_isResubmitting
                                        ? 'Lưu & Gửi Admin duyệt'
                                        : (widget.editingPodcast != null ? 'Lưu thay đổi' : 'Lưu vào Bản nháp'))
                                    : 'Tiếp tục',
                                icon: (_currentStep == 2 && _isResubmitting)
                                    ? const Icon(Icons.send_rounded, size: 16)
                                    : null,
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
                        state: (_audioFileName != null && _audioFileName!.isNotEmpty)
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
              ],
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
        // Khung Upload Tệp Âm Thanh
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
      resolveImageUrl(_selectedCoverUrl),
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
    return Form(
      key: _step2FormKey,
      child: Column(
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
          const Text(
            'Danh mục chủ đề *',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.xs),
          Consumer(
            builder: (context, ref, _) {
              final categoriesAsync = ref.watch(categoriesProvider);
              return categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Text(
                      'Không có danh mục nào khả dụng',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  }
                  final currentId = categories.any((c) => c.id == _selectedCategoryId)
                      ? _selectedCategoryId
                      : categories.first.id;

                  if (_selectedCategoryId == null && categories.isNotEmpty) {
                    _selectedCategoryId = currentId;
                    final match = categories.firstWhere(
                      (c) => c.id == currentId,
                      orElse: () => categories.first,
                    );
                    _selectedEra = match.name;
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: currentId,
                    decoration: const InputDecoration(
                      hintText: 'Chọn danh mục podcast *',
                      isDense: true,
                      prefixIcon: Icon(Icons.category_outlined, size: 20),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategoryId = val;
                          final match = categories.firstWhere(
                            (c) => c.id == val,
                            orElse: () => categories.first,
                          );
                          _selectedEra = match.name;
                        });
                      }
                    },
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Vui lòng chọn danh mục' : null,
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(),
                ),
                error: (err, st) => const Text(
                  'Không thể tải danh mục từ máy chủ',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              );
            },
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
              final hasSelectedInList = _selectedSeriesId == null ||
                  _selectedSeriesId == _otherSeriesKey ||
                  seriesList.any((s) => s.id == _selectedSeriesId);
              final dropdownValue = hasSelectedInList ? _selectedSeriesId : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: dropdownValue,
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
                      DropdownMenuItem<String?>(
                        value: _otherSeriesKey,
                        child: Row(
                          children: const [
                            Icon(Icons.add_circle_outline_rounded,
                                size: 18, color: AppColors.primaryLight),
                            SizedBox(width: 8),
                            Text(
                              '+ Khác (Nhập tên Series mới...)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedSeriesId = val),
                  ),
                  if (_selectedSeriesId == _otherSeriesKey) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Tên Series mới *',
                      hint: 'Nhập tên tuyển tập / series mới cho podcast này...',
                      controller: _customSeriesController,
                      prefixIcon: const Icon(Icons.playlist_add_rounded, size: 20),
                      validator: (v) {
                        if (_selectedSeriesId == _otherSeriesKey &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Vui lòng nhập tên series mới';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '💡 Series mới sẽ tự động được tạo và liên kết với tập podcast này khi lưu.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.onSurfaceMutedDark
                            : AppColors.onSurfaceMutedLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(bool isDark) {
    return Form(
      key: _step3FormKey,
      child: Column(
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
      ),
    );
  }
}

class _AudioSourceSelectorSheet extends StatefulWidget {
  final String? initialFileName;
  final bool isVideo;
  final void Function(PlatformFile file, List<int> bytes)? onFilePicked;

  const _AudioSourceSelectorSheet({
    this.initialFileName,
    this.isVideo = false,
    this.onFilePicked,
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
                const Icon(
                  Icons.audiotrack_rounded,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'Thay đổi tệp âm thanh',
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
              'Nhập tên tệp / URL trực tuyến, hoặc tải tệp trực tiếp từ thiết bị của bạn.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Tên tệp hoặc URL âm thanh',
              hint: 'Ví dụ: tap15_audio.mp3 hoặc https://...',
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
                label: 'Tải lên tệp mới từ máy (.mp3, .m4a, .wav, .mp4)',
                type: AppButtonType.secondary,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                height: 40,
                onPressed: () async {
                  try {
                    PlatformFile? file;
                    try {
                      file = await FilePicker.pickFile(
                        type: FileType.custom,
                        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'mp4'],
                      );
                    } catch (_) {
                      file = await FilePicker.pickFile(
                        type: FileType.audio,
                      );
                    }
                    if (file != null && file.name.isNotEmpty) {
                      List<int> bytes = [];
                      try {
                        bytes = await file.readAsBytes();
                      } catch (_) {}
                      if (bytes.isNotEmpty) {
                        widget.onFilePicked?.call(file, bytes);
                      }
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
                            resolveImageUrl(_previewUrl),
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
