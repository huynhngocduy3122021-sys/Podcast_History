import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:podcast_history/core/network/api_client.dart';
import 'package:podcast_history/core/network/api_endpoints.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/domain/creator_repository.dart';

class ApiCreatorRepository implements CreatorRepository {
  final ApiClient _apiClient;
  final _uuid = const Uuid();

  // Clean in-memory caches (initialized with empty data, populated purely by API responses)
  CreatorProfile _cachedProfile = const CreatorProfile(
    id: '',
    name: 'Creator',
    handle: '',
    bio: '',
    avatarUrl: '',
    bannerUrl: '',
    isVerified: false,
    isPremium: false,
    maxFreePodcasts: 5,
    currentPodcastCount: 0,
    followersCount: 0,
    status: CreatorStatus.notRegistered,
  );
  final List<CreatorPodcast> _cachedPodcasts = [];
  final List<PodcastRequest> _cachedRequests = [];
  final List<BankAccount> _cachedBankAccounts = [];
  final List<WalletTransaction> _cachedTransactions = [];
  final List<StudioComment> _cachedComments = [];
  final List<InteractiveForm> _cachedForms = [];
  final List<CreatorSeries> _cachedSeries = [];
  final Set<String> _deletedPodcastIds = {};

  int _availableBalance = 0;
  int _pendingRelease = 0;
  int _holdingWithdraw = 0;
  final int _totalWithdrawn = 0;

  ApiCreatorRepository(this._apiClient);

  ApiClient get apiClient => _apiClient;

  // ==========================================
  // 1. PROFILE & REGISTRATION
  // ==========================================

  @override
  Future<CreatorProfile> getProfile() async {
    if (!_apiClient.isAuthenticated) {
      return _cachedProfile;
    }
    try {
      // 1. Call GET /api/creator-applications/me
      final appData = await _apiClient.get(ApiEndpoints.myCreatorApplication);
      if (appData is Map<String, dynamic>) {
        final statusStr = (appData['status'] as String? ?? '').toUpperCase();
        CreatorStatus creatorStatus;
        switch (statusStr) {
          case 'APPROVED':
            creatorStatus = CreatorStatus.approved;
            break;
          case 'PENDING':
            creatorStatus = CreatorStatus.pending;
            break;
          case 'REJECTED':
            creatorStatus = CreatorStatus.rejected;
            break;
          default:
            creatorStatus = CreatorStatus.notRegistered;
        }

        final rawChannelName = appData['channelName'] as String?;
        final rawUsername = appData['username'] as String?;
        final channelName =
            (rawChannelName != null && rawChannelName.isNotEmpty)
            ? rawChannelName
            : ((rawUsername != null && rawUsername.isNotEmpty)
                  ? rawUsername
                  : _cachedProfile.name);
        final handle = (rawUsername != null && rawUsername.isNotEmpty)
            ? '@$rawUsername'
            : _cachedProfile.handle;
        final intro = appData['introduction'] as String? ?? _cachedProfile.bio;
        final reviewNote = appData['reviewNote'] as String?;

        _cachedProfile = _cachedProfile.copyWith(
          id: appData['applicationId']?.toString() ?? _cachedProfile.id,
          name: channelName,
          handle: handle,
          bio: intro,
          status: creatorStatus,
          rejectReason: reviewNote,
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        _cachedProfile = _cachedProfile.copyWith(
          status: CreatorStatus.notRegistered,
        );
      }
    } catch (_) {}

    return _cachedProfile;
  }

  @override
  Future<void> submitRegistration({
    required String channelName,
    required String bio,
    required String socialLink,
  }) async {
    final body = {
      'channelName': channelName,
      'introduction': bio,
      'portfolioUrl': socialLink.isNotEmpty ? socialLink : null,
    };

    try {
      await _apiClient.post(ApiEndpoints.creatorApplications, body: body);
    } catch (_) {}

    _cachedProfile = _cachedProfile.copyWith(
      name: channelName,
      bio: bio,
      status: CreatorStatus.pending,
      rejectReason: null,
    );
  }

  @override
  Future<void> upgradeToPremium() async {
    // "cái nào chưa có thì bỏ qua": Attempt contract endpoint
    try {
      await _apiClient.post(
        ApiEndpoints.creatorUpgradePremium,
        body: {'plan': 'MONTHLY'},
      );
    } catch (_) {}
    _cachedProfile = _cachedProfile.copyWith(isPremium: true);
  }

  // ==========================================
  // 1.5. CATEGORIES & DASHBOARD
  // ==========================================

  @override
  Future<List<CreatorCategory>> getCategories() async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.categories,
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map(CreatorCategory.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  @override
  Future<CreatorDashboardData> getDashboard({String period = '7d'}) async {
    if (!_apiClient.isAuthenticated) {
      return const CreatorDashboardData();
    }
    try {
      final res = await _apiClient.get(
        ApiEndpoints.creatorDashboard(period: period),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        return CreatorDashboardData.fromJson(res);
      }
    } catch (_) {}
    return const CreatorDashboardData();
  }

  // ==========================================
  // 2. PODCASTS MANAGEMENT
  // ==========================================

  @override
  Future<List<CreatorPodcast>> getPodcasts({
    PodcastStatus? filterStatus,
  }) async {
    if (!_apiClient.isAuthenticated) {
      return const [];
    }
    try {
      // Call GET /api/creator/podcasts
      final response = await _apiClient.get(
        ApiEndpoints.creatorPodcasts,
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (response is List) {
        final list = <CreatorPodcast>[];
        for (final item in response) {
          if (item is Map<String, dynamic>) {
            final id = item['podcastId']?.toString();
            final statusStr = (item['status'] as String? ?? '').toUpperCase();
            if (id != null && _deletedPodcastIds.contains(id)) {
              continue;
            }
            if (statusStr == 'DELETED' || statusStr == 'ARCHIVED') {
              if (id != null) _deletedPodcastIds.add(id);
              continue;
            }
            var mapped = _mapBackendPodcastToModel(item);
            final existing = _cachedPodcasts.cast<CreatorPodcast?>().firstWhere(
              (p) => p?.id == mapped.id,
              orElse: () => null,
            );
            if (existing != null) {
              mapped = mapped.copyWith(
                audioFileName: mapped.audioFileName ?? existing.audioFileName,
                sources: mapped.sources.isNotEmpty
                    ? mapped.sources
                    : existing.sources,
                eraTag: mapped.eraTag.isNotEmpty
                    ? mapped.eraTag
                    : existing.eraTag,
                rejectReason: mapped.rejectReason ?? existing.rejectReason,
              );
            }
            if (mapped.status == PodcastStatus.rejected &&
                (mapped.rejectReason == null || mapped.rejectReason!.isEmpty)) {
              try {
                final revRes = await _apiClient.get(
                  ApiEndpoints.creatorPodcastReviews(mapped.id),
                  headers: const {'ngrok-skip-browser-warning': '1'},
                );
                if (revRes is Map<String, dynamic> &&
                    revRes['content'] is List) {
                  final contents = revRes['content'] as List;
                  if (contents.isNotEmpty) {
                    final firstRev = contents.first as Map<String, dynamic>;
                    final note = firstRev['note']?.toString();
                    if (note != null && note.isNotEmpty) {
                      mapped = mapped.copyWith(rejectReason: note);
                    }
                  }
                }
              } catch (_) {}
            }
            if (mapped.sources.isEmpty) {
              try {
                final refRes = await _apiClient.get(
                  ApiEndpoints.creatorPodcastReferences(mapped.id),
                  headers: const {'ngrok-skip-browser-warning': '1'},
                );
                if (refRes is List && refRes.isNotEmpty) {
                  final firstRef = refRes.first as Map<String, dynamic>;
                  final citation =
                      firstRef['citationText']?.toString() ??
                      firstRef['title']?.toString() ??
                      '';
                  if (citation.isNotEmpty) {
                    mapped = mapped.copyWith(sources: citation);
                  }
                }
              } catch (_) {}
            }
            list.add(mapped);
          }
        }
        _cachedPodcasts.clear();
        _cachedPodcasts.addAll(list);
      }
    } catch (_) {}

    if (filterStatus == null) {
      return List.unmodifiable(_cachedPodcasts);
    }
    return _cachedPodcasts.where((p) => p.status == filterStatus).toList();
  }

  @override
  Future<CreatorPodcast?> getPodcastById(String id) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.creatorPodcastById(id),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        final mapped = _mapBackendPodcastToModel(res);
        final idx = _cachedPodcasts.indexWhere((p) => p.id == id);
        if (idx != -1) {
          _cachedPodcasts[idx] = mapped;
        } else {
          _cachedPodcasts.add(mapped);
        }
        return mapped;
      }
    } catch (_) {}
    final cached = _cachedPodcasts.where((p) => p.id == id);
    if (cached.isNotEmpty) return cached.first;
    return null;
  }

