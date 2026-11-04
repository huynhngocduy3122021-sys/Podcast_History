import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'package:uuid/uuid.dart';
import 'package:podcast_history/core/network/api_client.dart';
import 'package:podcast_history/core/network/api_endpoints.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_livestream_model.dart';
import 'package:podcast_history/features/creator_studio/domain/creator_repository.dart';

class _CoverUploadData {
  const _CoverUploadData({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final List<int> bytes;
  final String filename;
  final String mimeType;
}

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
  int _totalWithdrawn = 0;

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

    try {
      final sub = await getMySystemSubscription();
      if (sub != null) {
        _cachedProfile = _cachedProfile.copyWith(isPremium: sub.isActive);
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
    try {
      final plans = await getSystemPlans();
      final paidPlan = plans.firstWhere(
        (p) => p.isPaid && p.isActive,
        orElse: () =>
            plans.firstWhere((p) => p.isPaid, orElse: () => plans.first),
      );
      if (paidPlan.planId.isNotEmpty) {
        await subscribeSystemPlan(paidPlan.planId);
      }
    } catch (_) {}
    _cachedProfile = _cachedProfile.copyWith(isPremium: true);
  }

  @override
  Future<List<CreatorSystemPlan>> getSystemPlans() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.creatorSystemPlans);
      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map(CreatorSystemPlan.fromJson)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<CreatorSystemSubscription?> getMySystemSubscription() async {
    if (!_apiClient.isAuthenticated) return null;
    try {
      final response = await _apiClient.get(ApiEndpoints.creatorSystemPlansMe);
      if (response is Map<String, dynamic>) {
        final sub = CreatorSystemSubscription.fromJson(response);
        if (sub.isActive) {
          _cachedProfile = _cachedProfile.copyWith(isPremium: true);
        }
        return sub;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<CreatorCheckoutPayment> subscribeSystemPlan(String planId) async {
    final response = await _apiClient.post(
      ApiEndpoints.creatorSystemPlanSubscribe(planId),
    );
    if (response is Map<String, dynamic>) {
      return CreatorCheckoutPayment.fromJson(response);
    }
    throw ApiException(
      statusCode: 500,
      message: 'Phản hồi tạo thanh toán gói không hợp lệ.',
    );
  }

  @override
  Future<CreatorCheckoutPayment> getCheckoutStatus(String checkoutId) async {
    final response = await _apiClient.get(ApiEndpoints.meCheckout(checkoutId));
    if (response is Map<String, dynamic>) {
      final checkout = CreatorCheckoutPayment.fromJson(response);
      if (checkout.isPaid) {
        _cachedProfile = _cachedProfile.copyWith(isPremium: true);
      }
      return checkout;
    }
    throw ApiException(
      statusCode: 500,
      message: 'Phản hồi kiểm tra thanh toán không hợp lệ.',
    );
  }

  @override
  Future<void> cancelPendingCheckout() async {
    await _apiClient.delete(
      ApiEndpoints.creatorPendingCheckout,
      headers: const {'ngrok-skip-browser-warning': '1'},
    );
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
                listensCount: existing.listensCount > 0
                    ? existing.listensCount
                    : mapped.listensCount,
                likesCount: existing.likesCount,
                likedByMe: existing.likedByMe,
                commentsCount: existing.commentsCount,
                rejectReason: mapped.status == PodcastStatus.rejected
                    ? (mapped.rejectReason ?? existing.rejectReason)
                    : null,
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
            if (mapped.status == PodcastStatus.published) {
              try {
                final likeRes = await _apiClient.get(
                  ApiEndpoints.podcastLikes(mapped.id),
                  headers: const {'ngrok-skip-browser-warning': '1'},
                );
                if (likeRes is Map<String, dynamic>) {
                  final likeCount =
                      (likeRes['likeCount'] as num?)?.toInt() ?? 0;
                  final likedByMe = likeRes['likedByMe'] == true;
                  mapped = mapped.copyWith(
                    likesCount: likeCount,
                    likedByMe: likedByMe,
                  );
                }
              } catch (_) {}

              try {
                final cmtRes = await _apiClient.get(
                  '${ApiEndpoints.podcastComments(mapped.id)}?page=0&size=1',
                  headers: const {'ngrok-skip-browser-warning': '1'},
                );
                if (cmtRes is Map<String, dynamic> &&
                    cmtRes['totalElements'] is num) {
                  mapped = mapped.copyWith(
                    commentsCount: (cmtRes['totalElements'] as num).toInt(),
                  );
                }
              } catch (_) {}
            }
            list.add(mapped);
          }
        }

        // Fetch dashboard metrics to synchronize creator's total listens with podcasts
        int totalCreatorListens = 0;
        try {
          final dashRes = await _apiClient.get(
            ApiEndpoints.creatorDashboard(period: '7d'),
            headers: const {'ngrok-skip-browser-warning': '1'},
          );
          if (dashRes is Map<String, dynamic> &&
              dashRes['metrics'] is Map<String, dynamic>) {
            final m = dashRes['metrics'] as Map<String, dynamic>;
            totalCreatorListens =
                (m['totalListens'] as num?)?.toInt() ??
                (m['views'] as num?)?.toInt() ??
                0;
          }
        } catch (_) {}

        if (totalCreatorListens > 0) {
          final publishedIndices = <int>[];
          for (int i = 0; i < list.length; i++) {
            if (list[i].status == PodcastStatus.published) {
              publishedIndices.add(i);
            }
          }

          if (publishedIndices.length == 1) {
            final idx = publishedIndices.first;
            list[idx] = list[idx].copyWith(listensCount: totalCreatorListens);
          } else if (publishedIndices.length > 1) {
            final totalCurrent = publishedIndices.fold<int>(
              0,
              (sum, i) => sum + list[i].listensCount,
            );
            if (totalCurrent == 0) {
              final idx = publishedIndices.first;
              list[idx] = list[idx].copyWith(listensCount: totalCreatorListens);
            }
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
          final existing = _cachedPodcasts[idx];
          final resolved = mapped.copyWith(
            likesCount: existing.likesCount,
            likedByMe: existing.likedByMe,
            commentsCount: existing.commentsCount,
            listensCount: existing.listensCount > 0
                ? existing.listensCount
                : mapped.listensCount,
          );
          _cachedPodcasts[idx] = resolved;
          return resolved;
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

    // Create the draft first so the uploaded cover can be linked to its podcast.
    final coverUpload = _prepareCoverUpload(coverUrl);
    final effectiveCoverUrl = coverUpload == null
        ? _externalCoverUrl(coverUrl)
        : null;

    final durationSecs = duration.inSeconds > 0 ? duration.inSeconds : 1800;

    // 3. Create Draft Podcast: POST /api/creator/podcasts
    final podcastPayload = {
      'categoryId': effectiveCategoryId,
      'title': title,
      'description': description.isNotEmpty ? description : null,
      'thumbnailUrl':
          (effectiveCoverUrl != null && effectiveCoverUrl.length <= 2000)
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

    if (coverUpload != null) {
      final withCover = await uploadPodcastThumbnailFile(
        podcastId: createdPodcastId,
        fileBytes: coverUpload.bytes,
        filename: coverUpload.filename,
        mimeType: coverUpload.mimeType,
      );
      if (withCover == null) {
        throw Exception(
          'Upload ảnh bìa thất bại; podcast vẫn được lưu ở dạng nháp.',
        );
      }
      createdPodcast = withCover;
    }

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

    final coverUpload = _prepareCoverUpload(coverUrl);
    String? effectiveCoverUrl = coverUpload == null
        ? _externalCoverUrl(coverUrl)
        : null;

    if (coverUpload != null) {
      final withCover = await uploadPodcastThumbnailFile(
        podcastId: id,
        fileBytes: coverUpload.bytes,
        filename: coverUpload.filename,
        mimeType: coverUpload.mimeType,
      );
      if (withCover == null || withCover.coverUrl.isEmpty) {
        throw Exception('Upload ảnh bìa thất bại; podcast chưa được cập nhật.');
      }
      effectiveCoverUrl = withCover.coverUrl;
    }

    CreatorPodcast? updatedPodcast;

    final durationSecs = duration.inSeconds > 0 ? duration.inSeconds : 1800;
    final podcastPayload = {
      'categoryId': effectiveCategoryId,
      'title': title,
      'description': description.isNotEmpty ? description : null,
      'thumbnailUrl':
          (effectiveCoverUrl != null && effectiveCoverUrl.length <= 2000)
          ? effectiveCoverUrl
          : null,
      'durationSeconds': durationSecs,
      'episodeNumber': episodeNumber ?? 1,
      'visibility': isExclusive ? 'MEMBERS_ONLY' : 'PUBLIC',
      'exclusive': isExclusive,
    };

    final res = await _apiClient.put(
      ApiEndpoints.creatorPodcastById(id),
      body: podcastPayload,
      headers: const {'ngrok-skip-browser-warning': '1'},
    );
    if (res is! Map<String, dynamic>) {
      throw Exception('Máy chủ không xác nhận cập nhật podcast.');
    }
    updatedPodcast = _mapBackendPodcastToModel(res);

    if (seriesId != null && seriesId.isNotEmpty) {
      await assignPodcastToSeries(podcastId: id, seriesId: seriesId);
    } else {
      await removePodcastFromSeries(podcastId: id);
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
        throw Exception(
          'Không thể tải tệp âm thanh lên máy chủ. Vui lòng kiểm tra dung lượng tệp (< 10MB) và thử lại.',
        );
      }
    }

    if (autoSubmit) {
      updatedPodcast = await submitPodcast(id);
    }

    final existingIndex = _cachedPodcasts.indexWhere((p) => p.id == id);
    final finalPodcast = updatedPodcast.copyWith(
          audioFileName: audioFileName,
          sources: sources,
          eraTag: eraTag,
          categoryId: effectiveCategoryId,
          seriesId: seriesId,
        );

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
      final updated = _mapBackendPodcastToModel(res)
          .copyWith(status: PodcastStatus.pendingAdmin, rejectReason: null);
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
  Future<CreatorPodcast?> uploadPodcastThumbnailFile({
    required String podcastId,
    required List<int> fileBytes,
    required String filename,
    String mimeType = 'image/jpeg',
  }) async {
    final res = await _apiClient.uploadMultipart(
      ApiEndpoints.creatorPodcastThumbnail(podcastId),
      fileFieldName: 'file',
      filename: filename,
      fileBytes: fileBytes,
      mimeType: mimeType,
      headers: const {'ngrok-skip-browser-warning': '1'},
    );
    if (res is! Map<String, dynamic>) {
      return null;
    }

    final mapped = _mapBackendPodcastToModel(res);
    final index = _cachedPodcasts.indexWhere(
      (podcast) => podcast.id == podcastId,
    );
    if (index == -1) {
      _cachedPodcasts.add(mapped);
    } else {
      _cachedPodcasts[index] = mapped.copyWith(
        audioFileName: _cachedPodcasts[index].audioFileName,
        sources: _cachedPodcasts[index].sources,
        eraTag: _cachedPodcasts[index].eraTag,
      );
    }
    return mapped;
  }

  _CoverUploadData? _prepareCoverUpload(String coverUrl) {
    final value = coverUrl.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('data:')) {
      return null;
    }
    if (!value.startsWith('data:image/')) {
      throw Exception('Ảnh bìa phải là data URL image hợp lệ.');
    }

    final commaIndex = value.indexOf(',');
    final semicolonIndex = value.indexOf(';');
    if (commaIndex <= semicolonIndex || semicolonIndex < 5) {
      throw Exception('Dữ liệu ảnh bìa không hợp lệ.');
    }

    final mimeType = value.substring(5, semicolonIndex).toLowerCase();
    if (mimeType == 'image/svg+xml') {
      throw Exception('Không hỗ trợ SVG làm ảnh bìa.');
    }
    final bytes = base64Decode(value.substring(commaIndex + 1));
    if (bytes.isEmpty) {
      throw Exception('Ảnh bìa rỗng.');
    }

    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/avif' => 'avif',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      'image/jpeg' || 'image/jpg' => 'jpg',
      _ => 'jpg',
    };

    return _CoverUploadData(
      bytes: bytes,
      filename: 'cover_${DateTime.now().millisecondsSinceEpoch}.$extension',
      mimeType: mimeType,
    );
  }

  String? _externalCoverUrl(String coverUrl) {
    final value = coverUrl.trim();
    if (value.isEmpty || value.startsWith('data:')) return null;
    return value;
  }

  @override
  Future<bool> uploadPodcastVideoFile({
    required String podcastId,
    required List<int> fileBytes,
    required String filename,
    String mimeType = 'video/mp4',
  }) async {
    const maxAllowedBytes =
        100 * 1024 * 1024; // Giới hạn theo cấu hình hệ thống: 100MB
    if (fileBytes.length > maxAllowedBytes) {
      final sizeMb = (fileBytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw ApiException(
        statusCode: 413,
        message:
            'Tệp tải lên (${sizeMb}MB) vượt quá giới hạn tối đa của hệ thống (100MB). Vui lòng chọn tệp nhỏ hơn 100MB.',
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
          final objKey =
              media?['objectKey']?.toString() ?? res['mediaUrl']?.toString();
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
      'ogg' || 'oga' => 'audio/ogg',
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
      final responses = await Future.wait<dynamic>([
        _apiClient.get(ApiEndpoints.incomingRequests),
        _apiClient.get(ApiEndpoints.creatorContractRequests),
      ]);
      final rawRequestsById = <String, Map<String, dynamic>>{};
      for (final response in responses) {
        if (response is List) {
          for (final item in response.whereType<Map<String, dynamic>>()) {
            final requestId = item['requestId']?.toString() ?? '';
            if (requestId.isEmpty) continue;
            final existing = rawRequestsById[requestId];
            if (existing == null || _isRicherRequest(item, existing)) {
              rawRequestsById[requestId] = item;
            }
          }
        }
      }
      final rawRequests = rawRequestsById.values.toList();
      if (rawRequests.isNotEmpty) {
        final list = <PodcastRequest>[];
        for (final item in rawRequests) {
          list.add(await _mapBackendRequestToModel(item));
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

  bool _isRicherRequest(
    Map<String, dynamic> candidate,
    Map<String, dynamic> existing,
  ) {
    bool isEscrow(Map<String, dynamic> item) {
      final flowType = item['flowType']?.toString().toUpperCase();
      return flowType == 'ESCROW' ||
          item['contractId'] != null ||
          item['contractStatus'] != null;
    }

    return isEscrow(candidate) && !isEscrow(existing);
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
  Future<void> acceptRequest(
    String id, {
    String? responseText,
    List<Map<String, dynamic>>? milestones,
  }) async {
    final req = await getRequestById(id);
    final totalBudget = req?.totalBudget ?? 0;

    final defaultMilestones =
        milestones ??
        [
          {
            'name': 'Bản thu âm podcast hoàn chỉnh',
            'description':
                'Sản xuất và bàn giao bản audio theo đúng chủ đề yêu cầu.',
            'amount': totalBudget.toDouble(),
          },
        ];

    final body = {
      'responseText': responseText?.trim().isNotEmpty == true
          ? responseText!.trim()
          : 'Creator đã chấp nhận đơn đặt podcast.',
      'milestones': defaultMilestones,
    };

    List<RequestMilestone> realMilestones = [];
    try {
      final res = await _apiClient.post(
        ApiEndpoints.acceptRequest(id),
        body: body,
      );
      if (res is Map<String, dynamic>) {
        final milestonesJson = res['milestones'];
        if (milestonesJson is List) {
          for (final m in milestonesJson) {
            if (m is Map<String, dynamic>) {
              final mAmount = (m['amount'] as num?)?.toInt() ?? 0;
              final statusStr = (m['status'] as String? ?? 'NOT_STARTED')
                  .toUpperCase();
              realMilestones.add(
                RequestMilestone(
                  id: m['milestoneId']?.toString() ?? '',
                  title: m['name'] as String? ?? 'Mốc thanh toán',
                  description: m['description'] as String?,
                  order: (m['order'] as num?)?.toInt() ?? 1,
                  percentage: totalBudget > 0
                      ? ((mAmount / totalBudget) * 100).toInt()
                      : 100,
                  amount: mAmount,
                  status: statusStr,
                  isCompleted:
                      statusStr == 'APPROVED' || statusStr == 'SUBMITTED',
                  isApproved: statusStr == 'APPROVED',
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error acceptRequest: $e');
      rethrow;
    }

    if (realMilestones.isEmpty) {
      try {
        final res = await _apiClient.get(ApiEndpoints.requestMilestones(id));
        if (res is List) {
          for (final m in res) {
            if (m is Map<String, dynamic>) {
              final mAmount = (m['amount'] as num?)?.toInt() ?? 0;
              final statusStr = (m['status'] as String? ?? 'NOT_STARTED')
                  .toUpperCase();
              realMilestones.add(
                RequestMilestone(
                  id: m['milestoneId']?.toString() ?? '',
                  title: m['name'] as String? ?? 'Mốc thanh toán',
                  description: m['description'] as String?,
                  order: (m['order'] as num?)?.toInt() ?? 1,
                  percentage: totalBudget > 0
                      ? ((mAmount / totalBudget) * 100).toInt()
                      : 100,
                  amount: mAmount,
                  status: statusStr,
                  isCompleted:
                      statusStr == 'APPROVED' || statusStr == 'SUBMITTED',
                  isApproved: statusStr == 'APPROVED',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    final index = _cachedRequests.indexWhere((r) => r.id == id);
    if (index != -1) {
      final existing = _cachedRequests[index];
      _cachedRequests[index] = existing.copyWith(
        status: CustomRequestStatus.accepted,
        milestones: realMilestones.isNotEmpty
            ? realMilestones
            : existing.milestones,
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
  Future<ContractAgreement> proposeContract(
    String requestId, {
    required String responseText,
    required List<ContractProposalStageInput> milestones,
  }) async {
    final body = {
      'responseText': responseText.trim(),
      'milestones': milestones.map((s) => s.toJson()).toList(),
    };

    final res = await _apiClient.post(
      ApiEndpoints.creatorProposal(requestId),
      body: body,
    );

    if (res is! Map<String, dynamic>) {
      throw ApiException(
        statusCode: 500,
        message: 'Dữ liệu phản hồi hợp đồng không hợp lệ.',
      );
    }

    final agreement = ContractAgreement.fromJson(res);

    // Update in-memory cache
    final index = _cachedRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final existing = _cachedRequests[index];
      final newMilestones = agreement.milestones.map((s) {
        return RequestMilestone(
          id: s.milestoneId,
          title: s.name,
          description: s.description,
          order: agreement.milestones.indexOf(s) + 1,
          percentage: agreement.budgetAmount > 0
              ? ((s.amount / agreement.budgetAmount) * 100).toInt()
              : 100,
          amount: s.amount,
          status: s.status,
          isCompleted: s.isApproved || s.isSubmitted,
          isApproved: s.isApproved,
        );
      }).toList();

      _cachedRequests[index] = existing.copyWith(
        hasEscrow: true,
        contract: agreement,
        status: CustomRequestStatus.accepted,
        milestones: newMilestones,
      );
    }

    return agreement;
  }

  @override
  Future<ContractAgreement?> getContractAgreement(String requestId) async {
    try {
      final res = await _apiClient.get(ApiEndpoints.requestContract(requestId));
      if (res is Map<String, dynamic>) {
        return ContractAgreement.fromJson(res);
      }
    } catch (e) {
      debugPrint('getContractAgreement: $e');
    }
    return null;
  }

  @override
  Future<ContractAgreement> signContract(
    String requestId, {
    required int contractVersion,
    required String contentHash,
  }) async {
    final body = {
      'contractVersion': contractVersion,
      'contentHash': contentHash,
      'accepted': true,
    };

    final res = await _apiClient.post(
      ApiEndpoints.signContract(requestId),
      body: body,
    );

    if (res is! Map<String, dynamic>) {
      throw ApiException(
        statusCode: 500,
        message: 'Phản hồi ký kết hợp đồng không hợp lệ.',
      );
    }

    final agreement = ContractAgreement.fromJson(res);

    final index = _cachedRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final existing = _cachedRequests[index];
      _cachedRequests[index] = existing.copyWith(
        contract: agreement,
        status: agreement.isInProgress
            ? CustomRequestStatus.inProduction
            : existing.status,
      );
    }

    return agreement;
  }

  @override
  Future<List<MilestoneSubmissionItem>> getMilestoneSubmissions(
    String milestoneId,
  ) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.milestoneSubmissions(milestoneId),
      );
      if (res is List) {
        final list = <MilestoneSubmissionItem>[];
        for (final item in res) {
          if (item is Map<String, dynamic>) {
            var sub = MilestoneSubmissionItem.fromJson(item);
            // Optionally fetch media URL for preview
            try {
              final mediaUrl = await getMilestoneMediaUrl(
                milestoneId,
                sub.submissionId,
              );
              if (mediaUrl != null && mediaUrl.isNotEmpty) {
                sub = sub.copyWith(mediaUrl: mediaUrl);
              }
            } catch (_) {}
            list.add(sub);
          }
        }
        return list;
      }
    } catch (e) {
      debugPrint('getMilestoneSubmissions error: $e');
    }
    return const [];
  }

  @override
  Future<String?> getMilestoneMediaUrl(
    String milestoneId,
    String submissionId,
  ) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.milestoneMedia(milestoneId, submissionId),
      );
      if (res is Map<String, dynamic>) {
        return res['url'] as String?;
      }
    } catch (e) {
      debugPrint('getMilestoneMediaUrl error: $e');
    }
    return null;
  }

  @override
  Future<void> requestTermination(
    String requestId, {
    required String reason,
    String? listenerWinAction,
  }) async {
    await _apiClient.post(
      ApiEndpoints.contractTerminationRequest(requestId),
      body: {
        'reason': reason.trim(),
        if (listenerWinAction != null) 'listenerWinAction': listenerWinAction,
      },
    );

    // Refresh request in cache
    final index = _cachedRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final agreement = await getContractAgreement(requestId);
      final termStatus = await getTerminationRequest(requestId);
      _cachedRequests[index] = _cachedRequests[index].copyWith(
        contract: agreement,
        termination: termStatus,
        status: CustomRequestStatus.disputed,
      );
    }
  }

  @override
  Future<ContractTerminationStatus?> getTerminationRequest(
    String requestId,
  ) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.getContractTerminationRequest(requestId),
      );
      if (res is Map<String, dynamic>) {
        return ContractTerminationStatus.fromJson(res);
      }
    } catch (e) {
      debugPrint('getTerminationRequest error: $e');
    }
    return null;
  }

  @override
  Future<void> disputeMilestone(
    String milestoneId, {
    required String reason,
    String? listenerWinAction,
  }) async {
    await _apiClient.post(
      ApiEndpoints.milestoneDispute(milestoneId),
      body: {
        'reason': reason.trim(),
        if (listenerWinAction != null) 'listenerWinAction': listenerWinAction,
      },
    );
  }

  @override
  Future<void> confirmContractDispute(
    String disputeId, {
    String? listenerWinAction,
  }) async {
    await _apiClient.post(
      ApiEndpoints.contractDisputeConfirm(disputeId),
      body: {
        if (listenerWinAction != null) 'listenerWinAction': listenerWinAction,
      },
    );
  }

  @override
  Future<void> withdrawContractDispute(String disputeId) async {
    await _apiClient.post(ApiEndpoints.contractDisputeWithdraw(disputeId));
  }

  @override
  Future<void> confirmMilestoneDispute(
    String milestoneId,
    String disputeId, {
    String? listenerWinAction,
  }) async {
    await _apiClient.post(
      ApiEndpoints.milestoneDisputeConfirm(milestoneId, disputeId),
      body: {
        if (listenerWinAction != null) 'listenerWinAction': listenerWinAction,
      },
    );
  }

  @override
  Future<void> withdrawMilestoneDispute(
    String milestoneId,
    String disputeId,
  ) async {
    await _apiClient.post(
      ApiEndpoints.milestoneDisputeWithdraw(milestoneId, disputeId),
    );
  }

  @override
  Future<void> deliverWork(
    String id,
    String fileUrl,
    String note, {
    List<int>? fileBytes,
    String? filename,
    String? milestoneId,
  }) async {
    var uploadedDraft = false;
    try {
      final req = await getRequestById(id);
      String? targetMilestoneId = milestoneId;
      if (targetMilestoneId == null || targetMilestoneId.isEmpty) {
        if (req != null && req.milestones.isNotEmpty) {
          final pendingMilestone = req.milestones.firstWhere(
            (m) =>
                m.status == 'NOT_STARTED' || m.status == 'REVISION_REQUESTED',
            orElse: () => req.milestones.first,
          );
          targetMilestoneId = pendingMilestone.id;
        }
      }

      if (targetMilestoneId != null && targetMilestoneId.isNotEmpty) {
        if (fileBytes != null && fileBytes.isNotEmpty) {
          if (req?.hasEscrow == true) {
            // Escrow contracts require AI review before delivery. Uploading a
            // file must not start the listener's 3-day acceptance window.
            await uploadMilestoneDraft(
              targetMilestoneId,
              fileBytes: fileBytes,
              filename: filename ?? 'draft.mp3',
              note: note,
            );
            uploadedDraft = true;
          } else {
            await _apiClient.uploadMultipart(
              ApiEndpoints.submitMilestone(targetMilestoneId),
              fileFieldName: 'file',
              filename: filename ?? 'delivery.mp3',
              fileBytes: fileBytes,
              fields: {'note': note},
            );
          }
        }
      }
    } catch (e) {
      debugPrint('deliverWork error: $e');
      rethrow;
    }

    if (uploadedDraft) return;

    // Refresh request milestones from backend
    final index = _cachedRequests.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updatedMilestones = <RequestMilestone>[];
      try {
        final milestonesRes = await _apiClient.get(
          ApiEndpoints.requestMilestones(id),
        );
        if (milestonesRes is List && milestonesRes.isNotEmpty) {
          for (final m in milestonesRes) {
            if (m is Map<String, dynamic>) {
              final mAmount = (m['amount'] as num?)?.toInt() ?? 0;
              final mStatus = (m['status'] as String? ?? 'SUBMITTED')
                  .toUpperCase();
              updatedMilestones.add(
                RequestMilestone(
                  id: m['milestoneId']?.toString() ?? '',
                  title: m['name'] as String? ?? 'Mốc thanh toán',
                  description: m['description'] as String?,
                  order: (m['order'] as num?)?.toInt() ?? 1,
                  percentage: _cachedRequests[index].totalBudget > 0
                      ? ((mAmount / _cachedRequests[index].totalBudget) * 100)
                            .toInt()
                      : 100,
                  amount: mAmount,
                  status: mStatus,
                  isCompleted: mStatus == 'APPROVED' || mStatus == 'SUBMITTED',
                  isApproved: mStatus == 'APPROVED',
                  publicUrl: fileUrl,
                  submissionNote: note,
                ),
              );
            }
          }
        }
      } catch (_) {}

      _cachedRequests[index] = _cachedRequests[index].copyWith(
        status: CustomRequestStatus.delivered,
        deliveryFileUrl: fileUrl,
        deliveryNote: note,
        milestones: updatedMilestones.isNotEmpty
            ? updatedMilestones
            : _cachedRequests[index].milestones,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMilestoneDrafts(
    String milestoneId,
  ) async {
    final res = await _apiClient.get(ApiEndpoints.milestoneDrafts(milestoneId));
    return res is List
        ? res.whereType<Map<String, dynamic>>().toList(growable: false)
        : const [];
  }

  @override
  Future<Map<String, dynamic>> uploadMilestoneDraft(
    String milestoneId, {
    required List<int> fileBytes,
    required String filename,
    String? note,
  }) async {
    final res = await _apiClient.uploadMultipart(
      ApiEndpoints.milestoneDrafts(milestoneId),
      fileFieldName: 'file',
      filename: filename,
      fileBytes: fileBytes,
      fields: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    );
    if (res is Map<String, dynamic>) return res;
    throw ApiException(
      statusCode: 500,
      message: 'Phản hồi bản nháp không hợp lệ.',
    );
  }

  @override
  Future<Map<String, dynamic>> deliverMilestoneDraft(
    String milestoneId,
    String draftId,
  ) async {
    final res = await _apiClient.post(
      ApiEndpoints.deliverMilestoneDraft(milestoneId, draftId),
    );
    if (res is Map<String, dynamic>) return res;
    throw ApiException(
      statusCode: 500,
      message: 'Phản hồi bàn giao không hợp lệ.',
    );
  }

  @override
  Future<void> cancelMilestoneDraft(String milestoneId, String draftId) async {
    await _apiClient.post(
      ApiEndpoints.cancelMilestoneDraft(milestoneId, draftId),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getChatMessages(
    String requestId, {
    int page = 0,
    int size = 20,
  }) async {
    final res = await _apiClient.get(
      ApiEndpoints.requestChatMessages(requestId),
      queryParams: {'page': page, 'size': size},
    );
    final items = res is List
        ? res
        : res is Map<String, dynamic> && res['content'] is List
        ? res['content'] as List
        : const [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<void> sendChatMessage(String requestId, String message) async {
    await _apiClient.post(
      ApiEndpoints.requestChatMessages(requestId),
      body: {'clientMessageId': _uuid.v4(), 'content': message.trim()},
    );
  }

  // ==========================================
  // 5. WALLET & TRANSACTIONS ("cái nào chưa có thì bỏ qua")
  // ==========================================

  @override
  Future<Map<String, int>> getWalletBalance() async {
    if (!_apiClient.isAuthenticated) {
      throw Exception('Vui lòng đăng nhập để xem số dư ví.');
    }
    final res = await _apiClient.get(ApiEndpoints.creatorWallet);
    if (res is Map<String, dynamic>) {
      _availableBalance = (res['availableBalance'] as num?)?.toInt() ?? 0;
      _holdingWithdraw = (res['heldBalance'] as num?)?.toInt() ?? 0;
      _pendingRelease = (res['pendingRelease'] as num?)?.toInt() ?? 0;
      final totalBalance = (res['totalBalance'] as num?)?.toInt() ??
          (_availableBalance + _holdingWithdraw);

      return {
        'available': _availableBalance,
        'pending': _pendingRelease,
        'holding': _holdingWithdraw,
        'total': totalBalance,
        'totalWithdrawn': _totalWithdrawn,
      };
    } else {
      throw Exception('Dữ liệu số dư ví từ máy chủ không hợp lệ.');
    }
  }

  (String, String) _walletTransactionTitleAndSubtitle(
    dynamic rawType,
    dynamic rawRef,
    dynamic note,
  ) {
    final typeStr = '${rawType ?? ''}'.toUpperCase();
    final refStr = '${rawRef ?? ''}'.toUpperCase();

    if (typeStr == 'RELEASE_FUNDS' ||
        typeStr == 'CONTRACT_PAYMENT' ||
        typeStr == 'MILESTONE_RELEASE' ||
        typeStr == 'REQUEST_EARNING') {
      if (refStr.startsWith('CONTRACT_CREATOR:')) {
        return (
          'Thù lao hợp đồng',
          'Giải ngân đợt bàn giao đã nghiệm thu (80%)'
        );
      } else if (refStr.startsWith('CONTRACT_DISPUTE_CREATOR:')) {
        return (
          'Giải ngân tranh chấp',
          'Thù lao sau khi giải quyết tranh chấp hợp đồng'
        );
      } else if (refStr.startsWith('CONTRACT_COMPENSATION_CREATOR:')) {
        return (
          'Bồi thường hợp đồng',
          'Bồi hoàn hợp đồng đã xử lý'
        );
      }
      return ('Thù lao hợp đồng', 'Giải ngân thu nhập vào số dư khả dụng');
    }
    if (typeStr == 'WITHDRAWAL') {
      return ('Rút tiền về ngân hàng', 'Đã chuyển thành công về tài khoản');
    }
    if (typeStr == 'WITHDRAWAL_HOLD') {
      return ('Yêu cầu rút tiền', 'Tạm giữ số dư chờ Admin giải ngân');
    }
    if (typeStr == 'WITHDRAWAL_REFUND') {
      return ('Hoàn lại tiền rút', 'Yêu cầu rút tiền bị từ chối hoặc hủy');
    }
    if (typeStr == 'MEMBERSHIP' ||
        typeStr == 'MEMBERSHIP_EARNING' ||
        typeStr == 'MEMBERSHIP_FEE' ||
        typeStr == 'SUBSCRIPTION') {
      return ('Thu nhập hội viên', 'Đăng ký gói hội viên kênh');
    }
    if (typeStr == 'WALLET_TOPUP' || typeStr == 'TOP_UP') {
      return ('Nạp tiền vào ví', 'Nạp tiền thành công');
    }
    if (typeStr == 'REFUND') {
      return ('Hoàn tiền ví', note?.toString() ?? 'Hoàn tiền giao dịch');
    }
    return ('Giao dịch ví', note?.toString() ?? '');
  }

  TransactionType _walletTransactionType(dynamic rawType) {
    switch ('${rawType ?? ''}'.toUpperCase()) {
      case 'REQUEST_EARNING':
      case 'CONTRACT_PAYMENT':
      case 'MILESTONE_RELEASE':
      case 'RELEASE_FUNDS':
        return TransactionType.requestEarning;
      case 'MEMBERSHIP':
      case 'MEMBERSHIP_EARNING':
      case 'MEMBERSHIP_FEE':
      case 'SUBSCRIPTION':
        return TransactionType.membership;
      case 'REFUND':
      case 'WITHDRAWAL_REFUND':
        return TransactionType.refund;
      default:
        return TransactionType.withdrawal;
    }
  }

  int _walletTransactionAmount(Map<String, dynamic> item) {
    final rawAmount = ((item['amount'] as num?)?.toInt() ?? 0).abs();
    final direction = '${item['direction'] ?? ''}'.toUpperCase();
    final type = '${item['type'] ?? ''}'.toUpperCase();

    if (direction == 'DEBIT' ||
        direction == 'OUT' ||
        type == 'WITHDRAWAL' ||
        type == 'WITHDRAWAL_HOLD') {
      return -rawAmount;
    }
    if (direction == 'CREDIT' || direction == 'IN') {
      return rawAmount;
    }
    return rawAmount;
  }

  @override
  Future<List<WalletTransaction>> getTransactions({
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    if (!_apiClient.isAuthenticated) {
      throw Exception('Vui lòng đăng nhập để xem lịch sử ví.');
    }
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
    };
    if (status != null && status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }
    final res = await _apiClient.get(
      ApiEndpoints.creatorTransactions,
      queryParams: queryParams,
    );
    if (res is! List &&
        !(res is Map<String, dynamic> && res['content'] is List)) {
      throw Exception('Dữ liệu lịch sử ví từ máy chủ không hợp lệ.');
    }
    final rawTransactions = res is List
        ? res
        : res is Map<String, dynamic> && res['content'] is List
            ? res['content'] as List
            : const [];

    final transactions = rawTransactions
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final statusStr = (item['status']?.toString() ?? '').toUpperCase();
          final transactionStatus = switch (statusStr) {
            'COMPLETED' || 'SUCCESS' || 'PAID' => TransactionStatus.success,
            'FAILED' ||
            'REJECTED' ||
            'CANCELLED' => TransactionStatus.failed,
            'PENDING' || 'HOLDING' => TransactionStatus.holding,
            _ => TransactionStatus.processing,
          };

          final rawTitle = item['title']?.toString();
          final rawDescription = item['description']?.toString();

          final (fallbackTitle, fallbackSubtitle) = _walletTransactionTitleAndSubtitle(
            item['type'],
            item['referenceCode'],
            item['note'],
          );

          final title = (rawTitle != null && rawTitle.trim().isNotEmpty)
              ? rawTitle.trim()
              : fallbackTitle;
          final subtitle = (rawDescription != null && rawDescription.trim().isNotEmpty)
              ? rawDescription.trim()
              : fallbackSubtitle;

          return WalletTransaction(
            id: item['transactionId']?.toString() ??
                item['walletTransactionId']?.toString() ??
                item['withdrawalRequestId']?.toString() ??
                _uuid.v4(),
            title: title,
            subtitle: subtitle,
            type: _walletTransactionType(item['type']),
            rawType: item['type']?.toString(),
            direction: item['direction']?.toString(),
            amount: _walletTransactionAmount(item),
            currency: item['currency']?.toString() ?? 'VND',
            status: transactionStatus,
            rawStatus: statusStr,
            referenceCode: item['referenceCode']?.toString(),
            balanceAfter: (item['balanceAfter'] as num?)?.toInt(),
            heldBalanceAfter: (item['heldBalanceAfter'] as num?)?.toInt(),
            createdAt: DateTime.tryParse(
                  item['createdAt']?.toString() ??
                      item['occurredAt']?.toString() ??
                      item['requestedAt']?.toString() ??
                      '',
                ) ??
                DateTime.now(),
            note: item['note']?.toString(),
            movement: item['movement']?.toString(),
            availableBalanceChange:
                (item['availableBalanceChange'] as num?)?.toInt(),
            heldBalanceChange:
                (item['heldBalanceChange'] as num?)?.toInt(),
            requestId: item['requestId']?.toString(),
            requestTitle: item['requestTitle']?.toString(),
            milestoneId: item['milestoneId']?.toString(),
            milestoneName: item['milestoneName']?.toString(),
            withdrawalId: item['withdrawalId']?.toString(),
            payoutAccountMasked: item['payoutAccountMasked']?.toString(),
            membershipPlanName: item['membershipPlanName']?.toString(),
          );
        })
        .toList();

    _cachedTransactions
      ..clear()
      ..addAll(transactions);

    // Compute total withdrawn from completed withdrawal transactions
    _totalWithdrawn = transactions
        .where((t) =>
            (t.type == TransactionType.withdrawal ||
                t.rawType == 'WITHDRAWAL') &&
            t.status == TransactionStatus.success)
        .fold(0, (sum, t) => sum + t.amount.abs());

    return List.unmodifiable(_cachedTransactions);
  }

  @override
  Future<List<BankAccount>> getBankAccounts() async {
    if (!_apiClient.isAuthenticated) {
      throw Exception('Vui lòng đăng nhập để xem tài khoản nhận tiền.');
    }
    final res = await _apiClient.get(ApiEndpoints.creatorBankAccounts);
    if (res is List) {
      final accounts = res.whereType<Map<String, dynamic>>().map((item) {
        final payoutMethod =
            item['payoutMethod']?.toString() ?? 'BANK_TRANSFER';
        final bankNameDisplay = switch (payoutMethod.toUpperCase()) {
          'BANK_TRANSFER' => 'Chuyển khoản Ngân hàng',
          'MOMO' => 'Ví điện tử MoMo',
          'ZALOPAY' => 'Ví ZaloPay',
          'VIETQR' => 'VietQR Pro',
          _ => payoutMethod,
        };
        final isVerified = item['verified'] == true;
        final isActive = item['active'] == true;
        return BankAccount(
          id: item['payoutAccountId']?.toString() ??
              item['creatorPayoutAccountId']?.toString() ??
              _uuid.v4(),
          bankName: bankNameDisplay,
          accountNumber:
              item['accountMasked']?.toString() ?? 'Chưa cập nhật',
          accountHolder: item['accountReference']?.toString() ??
              item['currency']?.toString() ??
              'VND',
          isDefault: isActive && isVerified,
          payoutMethod: payoutMethod,
          currency: item['currency']?.toString() ?? 'VND',
          verified: isVerified,
          active: isActive,
        );
      }).toList();
      _cachedBankAccounts
        ..clear()
        ..addAll(accounts);
    } else {
      throw Exception('Danh sách tài khoản nhận tiền từ máy chủ không hợp lệ.');
    }
    return List.unmodifiable(_cachedBankAccounts);
  }

  @override
  Future<void> addBankAccount(
    String bankName,
    String accountNumber,
    String accountHolder,
  ) async {
    throw UnsupportedError('Tài khoản nhận tiền cần được Admin xác minh và đăng ký trên hệ thống.');
  }

  @override
  Future<void> deleteBankAccount(String id) async {
    throw UnsupportedError('Chưa có API gỡ tài khoản nhận tiền đã xác minh.');
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
    final response = await _apiClient.post(
      ApiEndpoints.creatorWithdraw,
      body: {'amount': amount, 'payoutAccountId': bankAccountId},
    );
    if (response is! Map<String, dynamic> || response['status'] != 'PENDING' ||
        response['withdrawalRequestId'] == null) {
      throw Exception('Cần kiểm tra lại trạng thái yêu cầu rút tiền trên máy chủ.');
    }
    return WalletTransaction(
      id: response['withdrawalRequestId'].toString(),
      title: 'Yêu cầu rút tiền về ngân hàng',
      type: TransactionType.withdrawal,
      amount: -amount,
      status: TransactionStatus.holding,
      createdAt: DateTime.tryParse(response['requestedAt']?.toString() ?? '') ?? DateTime.now(),
      note: 'Đang chờ Admin ghi nhận kết quả chuyển tiền.',
    );
  }

  @override
  Future<void> releaseFunds() async {
    if (!_apiClient.isAuthenticated) {
      throw Exception('Vui lòng đăng nhập để giải ngân thu nhập.');
    }
    await _apiClient.post(ApiEndpoints.creatorReleaseFunds);
  }

  // ==========================================
  // 6. COMMENTS MANAGEMENT
  // ==========================================
  // LIKES & COMMENTS API IMPLEMENTATION
  // ==========================================

  @override
  Future<Map<String, dynamic>> getPodcastLikes(String podcastId) async {
    final cached = _cachedPodcasts.cast<CreatorPodcast?>().firstWhere(
      (p) => p?.id == podcastId,
      orElse: () => null,
    );
    if (cached != null && cached.status != PodcastStatus.published) {
      return {'podcastId': podcastId, 'likeCount': 0, 'likedByMe': false};
    }
    try {
      final res = await _apiClient.get(
        ApiEndpoints.podcastLikes(podcastId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        final count = (res['likeCount'] as num?)?.toInt() ?? 0;
        final likedByMe = res['likedByMe'] == true;
        // Update cache
        final idx = _cachedPodcasts.indexWhere((p) => p.id == podcastId);
        if (idx != -1) {
          _cachedPodcasts[idx] = _cachedPodcasts[idx].copyWith(
            likesCount: count,
            likedByMe: likedByMe,
          );
        }
        return res;
      }
    } catch (_) {}
    return {'podcastId': podcastId, 'likeCount': 0, 'likedByMe': false};
  }

  @override
  Future<Map<String, dynamic>> likePodcast(String podcastId) async {
    try {
      final res = await _apiClient.put(
        ApiEndpoints.podcastLike(podcastId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        final count = (res['likeCount'] as num?)?.toInt();
        final likedByMe = res['likedByMe'] == true;
        final idx = _cachedPodcasts.indexWhere((p) => p.id == podcastId);
        if (idx != -1) {
          final resolvedCount = count ?? (_cachedPodcasts[idx].likesCount + 1);
          _cachedPodcasts[idx] = _cachedPodcasts[idx].copyWith(
            likesCount: resolvedCount,
            likedByMe: likedByMe,
          );
        }
        return res;
      }
    } catch (_) {}
    final idx = _cachedPodcasts.indexWhere((p) => p.id == podcastId);
    final fallbackCount = idx != -1 ? _cachedPodcasts[idx].likesCount + 1 : 1;
    if (idx != -1) {
      _cachedPodcasts[idx] = _cachedPodcasts[idx].copyWith(
        likesCount: fallbackCount,
        likedByMe: true,
      );
    }
    return {
      'podcastId': podcastId,
      'likeCount': fallbackCount,
      'likedByMe': true,
    };
  }

  @override
  Future<Map<String, dynamic>> unlikePodcast(String podcastId) async {
    try {
      final res = await _apiClient.delete(
        ApiEndpoints.podcastLike(podcastId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        final count = (res['likeCount'] as num?)?.toInt();
        final likedByMe = res['likedByMe'] == true;
        final idx = _cachedPodcasts.indexWhere((p) => p.id == podcastId);
        if (idx != -1) {
          final resolvedCount =
              count ??
              (_cachedPodcasts[idx].likesCount > 0
                  ? _cachedPodcasts[idx].likesCount - 1
                  : 0);
          _cachedPodcasts[idx] = _cachedPodcasts[idx].copyWith(
            likesCount: resolvedCount,
            likedByMe: likedByMe,
          );
        }
        return res;
      }
    } catch (_) {}
    final idx = _cachedPodcasts.indexWhere((p) => p.id == podcastId);
    final fallbackCount = idx != -1
        ? (_cachedPodcasts[idx].likesCount > 0
              ? _cachedPodcasts[idx].likesCount - 1
              : 0)
        : 0;
    if (idx != -1) {
      _cachedPodcasts[idx] = _cachedPodcasts[idx].copyWith(
        likesCount: fallbackCount,
        likedByMe: false,
      );
    }
    return {
      'podcastId': podcastId,
      'likeCount': fallbackCount,
      'likedByMe': false,
    };
  }

  @override
  Future<Map<String, dynamic>?> getPlayback(String podcastId) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.podcastPlayback(podcastId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (e) {
      debugPrint('[getPlayback] Error: $e');
    }
    return null;
  }

  @override
  Future<void> recordListeningProgress({
    required String podcastId,
    required int progressSeconds,
    bool completed = false,
  }) async {
    try {
      debugPrint('[ListeningProgress] PUT /api/podcasts/$podcastId/listening-progress -> {progressSeconds: $progressSeconds, completed: $completed}');
      await _apiClient.put(
        ApiEndpoints.podcastListeningProgress(podcastId),
        body: {'progressSeconds': progressSeconds, 'completed': completed},
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
    } catch (e) {
      debugPrint('[ListeningProgress] Error: $e');
    }
  }

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
      // Fetch latest comments only from published podcasts
      final publishedPods = podcasts
          .where((p) => p.status == PodcastStatus.published)
          .take(10);
      for (final pod in publishedPods) {
        try {
          final commentsRes = await _apiClient.get(
            ApiEndpoints.podcastComments(pod.id),
            headers: const {'ngrok-skip-browser-warning': '1'},
          );
          if (commentsRes is Map<String, dynamic> &&
              commentsRes['content'] is List) {
            for (final item in commentsRes['content'] as List) {
              if (item is Map<String, dynamic>) {
                allComments.add(
                  StudioComment.fromJson(
                    item,
                    fallbackPodcastTitle: pod.title,
                    fallbackPodcastId: pod.id,
                  ),
                );
              }
            }
          }
        } catch (_) {}
      }
      if (allComments.isNotEmpty) {
        _cachedComments.clear();
        _cachedComments.addAll(allComments);
      }
    } catch (_) {}

    return List.unmodifiable(_cachedComments);
  }

  @override
  Future<List<StudioComment>> getPodcastComments(
    String podcastId, {
    int page = 0,
    int size = 50,
  }) async {
    final cached = _cachedPodcasts.cast<CreatorPodcast?>().firstWhere(
      (p) => p?.id == podcastId,
      orElse: () => null,
    );
    if (cached != null && cached.status != PodcastStatus.published) {
      return const [];
    }
    try {
      final res = await _apiClient.get(
        '${ApiEndpoints.podcastComments(podcastId)}?page=$page&size=$size',
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic> && res['content'] is List) {
        final List<StudioComment> comments = [];
        final pod = _cachedPodcasts.cast<CreatorPodcast?>().firstWhere(
          (p) => p?.id == podcastId,
          orElse: () => null,
        );
        for (final item in res['content'] as List) {
          if (item is Map<String, dynamic>) {
            comments.add(
              StudioComment.fromJson(
                item,
                fallbackPodcastTitle: pod?.title ?? 'Podcast',
                fallbackPodcastId: podcastId,
              ),
            );
          }
        }
        return comments;
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<int> getPodcastCommentsCount(String podcastId) async {
    final cached = _cachedPodcasts.cast<CreatorPodcast?>().firstWhere(
      (p) => p?.id == podcastId,
      orElse: () => null,
    );
    if (cached != null && cached.status != PodcastStatus.published) {
      return 0;
    }
    try {
      final res = await _apiClient.get(
        '${ApiEndpoints.podcastComments(podcastId)}?page=0&size=1',
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic> && res['totalElements'] is num) {
        final count = (res['totalElements'] as num).toInt();
        final idx = _cachedPodcasts.indexWhere((p) => p.id == podcastId);
        if (idx != -1) {
          _cachedPodcasts[idx] = _cachedPodcasts[idx].copyWith(
            commentsCount: count,
          );
        }
        return count;
      }
    } catch (_) {}
    return 0;
  }

  @override
  Future<StudioComment?> addCommentToPodcast({
    required String podcastId,
    required String content,
    int? timestampSeconds,
    String? podcastTitle,
  }) async {
    final cached = _cachedPodcasts.cast<CreatorPodcast?>().firstWhere(
      (p) => p?.id == podcastId,
      orElse: () => null,
    );
    if (cached != null && cached.status != PodcastStatus.published) {
      throw Exception(
        'Tập podcast chỉ có thể nhận bình luận sau khi đã được xuất bản.',
      );
    }
    try {
      final body = <String, dynamic>{'content': content};
      if (timestampSeconds != null && timestampSeconds >= 0) {
        body['timestampSeconds'] = timestampSeconds;
      }

      final res = await _apiClient.post(
        ApiEndpoints.podcastComments(podcastId),
        body: body,
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        final comment = StudioComment.fromJson(
          res,
          fallbackPodcastTitle: podcastTitle ?? _cachedProfile.name,
          fallbackPodcastId: podcastId,
        );
        _cachedComments.insert(0, comment);

        // Update cached podcast comments count
        final idx = _cachedPodcasts.indexWhere((p) => p.id == podcastId);
        if (idx != -1) {
          _cachedPodcasts[idx] = _cachedPodcasts[idx].copyWith(
            commentsCount: _cachedPodcasts[idx].commentsCount + 1,
          );
        }
        return comment;
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.commentById(commentId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
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

  @override
  Future<Map<String, dynamic>> getCommentLikes(String commentId) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.commentLikes(commentId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {}
    return {'commentId': commentId, 'likeCount': 0, 'likedByMe': false};
  }

  @override
  Future<Map<String, dynamic>> likeComment(String commentId) async {
    try {
      final res = await _apiClient.put(
        ApiEndpoints.commentLike(commentId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        final count = (res['likeCount'] as num?)?.toInt();
        final likedByMe = res['likedByMe'] == true;
        final idx = _cachedComments.indexWhere((c) => c.id == commentId);
        if (idx != -1) {
          _cachedComments[idx] = _cachedComments[idx].copyWith(
            likesCount: count ?? (_cachedComments[idx].likesCount + 1),
            likedByMe: likedByMe,
          );
        }
        return res;
      }
    } catch (_) {}
    final idx = _cachedComments.indexWhere((c) => c.id == commentId);
    final fallbackCount = idx != -1 ? _cachedComments[idx].likesCount + 1 : 1;
    if (idx != -1) {
      _cachedComments[idx] = _cachedComments[idx].copyWith(
        likesCount: fallbackCount,
        likedByMe: true,
      );
    }
    return {
      'commentId': commentId,
      'likeCount': fallbackCount,
      'likedByMe': true,
    };
  }

  @override
  Future<Map<String, dynamic>> unlikeComment(String commentId) async {
    try {
      final res = await _apiClient.delete(
        ApiEndpoints.commentLike(commentId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        final count = (res['likeCount'] as num?)?.toInt();
        final likedByMe = res['likedByMe'] == true;
        final idx = _cachedComments.indexWhere((c) => c.id == commentId);
        if (idx != -1) {
          _cachedComments[idx] = _cachedComments[idx].copyWith(
            likesCount:
                count ??
                (_cachedComments[idx].likesCount > 0
                    ? _cachedComments[idx].likesCount - 1
                    : 0),
            likedByMe: likedByMe,
          );
        }
        return res;
      }
    } catch (_) {}
    final idx = _cachedComments.indexWhere((c) => c.id == commentId);
    final fallbackCount = idx != -1
        ? (_cachedComments[idx].likesCount > 0
              ? _cachedComments[idx].likesCount - 1
              : 0)
        : 0;
    if (idx != -1) {
      _cachedComments[idx] = _cachedComments[idx].copyWith(
        likesCount: fallbackCount,
        likedByMe: false,
      );
    }
    return {
      'commentId': commentId,
      'likeCount': fallbackCount,
      'likedByMe': false,
    };
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
  Future<CreatorSeries?> getSeriesById(String seriesId) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.creatorSeriesById(seriesId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        return CreatorSeries.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<CreatorSeries?> updateSeries({
    required String seriesId,
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
      final res = await _apiClient.put(
        ApiEndpoints.creatorSeriesById(seriesId),
        body: {
          'categoryId': effectiveCategoryId,
          'title': title,
          'slug': slug.isNotEmpty
              ? slug
              : title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
          'description': description.isNotEmpty ? description : null,
          'coverUrl': coverUrl.isNotEmpty ? coverUrl : null,
        },
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        final updated = CreatorSeries.fromJson(res);
        final idx = _cachedSeries.indexWhere((s) => s.id == seriesId);
        if (idx != -1) {
          _cachedSeries[idx] = updated;
        }
        return updated;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> deleteSeries(String seriesId) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.creatorSeriesById(seriesId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      _cachedSeries.removeWhere((s) => s.id == seriesId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<CreatorPodcast>> getSeriesPodcasts(String seriesId) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.creatorSeriesPodcasts(seriesId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map((json) => _mapBackendPodcastToModel(json))
            .toList();
      }
    } catch (_) {}
    return [];
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
  // REAL POLLS API (/api/creator/polls)
  // ==========================================

  @override
  Future<List<CreatorPoll>> getPolls({
    String? status,
    String? seriesId,
    String? podcastId,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (seriesId != null && seriesId.isNotEmpty) queryParams['seriesId'] = seriesId;
    if (podcastId != null && podcastId.isNotEmpty) queryParams['podcastId'] = podcastId;
    queryParams['page'] = '0';
    queryParams['size'] = '50';

    String endpoint = ApiEndpoints.creatorPolls;
    if (queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      endpoint = '$endpoint?$queryString';
    }

    final res = await _apiClient.get(endpoint);
    final list = <CreatorPoll>[];

    if (res is Map<String, dynamic> && res['content'] is List) {
      for (final item in res['content']) {
        if (item is Map<String, dynamic>) {
          list.add(CreatorPoll.fromJson(item));
        }
      }
    } else if (res is List) {
      for (final item in res) {
        if (item is Map<String, dynamic>) {
          list.add(CreatorPoll.fromJson(item));
        }
      }
    }
    return list;
  }

  @override
  Future<CreatorPoll> getPollDetail(String pollId) async {
    final res = await _apiClient.get(ApiEndpoints.creatorPollById(pollId));
    if (res is Map<String, dynamic>) {
      final pollMap = (res['poll'] is Map<String, dynamic>)
          ? res['poll'] as Map<String, dynamic>
          : res;
      final optionsList = <CreatorPollOption>[];
      if (res['options'] is List) {
        for (final opt in res['options']) {
          if (opt is Map<String, dynamic>) {
            optionsList.add(CreatorPollOption.fromJson(opt));
          }
        }
      }
      return CreatorPoll.fromJson(pollMap, options: optionsList);
    }
    throw Exception('Không thể tải chi tiết cuộc bình chọn');
  }

  @override
  Future<CreatorPoll> createPoll({
    required String question,
    required List<String> options,
    String? seriesId,
    String? podcastId,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final body = <String, dynamic>{
      'question': question.trim(),
      'options': options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    };
    if (seriesId != null && seriesId.isNotEmpty) body['seriesId'] = seriesId;
    if (podcastId != null && podcastId.isNotEmpty) body['podcastId'] = podcastId;
    if (startsAt != null) body['startsAt'] = startsAt.toUtc().toIso8601String();
    if (endsAt != null) body['endsAt'] = endsAt.toUtc().toIso8601String();

    final res = await _apiClient.post(ApiEndpoints.creatorPolls, body: body);
    if (res is Map<String, dynamic>) {
      final pollMap = (res['poll'] is Map<String, dynamic>)
          ? res['poll'] as Map<String, dynamic>
          : res;
      final optionsList = <CreatorPollOption>[];
      if (res['options'] is List) {
        for (final opt in res['options']) {
          if (opt is Map<String, dynamic>) {
            optionsList.add(CreatorPollOption.fromJson(opt));
          }
        }
      }
      return CreatorPoll.fromJson(pollMap, options: optionsList);
    }
    throw Exception('Tạo cuộc bình chọn không thành công');
  }

  @override
  Future<CreatorPoll> updatePoll(
    String pollId, {
    required String question,
    required List<String> options,
    String? seriesId,
    String? podcastId,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final body = <String, dynamic>{
      'question': question.trim(),
      'options': options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    };
    if (seriesId != null && seriesId.isNotEmpty) body['seriesId'] = seriesId;
    if (podcastId != null && podcastId.isNotEmpty) body['podcastId'] = podcastId;
    if (startsAt != null) body['startsAt'] = startsAt.toUtc().toIso8601String();
    if (endsAt != null) body['endsAt'] = endsAt.toUtc().toIso8601String();

    final res = await _apiClient.put(ApiEndpoints.creatorPollById(pollId), body: body);
    if (res is Map<String, dynamic>) {
      final pollMap = (res['poll'] is Map<String, dynamic>)
          ? res['poll'] as Map<String, dynamic>
          : res;
      final optionsList = <CreatorPollOption>[];
      if (res['options'] is List) {
        for (final opt in res['options']) {
          if (opt is Map<String, dynamic>) {
            optionsList.add(CreatorPollOption.fromJson(opt));
          }
        }
      }
      return CreatorPoll.fromJson(pollMap, options: optionsList);
    }
    throw Exception('Cập nhật cuộc bình chọn không thành công');
  }

  @override
  Future<void> deletePoll(String pollId) async {
    await _apiClient.delete(ApiEndpoints.creatorPollById(pollId));
  }

  @override
  Future<CreatorPoll> publishPoll(String pollId) async {
    final res = await _apiClient.post(ApiEndpoints.creatorPollPublish(pollId));
    if (res is Map<String, dynamic>) {
      final pollMap = (res['poll'] is Map<String, dynamic>)
          ? res['poll'] as Map<String, dynamic>
          : res;
      return CreatorPoll.fromJson(pollMap);
    }
    return getPollDetail(pollId);
  }

  @override
  Future<CreatorPoll> closePoll(String pollId) async {
    final res = await _apiClient.post(ApiEndpoints.creatorPollClose(pollId));
    if (res is Map<String, dynamic>) {
      final pollMap = (res['poll'] is Map<String, dynamic>)
          ? res['poll'] as Map<String, dynamic>
          : res;
      return CreatorPoll.fromJson(pollMap);
    }
    return getPollDetail(pollId);
  }

  @override
  Future<PollResultsData> getPollResults(String pollId) async {
    final res = await _apiClient.get(ApiEndpoints.creatorPollResults(pollId));
    if (res is Map<String, dynamic>) {
      return PollResultsData.fromJson(res);
    }
    throw Exception('Không lấy được kết quả bình chọn');
  }

  @override
  Future<List<PollResponseUserItem>> getPollResponses(String pollId) async {
    final res = await _apiClient.get(ApiEndpoints.creatorPollResponses(pollId));
    final list = <PollResponseUserItem>[];
    if (res is Map<String, dynamic> && res['content'] is List) {
      for (final item in res['content']) {
        if (item is Map<String, dynamic>) {
          list.add(PollResponseUserItem.fromJson(item));
        }
      }
    } else if (res is List) {
      for (final item in res) {
        if (item is Map<String, dynamic>) {
          list.add(PollResponseUserItem.fromJson(item));
        }
      }
    }
    return list;
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
    if (resolvedAudioName == null &&
        mediaKeyStr != null &&
        mediaKeyStr.isNotEmpty) {
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
      listensCount:
          (json['listenCount'] as num?)?.toInt() ??
          (json['listensCount'] as num?)?.toInt() ??
          0,
      likesCount:
          (json['likeCount'] as num?)?.toInt() ??
          (json['likesCount'] as num?)?.toInt() ??
          0,
      likedByMe: json['likedByMe'] == true,
      commentsCount:
          (json['commentCount'] as num?)?.toInt() ??
          (json['commentsCount'] as num?)?.toInt() ??
          0,
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

    // The escrow list uses RequestDetail field names, while the legacy inbox
    // uses SeriesRequestResponse names. Normalize both before rendering UI.
    final detail = await _loadContractRequestDetail(requestId);
    final source = <String, dynamic>{...json, ...?detail};
    final budgetNum =
        (source['budgetAmount'] as num?) ??
        (source['proposedBudget'] as num?) ??
        0;
    final totalBudget = budgetNum.toInt();

    final milestones = <RequestMilestone>[];
    final allSubmissions = <MilestoneSubmissionItem>[];
    String? latestDeliveryUrl;
    String? latestDeliveryNote;

    // Check for Escrow Contract
    ContractAgreement? agreement;
    try {
      final contractRes = await _apiClient.get(
        ApiEndpoints.requestContract(requestId),
      );
      if (contractRes is Map<String, dynamic>) {
        agreement = ContractAgreement.fromJson(contractRes);
      }
    } catch (_) {}

    ContractTerminationStatus? termStatus;
    if (agreement != null && (agreement.isDisputed || agreement.isTerminated)) {
      try {
        final termRes = await _apiClient.get(
          ApiEndpoints.getContractTerminationRequest(requestId),
        );
        if (termRes is Map<String, dynamic>) {
          termStatus = ContractTerminationStatus.fromJson(termRes);
        }
      } catch (_) {}
    }

    if (agreement != null && agreement.milestones.isNotEmpty) {
      for (final stage in agreement.milestones) {
        String? subUrl;
        String? subNote;
        try {
          final subsRes = await _apiClient.get(
            ApiEndpoints.milestoneSubmissions(stage.milestoneId),
          );
          if (subsRes is List && subsRes.isNotEmpty) {
            for (final sItem in subsRes) {
              if (sItem is Map<String, dynamic>) {
                var sub = MilestoneSubmissionItem.fromJson(sItem);
                try {
                  final mediaRes = await _apiClient.get(
                    ApiEndpoints.milestoneMedia(
                      stage.milestoneId,
                      sub.submissionId,
                    ),
                  );
                  if (mediaRes is Map<String, dynamic> &&
                      mediaRes['url'] != null) {
                    sub = sub.copyWith(mediaUrl: mediaRes['url'] as String);
                  }
                } catch (_) {}
                allSubmissions.add(sub);
                subUrl ??= sub.mediaUrl ?? sub.fileKey;
                subNote ??= sub.note;
                latestDeliveryUrl ??= subUrl;
                latestDeliveryNote ??= subNote;
              }
            }
          }
        } catch (_) {}

        final percentage = agreement.budgetAmount > 0
            ? ((stage.amount / agreement.budgetAmount) * 100).toInt()
            : 100;

        milestones.add(
          RequestMilestone(
            id: stage.milestoneId,
            title: stage.name,
            description: stage.description,
            order: agreement.milestones.indexOf(stage) + 1,
            percentage: percentage,
            amount: stage.amount,
            status: stage.status,
            isCompleted: stage.isApproved || stage.isSubmitted,
            isApproved: stage.isApproved,
            publicUrl: subUrl,
            submissionNote: subNote,
          ),
        );
      }

      if (agreement.isCompleted) {
        status = CustomRequestStatus.completed;
      } else if (agreement.isDisputed) {
        status = CustomRequestStatus.disputed;
      } else if (agreement.isInProgress) {
        if (milestones.any((m) => m.isRevisionRequested)) {
          status = CustomRequestStatus.revisionRequested;
        } else if (milestones.any((m) => m.isSubmitted)) {
          status = CustomRequestStatus.delivered;
        } else {
          status = CustomRequestStatus.inProduction;
        }
      } else if (agreement.isPendingSignature) {
        status = CustomRequestStatus.accepted;
      }
    } else {
      // Fallback for non-escrow or legacy requests
      try {
        final milestonesRes = await _apiClient.get(
          ApiEndpoints.requestMilestones(requestId),
        );
        if (milestonesRes is List && milestonesRes.isNotEmpty) {
          for (final m in milestonesRes) {
            if (m is Map<String, dynamic>) {
              final mAmount = (m['amount'] as num?)?.toInt() ?? 0;
              final mStatus = (m['status'] as String? ?? 'NOT_STARTED')
                  .toUpperCase();
              final milestoneId = m['milestoneId']?.toString() ?? '';

              String? subUrl;
              String? subNote;
              if (mStatus == 'SUBMITTED' || mStatus == 'APPROVED') {
                try {
                  final subsRes = await _apiClient.get(
                    ApiEndpoints.milestoneSubmissions(milestoneId),
                  );
                  if (subsRes is List && subsRes.isNotEmpty) {
                    final latestSub = subsRes.last;
                    if (latestSub is Map<String, dynamic>) {
                      subUrl = latestSub['publicUrl'] as String?;
                      subNote = latestSub['note'] as String?;
                      latestDeliveryUrl ??= subUrl;
                      latestDeliveryNote ??= subNote;
                    }
                  }
                } catch (_) {}
              }

              milestones.add(
                RequestMilestone(
                  id: milestoneId,
                  title: m['name'] as String? ?? 'Mốc thanh toán',
                  description: m['description'] as String?,
                  order: (m['order'] as num?)?.toInt() ?? 1,
                  percentage: totalBudget > 0
                      ? ((mAmount / totalBudget) * 100).toInt()
                      : 100,
                  amount: mAmount,
                  status: mStatus,
                  isCompleted: mStatus == 'APPROVED' || mStatus == 'SUBMITTED',
                  isApproved: mStatus == 'APPROVED',
                  publicUrl: subUrl,
                  submissionNote: subNote,
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    final createdAtStr = json['createdAt'] as String?;
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();

    final listenerIdStr = json['listenerId']?.toString() ?? '';
    final listenerDisplay = listenerIdStr.length >= 6
        ? 'Người nghe #${listenerIdStr.substring(0, 6)}'
        : 'Người nghe';

    final hasEscrow = agreement != null || detail != null;

    return PodcastRequest(
      id: requestId,
      listenerName: listenerDisplay,
      listenerAvatar: '',
      topic:
          source['requestedTitle'] as String? ??
          source['title'] as String? ??
          'Yêu cầu podcast',
      description: source['description'] as String? ?? '',
      totalBudget: agreement?.budgetAmount ?? totalBudget,
      milestones: milestones,
      status: status,
      deliveryFileUrl: latestDeliveryUrl,
      deliveryNote: latestDeliveryNote,
      createdAt: createdAt,
      hasEscrow: hasEscrow,
      contract: agreement,
      termination: termStatus,
      productType: source['productType'] as String?,
      fileFormat: source['fileFormat'] as String?,
      duration: source['duration'] as String?,
      acceptanceCriteria: source['acceptanceCriteria'] as String?,
      autoAcceptEnabled: source['autoAcceptEnabled'] as bool? ?? false,
      submissions: allSubmissions,
    );
  }

  Future<Map<String, dynamic>?> _loadContractRequestDetail(
    String requestId,
  ) async {
    try {
      final detail = await _apiClient.get(
        ApiEndpoints.contractRequestDetail(requestId),
      );
      return detail is Map<String, dynamic> ? detail : null;
    } catch (_) {
      return null;
    }
  }

  // Livestreams (Agora RTC)
  @override
  Future<List<CreatorLivestreamItem>> getLivestreams() async {
    try {
      final res = await _apiClient.get(ApiEndpoints.creatorLivestreams);
      if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map((e) => CreatorLivestreamItem.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<CreatorLivestreamItem> getLivestreamById(String livestreamId) async {
    final res = await _apiClient.get(
      ApiEndpoints.creatorLivestreamById(livestreamId),
    );
    if (res is Map<String, dynamic>) {
      return CreatorLivestreamItem.fromJson(res);
    }
    throw Exception('Phản hồi không hợp lệ từ máy chủ');
  }

  @override
  Future<CreatorLivestreamItem> createLivestream({
    required String title,
    String? description,
    DateTime? scheduledAt,
  }) async {
    final body = <String, dynamic>{
      'title': title.trim(),
      'description': (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : null,
      'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
    };
    final res = await _apiClient.post(
      ApiEndpoints.creatorLivestreams,
      body: body,
    );
    if (res is Map<String, dynamic>) {
      return CreatorLivestreamItem.fromJson(res);
    }
    throw Exception('Không thể tạo buổi livestream');
  }

  @override
  Future<AgoraJoinResponse> startLivestream(String livestreamId) async {
    final res = await _apiClient.post(
      ApiEndpoints.creatorLivestreamStart(livestreamId),
    );
    if (res is Map<String, dynamic>) {
      return AgoraJoinResponse.fromJson(res);
    }
    throw Exception('Không thể bắt đầu phát trực tiếp');
  }

  @override
  Future<AgoraJoinResponse> renewLivestreamToken(String livestreamId) async {
    final res = await _apiClient.post(
      ApiEndpoints.creatorLivestreamToken(livestreamId),
    );
    if (res is Map<String, dynamic>) {
      return AgoraJoinResponse.fromJson(res);
    }
    throw Exception('Không thể gia hạn token');
  }

  @override
  Future<CreatorLivestreamItem> endLivestream(String livestreamId) async {
    final res = await _apiClient.post(
      ApiEndpoints.creatorLivestreamEnd(livestreamId),
    );
    if (res is Map<String, dynamic>) {
      return CreatorLivestreamItem.fromJson(res);
    }
    throw Exception('Không thể kết thúc livestream');
  }

  // Channel Membership Plans
  @override
  Future<List<CreatorChannelPlan>> getMyChannelMembershipPlans() async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.creatorMembershipPlans,
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map(CreatorChannelPlan.fromJson)
            .toList();
      }
    } catch (e) {
      dev.log('[ApiCreatorRepository] getMyChannelMembershipPlans error: $e');
    }
    return [];
  }

  @override
  Future<List<CreatorPlanTemplate>> getMembershipPlanTemplates() async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.creatorMembershipTemplates,
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map(CreatorPlanTemplate.fromJson)
            .toList();
      }
    } catch (e) {
      dev.log('[ApiCreatorRepository] getMembershipPlanTemplates error: $e');
    }
    return [];
  }

  @override
  Future<CreatorChannelPlan> selectMembershipTemplate(
    String templateCode,
  ) async {
    final res = await _apiClient.put(
      ApiEndpoints.selectMembershipTemplate(templateCode),
      headers: const {'ngrok-skip-browser-warning': '1'},
    );
    if (res is Map<String, dynamic>) {
      return CreatorChannelPlan.fromJson(res);
    }
    throw Exception('Không thể kích hoạt gói thành viên');
  }

  @override
  Future<CreatorChannelPlan> updateMembershipPlanPrice(
    String planId,
    double price,
  ) async {
    final res = await _apiClient.put(
      ApiEndpoints.updateMembershipPlanPrice(planId),
      body: {'price': price},
      headers: const {'ngrok-skip-browser-warning': '1'},
    );
    if (res is Map<String, dynamic>) {
      return CreatorChannelPlan.fromJson(res);
    }
    throw Exception('Không thể cập nhật giá gói thành viên');
  }

  @override
  Future<PageCreatorMembers> getCreatorMemberships({
    String status = 'ACTIVE',
    int page = 0,
    int size = 20,
  }) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.creatorMemberships(status: status, page: page, size: size),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic>) {
        return PageCreatorMembers.fromJson(res);
      }
    } catch (e) {
      dev.log('[ApiCreatorRepository] getCreatorMemberships error: $e');
    }
    return PageCreatorMembers(
      totalPages: 0,
      totalElements: 0,
      size: size,
      number: page,
      content: const [],
    );
  }

  // Notifications
  @override
  Future<List<CreatorStudioNotification>> getNotifications({
    int page = 0,
    int size = 30,
  }) async {
    try {
      final res = await _apiClient.get(
        '${ApiEndpoints.notifications}?page=$page&size=$size',
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
      if (res is Map<String, dynamic> && res['content'] is List) {
        return (res['content'] as List)
            .whereType<Map<String, dynamic>>()
            .map(CreatorStudioNotification.fromJson)
            .toList();
      } else if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map(CreatorStudioNotification.fromJson)
            .toList();
      }
    } catch (e) {
      dev.log('[ApiCreatorRepository] getNotifications error: $e');
    }
    return [];
  }

  @override
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _apiClient.put(
        ApiEndpoints.markNotificationRead(notificationId),
        headers: const {'ngrok-skip-browser-warning': '1'},
      );
    } catch (e) {
      dev.log('[ApiCreatorRepository] markNotificationAsRead error: $e');
    }
  }
}