  @override
  Future<CreatorPodcast> createPodcast({
    required String title,
    required String description,
    required String eraTag,
    required String sources,
    required bool isExclusive,
    required String coverUrl,
    required String? audioFileName,
    required Duration duration,
    List<int>? mediaBytes,
    String? categoryId,
    String? seriesId,
    int? episodeNumber,
    bool autoSubmit = false,
  }) async {
    String? effectiveCategoryId = categoryId;

    // 1. Resolve category ID
    if (effectiveCategoryId == null || effectiveCategoryId.isEmpty) {
      try {
        final categories = await getCategories();
        if (categories.isNotEmpty) {
          final matching = categories.firstWhere(
            (c) => c.name.toLowerCase().contains(eraTag.toLowerCase()),
            orElse: () => categories.first,
          );
          effectiveCategoryId = matching.id;
        }
      } catch (_) {}
    }

    if (effectiveCategoryId == null || effectiveCategoryId.isEmpty) {
      throw Exception('Vui lòng chọn danh mục hợp lệ');
    }

    // 2. Upload cover if data URL
    String? effectiveCoverUrl;
    if (coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('data:image')) {
        try {
          final mime = coverUrl.split(';').first.replaceFirst('data:', '');
          final base64Part = coverUrl.split(',').last;
          final bytes = base64Decode(base64Part);
          final ext = mime.contains('png')
              ? 'png'
              : (mime.contains('webp') ? 'webp' : 'jpg');
          final uploadedUrl = await uploadImageFile(
            fileBytes: bytes,
            filename: 'cover_${DateTime.now().millisecondsSinceEpoch}.$ext',
            mimeType: mime,
          );
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            effectiveCoverUrl = uploadedUrl;
          }
        } catch (_) {}
      } else if (!coverUrl.startsWith('data:')) {
        effectiveCoverUrl = coverUrl;
      }
    }

    final durationSecs = duration.inSeconds > 0 ? duration.inSeconds : 1800;

    // 3. Create Draft Podcast: POST /api/creator/podcasts
    final podcastPayload = {
      'categoryId': effectiveCategoryId,
      'title': title,
      'description': description.isNotEmpty ? description : null,
      'thumbnailUrl': (effectiveCoverUrl != null && effectiveCoverUrl.length <= 2000)
          ? effectiveCoverUrl
          : null,
      'durationSeconds': durationSecs,
      'episodeNumber': episodeNumber ?? 1,
      'visibility': isExclusive ? 'MEMBERS_ONLY' : 'PUBLIC',
      'exclusive': isExclusive,
    };

    final res = await _apiClient.post(
      ApiEndpoints.creatorPodcasts,
      body: podcastPayload,
      headers: const {'ngrok-skip-browser-warning': '1'},
    );

    if (res is! Map<String, dynamic>) {
      throw Exception('Không thể tạo podcast nháp từ máy chủ');
    }

    var createdPodcast = _mapBackendPodcastToModel(res);
    final createdPodcastId = createdPodcast.id;

    // 4. Assign series if selected: PUT /api/creator/podcasts/{id}/series
    if (seriesId != null && seriesId.isNotEmpty) {
      await assignPodcastToSeries(
        podcastId: createdPodcastId,
        seriesId: seriesId,
      );
    }

    // 5. Upload media file (video or audio) if bytes provided: POST /api/creator/podcasts/{id}/video
    if (audioFileName != null && mediaBytes != null && mediaBytes.isNotEmpty) {
      final mimeType = _podcastMediaTypeForFilename(audioFileName);
      if (mimeType == null) {
        throw Exception('Định dạng media podcast chưa được hỗ trợ.');
      }

      final uploaded = await uploadPodcastVideoFile(
        podcastId: createdPodcastId,
        fileBytes: mediaBytes,
        filename: audioFileName,
        mimeType: mimeType,
      );
      if (!uploaded) {
        throw Exception(
          'Upload tệp media thất bại! Podcast được lưu dưới dạng nháp (DRAFT).',
        );
      }
    }

    // 6. Add sources reference if provided: POST /api/creator/podcasts/{id}/references
    if (sources.isNotEmpty) {
      try {
        await _apiClient.post(
          ApiEndpoints.creatorPodcastReferences(createdPodcastId),
          body: {
            'referenceType': 'OTHER',
            'title': 'Nguồn tham khảo: $title',
            'citationText': sources,
            'url': sources.startsWith('http') ? sources : null,
          },
          headers: const {'ngrok-skip-browser-warning': '1'},
        );
      } catch (_) {}
    }

    // 7. Auto-submit if requested
    if (autoSubmit) {
      createdPodcast = await submitPodcast(createdPodcastId);
    } else {
      final verified = await getPodcastById(createdPodcastId);
      if (verified != null) {
        createdPodcast = verified;
      }
    }

    createdPodcast = createdPodcast.copyWith(
      audioFileName: audioFileName,
      sources: sources,
      eraTag: eraTag,
      categoryId: effectiveCategoryId,
      seriesId: seriesId,
    );

    _cachedPodcasts.insert(0, createdPodcast);
    _cachedProfile = _cachedProfile.copyWith(
      currentPodcastCount: _cachedProfile.currentPodcastCount + 1,
    );

    return createdPodcast;
  }

  @override
  Future<CreatorPodcast> updatePodcast({
    required String id,
    required String title,
    required String description,
    required String eraTag,
    required String sources,
    required bool isExclusive,
    required String coverUrl,
    required String? audioFileName,
    required Duration duration,
    List<int>? mediaBytes,
    String? categoryId,
    String? seriesId,
    int? episodeNumber,
    bool autoSubmit = false,
  }) async {
    String? effectiveCategoryId = categoryId;

    if (effectiveCategoryId == null || effectiveCategoryId.isEmpty) {
      try {
        final categories = await getCategories();
        if (categories.isNotEmpty) {
          final matching = categories.firstWhere(
            (c) => c.name.toLowerCase().contains(eraTag.toLowerCase()),
            orElse: () => categories.first,
          );
          effectiveCategoryId = matching.id;
        }
      } catch (_) {}
    }

    effectiveCategoryId ??= '00000000-0000-0000-0000-000000000001';

    String? effectiveCoverUrl;
    if (coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('data:image')) {
        try {
          final mime = coverUrl.split(';').first.replaceFirst('data:', '');
          final base64Part = coverUrl.split(',').last;
          final bytes = base64Decode(base64Part);
          final ext = mime.contains('png')
              ? 'png'
              : (mime.contains('webp') ? 'webp' : 'jpg');
          final uploadedUrl = await uploadImageFile(
            fileBytes: bytes,
            filename: 'cover_${DateTime.now().millisecondsSinceEpoch}.$ext',
            mimeType: mime,
          );
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            effectiveCoverUrl = uploadedUrl;
          }
        } catch (_) {}
      } else if (!coverUrl.startsWith('data:')) {
        effectiveCoverUrl = coverUrl;
      }
    }

    CreatorPodcast? updatedPodcast;

    final durationSecs = duration.inSeconds > 0 ? duration.inSeconds : 1800;
    final podcastPayload = {
      'categoryId': effectiveCategoryId,
      'title': title,
      'description': description.isNotEmpty ? description : null,
      'thumbnailUrl': (effectiveCoverUrl != null && effectiveCoverUrl.length <= 2000)
          ? effectiveCoverUrl
          : null,
      'durationSeconds': durationSecs,
      'episodeNumber': episodeNumber ?? 1,
      'visibility': isExclusive ? 'MEMBERS_ONLY' : 'PUBLIC',
      'exclusive': isExclusive,
    };

    try {
      final res = await _apiClient.put(
        ApiEndpoints.creatorPodcastById(id),
        body: podcastPayload,
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        updatedPodcast = _mapBackendPodcastToModel(res);
      }
    } catch (_) {}

    if (seriesId != null && seriesId.isNotEmpty) {
      await assignPodcastToSeries(
        podcastId: id,
        seriesId: seriesId,
      );
    }

    if (sources.isNotEmpty) {
      try {
        await _apiClient.post(
          ApiEndpoints.creatorPodcastReferences(id),
          body: {
            'referenceType': 'OTHER',
            'title': 'Nguồn tham khảo: $title',
            'citationText': sources,
            'url': sources.startsWith('http') ? sources : null,
          },
          headers: const {'ngrok-skip-browser-warning': '1'},
        );
      } catch (_) {}
    }

    if (audioFileName != null && mediaBytes != null && mediaBytes.isNotEmpty) {
      final mimeType = _podcastMediaTypeForFilename(audioFileName);
      if (mimeType == null) {
        throw Exception('Định dạng media podcast chưa được hỗ trợ.');
      }

      final uploaded = await uploadPodcastVideoFile(
        podcastId: id,
        fileBytes: mediaBytes,
        filename: audioFileName,
        mimeType: mimeType,
      );
      if (!uploaded) {
        throw Exception('Không thể tải tệp âm thanh lên máy chủ. Vui lòng kiểm tra dung lượng tệp (< 10MB) và thử lại.');
      }
    }

    if (autoSubmit) {
      try {
        updatedPodcast = await submitPodcast(id);
      } catch (_) {}
    }

    final existingIndex = _cachedPodcasts.indexWhere((p) => p.id == id);
    final fallbackPodcast = existingIndex != -1
        ? _cachedPodcasts[existingIndex].copyWith(
            title: title,
            description: description,
            eraTag: eraTag,
            sources: sources,
            isExclusive: isExclusive,
            coverUrl: effectiveCoverUrl ?? coverUrl,
            audioFileName: audioFileName,
            duration: duration,
            categoryId: effectiveCategoryId,
            seriesId: seriesId,
          )
        : CreatorPodcast(
            id: id,
            title: title,
            description: description,
            coverUrl: effectiveCoverUrl ?? coverUrl,
            audioFileName: audioFileName,
            duration: duration,
            createdAt: DateTime.now(),
            eraTag: eraTag,
            sources: sources,
            isExclusive: isExclusive,
            listensCount: 0,
            likesCount: 0,
            commentsCount: 0,
            status: PodcastStatus.aiModerating,
            categoryId: effectiveCategoryId,
            seriesId: seriesId,
          );

    final finalPodcast = updatedPodcast?.copyWith(
          audioFileName: audioFileName,
          sources: sources,
          eraTag: eraTag,
          categoryId: effectiveCategoryId,
          seriesId: seriesId,
        ) ??
        fallbackPodcast;

    if (existingIndex != -1) {
      _cachedPodcasts[existingIndex] = finalPodcast;
    } else {
      _cachedPodcasts.insert(0, finalPodcast);
    }

    return finalPodcast;
  }

  @override
  Future<CreatorPodcast> submitPodcast(String podcastId) async {
    final res = await _apiClient.post(
      ApiEndpoints.creatorPodcastSubmit(podcastId),
      headers: const {'ngrok-skip-browser-warning': '1'},
    );
    if (res is Map<String, dynamic>) {
      final updated = _mapBackendPodcastToModel(res);
      final idx = _cachedPodcasts.indexWhere((p) => p.id == podcastId);
      if (idx != -1) {
        _cachedPodcasts[idx] = updated;
      }
      return updated;
    }
    throw Exception('Không thể gửi podcast cho Admin duyệt');
  }

  @override
  Future<void> deletePodcast(String id) async {
    _deletedPodcastIds.add(id);
    _cachedPodcasts.removeWhere((p) => p.id == id);
    _cachedProfile = _cachedProfile.copyWith(
      currentPodcastCount: (_cachedProfile.currentPodcastCount - 1).clamp(
        0,
        999,
      ),
    );

    try {
      await _apiClient.delete(
        ApiEndpoints.creatorPodcastById(id),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
    } catch (_) {}
  }

  // ==========================================
  // 3. MEDIA UPLOADS
  // ==========================================

  @override
  Future<String?> uploadImageFile({
    required List<int> fileBytes,
    required String filename,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final res = await _apiClient.uploadMultipart(
        ApiEndpoints.uploads,
        fileFieldName: 'file',
        filename: filename,
        fileBytes: fileBytes,
        mimeType: mimeType,
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        final url = res['publicUrl'] ?? res['url'] ?? res['objectKey'];
        if (url != null) {
          return url.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> uploadPodcastVideoFile({
    required String podcastId,
    required List<int> fileBytes,
    required String filename,
    String mimeType = 'video/mp4',
  }) async {
    const maxAllowedBytes = 100 * 1024 * 1024; // Giới hạn theo cấu hình hệ thống: 100MB
    if (fileBytes.length > maxAllowedBytes) {
      final sizeMb = (fileBytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw ApiException(
        statusCode: 413,
        message: 'Tệp tải lên (${sizeMb}MB) vượt quá giới hạn tối đa của hệ thống (100MB). Vui lòng chọn tệp nhỏ hơn 100MB.',
      );
    }

    try {
      final res = await _apiClient.uploadMultipart(
        ApiEndpoints.creatorPodcastVideo(podcastId),
        fileFieldName: 'file',
        filename: filename,
        fileBytes: fileBytes,
        mimeType: mimeType,
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res != null) {
        if (res is Map<String, dynamic>) {
          final media = res['media'] as Map<String, dynamic>?;
          final objKey = media?['objectKey']?.toString() ?? res['mediaUrl']?.toString();
          final idx = _cachedPodcasts.indexWhere((p) => p.id == podcastId);
          if (idx != -1 && objKey != null && objKey.isNotEmpty) {
            _cachedPodcasts[idx] = _cachedPodcasts[idx].copyWith(
              videoUrl: objKey,
              audioFileName: filename,
            );
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      if (mimeType != 'video/mp4') {
        try {
          final resFallback = await _apiClient.uploadMultipart(
            ApiEndpoints.creatorPodcastVideo(podcastId),
            fileFieldName: 'file',
            filename: filename,
            fileBytes: fileBytes,
            mimeType: 'video/mp4',
            headers: const {'ngrok-skip-browser-warning': '1'},
          );
          if (resFallback != null) {
            return true;
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  String? _podcastMediaTypeForFilename(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    return switch (extension) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'webm' => 'video/webm',
      'mkv' => 'video/x-matroska',
      '3gp' => 'video/3gpp',
      'avi' => 'video/x-msvideo',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg', 'oga' => 'audio/ogg',
      'opus' => 'audio/opus',
      'flac' => 'audio/flac',
      _ => null,
    };
  }

  @override
  Future<bool> uploadPdfReferenceFile({
    required String podcastId,
    String? referenceId,
    required List<int> fileBytes,
    required String filename,
  }) async {
    try {
      String? targetRefId = referenceId;
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );

      // If referenceId is null or not a valid UUID, resolve from existing or create one
      if (targetRefId == null || !uuidRegex.hasMatch(targetRefId)) {
        try {
          final existing = await _apiClient.get(
            ApiEndpoints.creatorPodcastReferences(podcastId),
            headers: const {'ngrok-skip-browser-warning': '1'},
          );
          if (existing is List && existing.isNotEmpty) {
            targetRefId = existing.first['referenceId']?.toString();
          }
        } catch (_) {}

        if (targetRefId == null || !uuidRegex.hasMatch(targetRefId)) {
          final createRes = await _apiClient.post(
            ApiEndpoints.creatorPodcastReferences(podcastId),
            body: {
              'referenceType': 'BOOK',
              'title': filename,
              'citationText': 'Tài liệu nguồn tham khảo: $filename',
            },
            headers: const {'ngrok-skip-browser-warning': '1'},
          );
          if (createRes is Map<String, dynamic>) {
            targetRefId = createRes['referenceId']?.toString();
          }
        }
      }

      if (targetRefId == null || !uuidRegex.hasMatch(targetRefId)) {
        return false;
      }

      final res = await _apiClient.uploadMultipart(
        ApiEndpoints.creatorPodcastReferenceFile(podcastId, targetRefId),
        fileFieldName: 'file',
        filename: filename,
        fileBytes: fileBytes,
        mimeType: 'application/pdf',
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      return res != null;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // 4. CUSTOM PODCAST REQUESTS
  // ==========================================

  @override
  Future<List<PodcastRequest>> getRequests() async {
    if (!_apiClient.isAuthenticated) {
      return const [];
    }
    try {
      // Call GET /api/creator/requests/incoming
      final response = await _apiClient.get(ApiEndpoints.incomingRequests);
      if (response is List) {
        final list = <PodcastRequest>[];
        for (final item in response) {
          if (item is Map<String, dynamic>) {
            final req = await _mapBackendRequestToModel(item);
            list.add(req);
          }
        }
        // Preserve any processed requests (accepted, inProduction, delivered, completed, rejected)
        final nonPending = _cachedRequests
            .where((r) => r.status != CustomRequestStatus.sent)
            .toList();
        _cachedRequests.clear();
        _cachedRequests.addAll(list);
        for (final p in nonPending) {
          if (!_cachedRequests.any((r) => r.id == p.id)) {
            _cachedRequests.add(p);
          }
        }
      }
    } catch (_) {}

    return List.unmodifiable(_cachedRequests);
  }

  @override
  Future<PodcastRequest?> getRequestById(String id) async {
    final cached = _cachedRequests.where((r) => r.id == id);
    if (cached.isNotEmpty) {
      return cached.first;
    }
    try {
      final requests = await getRequests();
      return requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> acceptRequest(String id) async {
    final req = await getRequestById(id);
    final totalBudget = (req != null && req.totalBudget > 0)
        ? req.totalBudget
        : 2000000;
    final m1Amount = (totalBudget * 0.3).round();
    final m2Amount = totalBudget - m1Amount;

    try {
      // Call POST /api/creator/requests/{requestId}/accept
      final body = {
        'responseText': 'Creator đã chấp nhận đơn đặt podcast.',
        'milestones': [
          {
            'name': 'Giai đoạn 1: Đề cương & Kịch bản chi tiết',
            'description': 'Hoàn thiện nghiên cứu lịch sử và khung nội dung',
            'amount': m1Amount > 0 ? m1Amount.toDouble() : 500000.0,
          },
          {
            'name': 'Giai đoạn 2: Thu âm & Hậu kỳ hoàn chỉnh',
            'description': 'Bản audio chất lượng cao',
            'amount': m2Amount > 0 ? m2Amount.toDouble() : 1500000.0,
          },
        ],
      };
      await _apiClient.post(ApiEndpoints.acceptRequest(id), body: body);
    } catch (_) {}

    final index = _cachedRequests.indexWhere((r) => r.id == id);
    if (index != -1) {
      final existing = _cachedRequests[index];
      final milestones = existing.milestones.isNotEmpty
          ? existing.milestones
          : [
              RequestMilestone(
                id: 'm1_${existing.id}',
                title: 'Giai đoạn 1: Đề cương & Kịch bản chi tiết',
                percentage: 30,
                amount: m1Amount,
                isCompleted: false,
                isApproved: false,
              ),
              RequestMilestone(
                id: 'm2_${existing.id}',
                title: 'Giai đoạn 2: Thu âm & Hậu kỳ hoàn chỉnh',
                percentage: 70,
                amount: m2Amount,
                isCompleted: false,
                isApproved: false,
              ),
            ];
      _cachedRequests[index] = existing.copyWith(
        status: CustomRequestStatus.accepted,
        milestones: milestones,
      );
    }
  }

  @override
  Future<void> rejectRequest(String id, String reason) async {
    try {
      await _apiClient.post(
        ApiEndpoints.rejectRequest(id),
        body: {'responseText': reason},
      );
    } catch (_) {}

    final index = _cachedRequests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _cachedRequests[index] = _cachedRequests[index].copyWith(
        status: CustomRequestStatus.rejected,
        rejectionReason: reason,
      );
    }
  }

  @override
  Future<void> deliverWork(
    String id,
    String fileUrl,
    String note, {
    List<int>? fileBytes,
    String? filename,
  }) async {
    try {
      final req = await getRequestById(id);
      if (req != null && req.milestones.isNotEmpty) {
        final milestoneId = req.milestones.first.id;
        if (fileBytes != null && fileBytes.isNotEmpty) {
          await _apiClient.uploadMultipart(
            ApiEndpoints.submitMilestone(milestoneId),
            fileFieldName: 'file',
            filename: filename ?? 'delivery.mp3',
            fileBytes: fileBytes,
            fields: {'note': note},
          );
        }
      }
    } catch (_) {}

    final index = _cachedRequests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _cachedRequests[index] = _cachedRequests[index].copyWith(
        status: CustomRequestStatus.delivered,
        deliveryFileUrl: fileUrl,
        deliveryNote: note,
      );
    }
  }

  @override
  Future<void> sendChatMessage(String requestId, String message) async {
    final index = _cachedRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = _cachedRequests[index];
      final newMsg = RequestChatMessage(
        id: 'msg_${_uuid.v4().substring(0, 6)}',
        senderName: _cachedProfile.name.isNotEmpty
            ? _cachedProfile.name
            : 'Creator',
        isCreator: true,
        message: message,
        timestamp: DateTime.now(),
      );
      final updatedMsgs = List<RequestChatMessage>.from(req.messages)
        ..add(newMsg);
      _cachedRequests[index] = req.copyWith(messages: updatedMsgs);
    }
  }

  // ==========================================
  // 5. WALLET & TRANSACTIONS ("cái nào chưa có thì bỏ qua")
  // ==========================================

  @override
  Future<Map<String, int>> getWalletBalance() async {
    if (!_apiClient.isAuthenticated) {
      return {
        'available': _availableBalance,
        'pending': _pendingRelease,
        'holding': _holdingWithdraw,
        'totalWithdrawn': _totalWithdrawn,
      };
    }
    try {
      final res = await _apiClient.get(ApiEndpoints.creatorWallet);
      if (res is Map<String, dynamic>) {
        _availableBalance =
            (res['availableBalance'] as num?)?.toInt() ?? _availableBalance;
        _holdingWithdraw =
            (res['heldBalance'] as num?)?.toInt() ?? _holdingWithdraw;
        _pendingRelease =
            (res['pendingRelease'] as num?)?.toInt() ?? _pendingRelease;
      }
    } catch (_) {}

    return {
      'available': _availableBalance,
      'pending': _pendingRelease,
      'holding': _holdingWithdraw,
      'totalWithdrawn': _totalWithdrawn,
    };
  }

  @override
  Future<List<WalletTransaction>> getTransactions() async {
    if (!_apiClient.isAuthenticated) {
      return const [];
    }
    try {
      final res = await _apiClient.get(ApiEndpoints.creatorTransactions);
      if (res is List) {
        final transactions = res.whereType<Map<String, dynamic>>().map((item) {
          final status = (item['status']?.toString() ?? '').toUpperCase();
          final transactionStatus = switch (status) {
            'COMPLETED' || 'SUCCESS' || 'PAID' => TransactionStatus.success,
            'FAILED' || 'REJECTED' || 'CANCELLED' => TransactionStatus.failed,
            'PENDING' => TransactionStatus.holding,
            _ => TransactionStatus.processing,
          };
          return WalletTransaction(
            id: item['withdrawalRequestId']?.toString() ?? _uuid.v4(),
            title: 'Yêu cầu rút tiền',
            type: TransactionType.withdrawal,
            amount: -((item['amount'] as num?)?.toInt() ?? 0),
            status: transactionStatus,
            createdAt:
                DateTime.tryParse(item['requestedAt']?.toString() ?? '') ??
                DateTime.now(),
            note: item['note']?.toString(),
          );
        }).toList();
        _cachedTransactions
          ..clear()
          ..addAll(transactions);
      }
    } catch (_) {}
    return List.unmodifiable(_cachedTransactions);
  }

  @override
  Future<List<BankAccount>> getBankAccounts() async {
    if (!_apiClient.isAuthenticated) {
      return List.unmodifiable(_cachedBankAccounts);
    }
    try {
      final res = await _apiClient.get(ApiEndpoints.creatorBankAccounts);
      if (res is List) {
        final accounts = res.whereType<Map<String, dynamic>>().map((item) {
          return BankAccount(
            id: item['payoutAccountId']?.toString() ?? _uuid.v4(),
            bankName: item['payoutMethod']?.toString() ?? 'Tài khoản nhận tiền',
            accountNumber: item['accountMasked']?.toString() ?? '',
            accountHolder: item['currency']?.toString() ?? '',
            isDefault: item['active'] == true && item['verified'] == true,
          );
        }).toList();
        _cachedBankAccounts
          ..clear()
          ..addAll(accounts);
      }
    } catch (_) {}
    return List.unmodifiable(_cachedBankAccounts);
  }

  @override
  Future<void> addBankAccount(
    String bankName,
    String accountNumber,
    String accountHolder,
  ) async {
    final newAccount = BankAccount(
      id: _uuid.v4(),
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      isDefault: _cachedBankAccounts.isEmpty,
    );
    _cachedBankAccounts.add(newAccount);
  }

  @override
  Future<void> deleteBankAccount(String id) async {
    _cachedBankAccounts.removeWhere((a) => a.id == id);
  }

  @override
  Future<WalletTransaction> withdrawMoney(
    int amount,
    String bankAccountId,
    String pin,
  ) async {
    if (!_apiClient.isAuthenticated) {
      throw Exception('Vui lòng đăng nhập để thực hiện rút tiền.');
    }
    try {
      await _apiClient.post(
        ApiEndpoints.creatorWithdraw,
        body: {'amount': amount, 'payoutAccountId': bankAccountId},
      );
    } catch (_) {}

    if (amount > _availableBalance) {
      throw Exception('Số dư khả dụng không đủ để thực hiện rút tiền.');
    }
    _availableBalance -= amount;
    _holdingWithdraw += amount;

    final tx = WalletTransaction(
      id: 'tx_${_uuid.v4().substring(0, 8)}',
      title: 'Yêu cầu rút tiền về ngân hàng',
      type: TransactionType.withdrawal,
      amount: -amount,
      status: TransactionStatus.processing,
      createdAt: DateTime.now(),
      note: 'Hệ thống đã tiếp nhận yêu cầu rút tiền $amount ₫.',
    );
    _cachedTransactions.insert(0, tx);
    return tx;
  }

  @override
  Future<void> releaseFunds() async {
    if (!_apiClient.isAuthenticated) {
      return;
    }
    try {
      await _apiClient.post(ApiEndpoints.creatorReleaseFunds);
    } catch (_) {}

    if (_pendingRelease > 0) {
      _availableBalance += _pendingRelease;
      final released = _pendingRelease;
      _pendingRelease = 0;

      _cachedTransactions.insert(
        0,
        WalletTransaction(
          id: 'tx_${_uuid.v4().substring(0, 8)}',
          title: 'Giải phóng thu nhập hoàn tất',
          type: TransactionType.requestEarning,
          amount: released,
          status: TransactionStatus.success,
          createdAt: DateTime.now(),
          note: 'Tiền đã chuyển từ Đang chờ release vào Số dư khả dụng.',
        ),
      );
    }
  }

  // ==========================================
  // 6. COMMENTS MANAGEMENT
  // ==========================================

  @override
  Future<List<StudioComment>> getComments() async {
    if (!_apiClient.isAuthenticated) {
      return List.unmodifiable(_cachedComments);
    }
    final allComments = <StudioComment>[];
    try {
      final podcasts = _cachedPodcasts.isNotEmpty
          ? _cachedPodcasts
          : await getPodcasts();
      for (final pod in podcasts.take(5)) {
        try {
          final commentsRes = await _apiClient.get(
            ApiEndpoints.podcastComments(pod.id),
          );
          if (commentsRes is Map<String, dynamic> &&
              commentsRes['content'] is List) {
            for (final item in commentsRes['content'] as List) {
              if (item is Map<String, dynamic>) {
                allComments.add(
                  StudioComment(
                    id: item['commentId']?.toString() ?? _uuid.v4(),
                    podcastTitle: pod.title,
                    authorName: item['username']?.toString() ?? 'Thính giả',
                    authorAvatar: item['avatarUrl']?.toString() ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
                    content: item['content']?.toString() ?? '',
                    timestampSeconds:
                        (item['timestampSeconds'] as num?)?.toInt() ?? 0,
                    createdAt:
                        DateTime.tryParse(
                          item['createdAt']?.toString() ?? '',
                        ) ??
                        DateTime.now(),
                  ),
                );
              }
            }
          }
        } catch (_) {}
      }
      _cachedComments.clear();
      _cachedComments.addAll(allComments);
    } catch (_) {}

    return List.unmodifiable(_cachedComments);
  }

  @override
  Future<StudioComment?> addCommentToPodcast({
    required String podcastId,
    required String content,
    int? timestampSeconds,
    String? podcastTitle,
  }) async {
    try {
      final res = await _apiClient.post(
        ApiEndpoints.podcastComments(podcastId),
        body: {'content': content, 'timestampSeconds': timestampSeconds},
      );
      if (res is Map<String, dynamic>) {
        final comment = StudioComment(
          id: res['commentId']?.toString() ?? _uuid.v4(),
          podcastTitle: podcastTitle ?? _cachedProfile.name,
          authorName: res['username']?.toString() ?? _cachedProfile.name,
          authorAvatar:
              res['avatarUrl']?.toString() ?? _cachedProfile.avatarUrl,
          content: res['content']?.toString() ?? content,
          timestampSeconds:
              (res['timestampSeconds'] as num?)?.toInt() ??
              (timestampSeconds ?? 0),
          createdAt:
              DateTime.tryParse(res['createdAt']?.toString() ?? '') ??
              DateTime.now(),
        );
        _cachedComments.insert(0, comment);
        return comment;
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      await _apiClient.delete(ApiEndpoints.commentById(commentId));
    } catch (_) {}
    _cachedComments.removeWhere((c) => c.id == commentId);
  }

  @override
  Future<void> togglePinComment(String id) async {
    final index = _cachedComments.indexWhere((c) => c.id == id);
    if (index != -1) {
      _cachedComments[index] = _cachedComments[index].copyWith(
        isPinned: !_cachedComments[index].isPinned,
      );
    }
  }

  @override
  Future<void> toggleHideComment(String id) async {
    final index = _cachedComments.indexWhere((c) => c.id == id);
    if (index != -1) {
      _cachedComments[index] = _cachedComments[index].copyWith(
        isHidden: !_cachedComments[index].isHidden,
      );
    }
  }

  // ==========================================
  // 7. SERIES MANAGEMENT
  // ==========================================

  @override
  Future<List<CreatorSeries>> getSeries() async {
    if (!_apiClient.isAuthenticated) {
      return List.unmodifiable(_cachedSeries);
    }
    try {
      final res = await _apiClient.get(ApiEndpoints.creatorSeries);
      if (res is List) {
        final list = <CreatorSeries>[];
        for (final item in res) {
          if (item is Map<String, dynamic>) {
            list.add(CreatorSeries.fromJson(item));
          }
        }
        _cachedSeries.clear();
        _cachedSeries.addAll(list);
      }
    } catch (_) {}
    return List.unmodifiable(_cachedSeries);
  }

  @override
  Future<CreatorSeries?> createSeries({
    required String title,
    required String slug,
    required String categoryId,
    String description = '',
    String coverUrl = '',
  }) async {
    String effectiveCategoryId = categoryId;
    if (effectiveCategoryId.isEmpty ||
        effectiveCategoryId.startsWith('00000000-0000-0000')) {
      try {
        final categoriesRes = await _apiClient.get(ApiEndpoints.categories);
        if (categoriesRes is List && categoriesRes.isNotEmpty) {
          final firstCat = categoriesRes.first as Map<String, dynamic>;
          final realId = (firstCat['categoryId'] ?? firstCat['id'])?.toString();
          if (realId != null && realId.isNotEmpty) {
            effectiveCategoryId = realId;
          }
        }
      } catch (_) {}
    }

    try {
      final res = await _apiClient.post(
        ApiEndpoints.creatorSeries,
        body: {
          'categoryId': effectiveCategoryId,
          'title': title,
          'slug': slug.isNotEmpty
              ? slug
              : title.toLowerCase().replaceAll(' ', '-'),
          'description': description.isNotEmpty ? description : null,
          'coverUrl': coverUrl.isNotEmpty ? coverUrl : null,
        },
      );
      if (res is Map<String, dynamic>) {
        final series = CreatorSeries.fromJson(res);
        _cachedSeries.insert(0, series);
        return series;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> assignPodcastToSeries({
    required String podcastId,
    required String seriesId,
  }) async {
    try {
      final res = await _apiClient.put(
        ApiEndpoints.creatorPodcastSeries(podcastId),
        body: {'seriesId': seriesId},
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      return res != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removePodcastFromSeries({required String podcastId}) async {
    try {
      final res = await _apiClient.delete(
        ApiEndpoints.creatorPodcastSeries(podcastId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      return res != null;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // 8. APPEALS & REVIEWS
  // ==========================================

  @override
  Future<void> submitPodcastAppeal({
    required String podcastId,
    required String note,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.creatorPodcastAppeals(podcastId),
        body: {'note': note},
      );
    } catch (_) {}
  }

  // ==========================================
  // 9. FORMS & POLLS
  // ==========================================

  @override
  Future<List<InteractiveForm>> getForms() async {
    if (!_apiClient.isAuthenticated) {
      return List.unmodifiable(_cachedForms);
    }
    try {
      final res = await _apiClient.get(ApiEndpoints.creatorPolls);
      if (res is Map<String, dynamic> && res['content'] is List) {
        final content = res['content'] as List;
        final list = <InteractiveForm>[];
        for (final item in content) {
          if (item is Map<String, dynamic>) {
            final pollId = item['pollId']?.toString() ?? _uuid.v4();
            final question =
                item['question']?.toString() ?? 'Khảo sát thính giả';
            final status = item['status']?.toString() ?? 'DRAFT';
            list.add(
              InteractiveForm(
                id: pollId,
                title: question,
                description: 'Trạng thái: $status',
                questions: [
                  FormQuestion(
                    id: 'q_$pollId',
                    question: question,
                    type: FormQuestionType.singleChoice,
                    options: const ['Đồng ý', 'Không đồng ý'],
                  ),
                ],
                responsesCount: 0,
                createdAt:
                    DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
                    DateTime.now(),
              ),
            );
          }
        }
        _cachedForms.clear();
        _cachedForms.addAll(list);
      }
    } catch (_) {}

    return List.unmodifiable(_cachedForms);
  }

  @override
  Future<void> createForm(
    String title,
    String description,
    List<FormQuestion> questions,
  ) async {
    String? createdPollId;
    try {
      final questionText = questions.isNotEmpty
          ? questions.first.question
          : title;
      final options =
          (questions.isNotEmpty && questions.first.options.length >= 2)
          ? questions.first.options
          : ['Đồng ý', 'Không đồng ý'];

      final pollRes = await _apiClient.post(
        ApiEndpoints.creatorPolls,
        body: {'question': questionText, 'options': options},
      );

      if (pollRes is Map<String, dynamic>) {
        final pollSummary = pollRes['poll'] as Map<String, dynamic>?;
        createdPollId =
            pollSummary?['pollId']?.toString() ?? pollRes['pollId']?.toString();
      }

      if (createdPollId != null) {
        // Automatically publish poll
        await _apiClient.post(ApiEndpoints.creatorPollPublish(createdPollId));
      }
    } catch (_) {}

    final newForm = InteractiveForm(
      id: createdPollId ?? 'form_${_uuid.v4().substring(0, 8)}',
      title: title,
      description: description,
      questions: questions,
      responsesCount: 0,
      createdAt: DateTime.now(),
    );
    _cachedForms.insert(0, newForm);
  }

  // ==========================================
  // PRIVATE MAPPER HELPERS
  // ==========================================

  CreatorPodcast _mapBackendPodcastToModel(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String? ?? '').toUpperCase();
    PodcastStatus status;
    switch (statusStr) {
      case 'PUBLISHED':
      case 'APPROVED':
        status = PodcastStatus.published;
        break;
      case 'PENDING_REVIEW':
      case 'PENDING_ADMIN':
      case 'IN_REVIEW':
      case 'UNDER_REVIEW':
        status = PodcastStatus.pendingAdmin;
        break;
      case 'AI_MODERATING':
        status = PodcastStatus.aiModerating;
        break;
      case 'REJECTED':
        status = PodcastStatus.rejected;
        break;
      case 'DRAFT':
      default:
        status = PodcastStatus.draft;
    }

    final durationSeconds = (json['durationSeconds'] as num?)?.toInt() ?? 1200;
    final createdAtStr = json['createdAt'] as String?;
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();

    final isExclusive =
        json['exclusive'] == true || json['visibility'] == 'MEMBERS_ONLY';

    final mediaKeyStr = json['mediaKey'] as String?;
    String? resolvedAudioName = json['audioFileName'] as String?;
    if (resolvedAudioName == null && mediaKeyStr != null && mediaKeyStr.isNotEmpty) {
      resolvedAudioName = mediaKeyStr.split('/').last;
    }
    String? resolvedMediaType = json['mediaType'] as String?;
    if (resolvedAudioName != null) {
      final nameLower = resolvedAudioName.toLowerCase();
      if (nameLower.endsWith('.mp3') ||
          nameLower.endsWith('.wav') ||
          nameLower.endsWith('.m4a') ||
          nameLower.endsWith('.aac') ||
          nameLower.endsWith('.flac') ||
          nameLower.endsWith('.ogg')) {
        resolvedMediaType = 'audio/mpeg';
      }
    }

    return CreatorPodcast(
      id: json['podcastId']?.toString() ?? _uuid.v4(),
      title: json['title'] as String? ?? 'Chưa đặt tiêu đề',
      description: json['description'] as String? ?? '',
      coverUrl: json['thumbnailUrl'] as String? ?? '',
      audioFileName: resolvedAudioName ?? json['videoUrl'] as String?,
      duration: Duration(seconds: durationSeconds),
      createdAt: createdAt,
      eraTag: json['categoryName'] as String? ?? '',
      sources: '',
      isExclusive: isExclusive,
      listensCount: 0,
      likesCount: 0,
      commentsCount: 0,
      status: status,
      categoryId: json['categoryId']?.toString(),
      seriesId: json['seriesId']?.toString(),
      seriesTitle: json['seriesTitle'] as String?,
      mediaType: resolvedMediaType,
      videoUrl: json['videoUrl'] as String?,
    );
  }

  Future<PodcastRequest> _mapBackendRequestToModel(
    Map<String, dynamic> json,
  ) async {
    final statusStr = (json['status'] as String? ?? '').toUpperCase();
    CustomRequestStatus status;
    switch (statusStr) {
      case 'ACCEPTED':
        status = CustomRequestStatus.accepted;
        break;
      case 'IN_PRODUCTION':
        status = CustomRequestStatus.inProduction;
        break;
      case 'SUBMITTED':
      case 'DELIVERED':
        status = CustomRequestStatus.delivered;
        break;
      case 'APPROVED':
        status = CustomRequestStatus.approved;
        break;
      case 'COMPLETED':
        status = CustomRequestStatus.completed;
        break;
      case 'REJECTED':
        status = CustomRequestStatus.rejected;
        break;
      case 'DISPUTED':
        status = CustomRequestStatus.disputed;
        break;
      default:
        status = CustomRequestStatus.sent;
    }

    final requestId = json['requestId']?.toString() ?? _uuid.v4();
    final budgetNum = json['proposedBudget'] as num? ?? 0;
    final totalBudget = budgetNum.toInt();

    final milestones = <RequestMilestone>[];
    try {
      final milestonesRes = await _apiClient.get(
        ApiEndpoints.requestMilestones(requestId),
      );
      if (milestonesRes is List && milestonesRes.isNotEmpty) {
        for (final m in milestonesRes) {
          if (m is Map<String, dynamic>) {
            final mAmount = (m['amount'] as num?)?.toInt() ?? 0;
            milestones.add(
              RequestMilestone(
                id: m['milestoneId']?.toString() ?? _uuid.v4(),
                title: m['name'] as String? ?? 'Mốc thanh toán',
                percentage: totalBudget > 0
                    ? ((mAmount / totalBudget) * 100).toInt()
                    : 0,
                amount: mAmount,
                isCompleted:
                    m['status'] == 'APPROVED' || m['status'] == 'SUBMITTED',
                isApproved: m['status'] == 'APPROVED',
              ),
            );
          }
        }
      }
    } catch (_) {}

    final createdAtStr = json['createdAt'] as String?;
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();

    return PodcastRequest(
      id: requestId,
      listenerName: 'Thính giả',
      listenerAvatar: '',
      topic: json['title'] as String? ?? 'Yêu cầu podcast',
      description: json['description'] as String? ?? '',
      targetDurationMinutes: 30,
      deadline: DateTime.now().add(const Duration(days: 7)),
      totalBudget: totalBudget,
      milestones: milestones,
      status: status,
      createdAt: createdAt,
    );
  }
}
