import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/api_service.dart';
import 'package:podcast_history/core/network/api_client.dart';
import 'package:podcast_history/features/notifications/notification_socket.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_livestream_model.dart';
import 'package:podcast_history/features/creator_studio/data/repositories/api_creator_repository.dart';
import 'package:podcast_history/features/creator_studio/domain/creator_repository.dart';

// Inject the authenticated session into Creator Studio API calls.
final creatorAccessTokenProvider = Provider<String?>((ref) => null);
final creatorRefreshTokenProvider = Provider<String?>((ref) => null);
final creatorSessionRefreshCallbackProvider =
    Provider<void Function(String newAccessToken, String newRefreshToken)?>(
      (ref) => null,
    );
final creatorSessionExpiredCallbackProvider = Provider<VoidCallback?>(
  (ref) => null,
);

final creatorNotificationSocketProvider = Provider<NotificationSocket?>((ref) {
  final token = ref.watch(creatorAccessTokenProvider);
  if (token == null || token.isEmpty) return null;
  final socket = NotificationSocket(
    url: apiBaseUrl.replaceFirst(RegExp(r'^http'), 'ws') + '/ws',
    accessToken: token,
    onNotification: (_) {},
    onRealtime: (_) {},
    onReconnected: () {},
  );
  ref.onDispose(socket.dispose);
  socket.connect();
  return socket;
});

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final accessToken = ref.watch(creatorAccessTokenProvider);
  final refreshToken = ref.watch(creatorRefreshTokenProvider);
  final onTokensRefreshed = ref.watch(creatorSessionRefreshCallbackProvider);
  final onSessionExpired = ref.watch(creatorSessionExpiredCallbackProvider);

  return ApiClient(
    initialToken: accessToken,
    initialRefreshToken: refreshToken,
    onTokensRefreshed: onTokensRefreshed,
    onSessionExpired: onSessionExpired,
  );
});

// Single repository instance - backed by real API calls
final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiCreatorRepository(apiClient);
});

// Profile Controller
class CreatorProfileNotifier extends Notifier<AsyncValue<CreatorProfile>> {
  @override
  AsyncValue<CreatorProfile> build() {
    Future.microtask(() => loadProfile());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadProfile() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data(CreatorProfile.empty);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final profile = await _repo.getProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> submitRegistration({
    required String channelName,
    required String bio,
    required String socialLink,
  }) async {
    await _repo.submitRegistration(
      channelName: channelName,
      bio: bio,
      socialLink: socialLink,
    );
    await loadProfile();
  }

  Future<void> upgradeToPremium() async {
    await _repo.upgradeToPremium();
    await loadProfile();
  }

  void setPremiumStatus(bool isPremium) {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isPremium: isPremium));
    }
  }
}

final creatorProfileProvider =
    NotifierProvider<CreatorProfileNotifier, AsyncValue<CreatorProfile>>(
      CreatorProfileNotifier.new,
    );

// Creator System Plans Provider
final creatorSystemPlansProvider = FutureProvider<List<CreatorSystemPlan>>((
  ref,
) async {
  final token = ref.watch(creatorAccessTokenProvider);
  if (token == null || token.isEmpty) {
    return const [];
  }
  final repo = ref.watch(creatorRepositoryProvider);
  return repo.getSystemPlans();
});

// Creator Subscription Controller & Provider
class CreatorSubscriptionNotifier
    extends Notifier<AsyncValue<CreatorSystemSubscription?>> {
  @override
  AsyncValue<CreatorSystemSubscription?> build() {
    Future.microtask(() => loadSubscription());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadSubscription() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final sub = await _repo.getMySystemSubscription();
      state = AsyncValue.data(sub);
      if (sub != null && sub.isActive) {
        ref.read(creatorProfileProvider.notifier).setPremiumStatus(true);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final creatorSubscriptionProvider =
    NotifierProvider<
      CreatorSubscriptionNotifier,
      AsyncValue<CreatorSystemSubscription?>
    >(CreatorSubscriptionNotifier.new);

// Categories Controller
class CreatorCategoriesNotifier
    extends Notifier<AsyncValue<List<CreatorCategory>>> {
  @override
  AsyncValue<List<CreatorCategory>> build() {
    Future.microtask(() => loadCategories());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadCategories() async {
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getCategories();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final categoriesProvider =
    NotifierProvider<
      CreatorCategoriesNotifier,
      AsyncValue<List<CreatorCategory>>
    >(CreatorCategoriesNotifier.new);

// Creator Dashboard Provider
final creatorDashboardProvider =
    FutureProvider.family<CreatorDashboardData, String>((ref, period) async {
      final token = ref.watch(creatorAccessTokenProvider);
      if (token == null || token.isEmpty) {
        return const CreatorDashboardData();
      }
      final repo = ref.watch(creatorRepositoryProvider);
      return repo.getDashboard(period: period);
    });

// Podcasts Controller
class CreatorPodcastsNotifier
    extends Notifier<AsyncValue<List<CreatorPodcast>>> {
  @override
  AsyncValue<List<CreatorPodcast>> build() {
    Future.microtask(() => loadPodcasts());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadPodcasts({PodcastStatus? filter}) async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getPodcasts(filterStatus: filter);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CreatorPodcast?> getPodcastById(String id) async {
    return _repo.getPodcastById(id);
  }

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
    final pod = await _repo.createPodcast(
      title: title,
      description: description,
      eraTag: eraTag,
      sources: sources,
      isExclusive: isExclusive,
      coverUrl: coverUrl,
      audioFileName: audioFileName,
      duration: duration,
      mediaBytes: mediaBytes,
      categoryId: categoryId,
      seriesId: seriesId,
      episodeNumber: episodeNumber,
      autoSubmit: autoSubmit,
    );
    await loadPodcasts();
    ref.read(creatorProfileProvider.notifier).loadProfile();
    ref.invalidate(creatorDashboardProvider);
    return pod;
  }

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
    final pod = await _repo.updatePodcast(
      id: id,
      title: title,
      description: description,
      eraTag: eraTag,
      sources: sources,
      isExclusive: isExclusive,
      coverUrl: coverUrl,
      audioFileName: audioFileName,
      duration: duration,
      mediaBytes: mediaBytes,
      categoryId: categoryId,
      seriesId: seriesId,
      episodeNumber: episodeNumber,
      autoSubmit: autoSubmit,
    );
    await loadPodcasts();
    ref.invalidate(creatorDashboardProvider);
    return pod;
  }

  Future<CreatorPodcast> submitPodcast(String id) async {
    final pod = await _repo.submitPodcast(id);
    await loadPodcasts();
    ref.invalidate(creatorDashboardProvider);
    return pod;
  }

  Future<void> deletePodcast(String id) async {
    await _repo.deletePodcast(id);
    await loadPodcasts();
    ref.read(creatorProfileProvider.notifier).loadProfile();
    ref.invalidate(creatorDashboardProvider);
  }

  void updatePodcastStats({
    required String podcastId,
    int? likesCount,
    bool? likedByMe,
    int? commentsCount,
    int? listensCount,
  }) {
    final currentList = state.value;
    if (currentList == null) return;
    final index = currentList.indexWhere((p) => p.id == podcastId);
    if (index == -1) return;
    final updatedList = List<CreatorPodcast>.from(currentList);
    updatedList[index] = updatedList[index].copyWith(
      likesCount: likesCount ?? updatedList[index].likesCount,
      likedByMe: likedByMe ?? updatedList[index].likedByMe,
      commentsCount: commentsCount ?? updatedList[index].commentsCount,
      listensCount: listensCount ?? updatedList[index].listensCount,
    );
    state = AsyncValue.data(updatedList);
  }

  Future<void> refreshPodcastStats(String podcastId) async {
    try {
      final currentList = state.value ?? [];
      final currentPod = currentList.cast<CreatorPodcast?>().firstWhere(
        (p) => p?.id == podcastId,
        orElse: () => null,
      );

      final isPublished =
          currentPod == null || currentPod.status == PodcastStatus.published;
      final likesRes = isPublished
          ? await _repo.getPodcastLikes(podcastId)
          : {'likeCount': 0, 'likedByMe': false};
      final cmtCount = isPublished
          ? await _repo.getPodcastCommentsCount(podcastId)
          : 0;
      final likeCount = (likesRes['likeCount'] as num?)?.toInt();
      final likedByMe = likesRes['likedByMe'] as bool?;

      // Đồng bộ lượt nghe từ Dashboard Metrics
      int? listens;
      try {
        final dash = await _repo.getDashboard(period: '7d');
        if (dash.metrics.views > 0) {
          listens = dash.metrics.views;
        }
      } catch (_) {}

      updatePodcastStats(
        podcastId: podcastId,
        likesCount: likeCount,
        likedByMe: likedByMe,
        commentsCount: cmtCount,
        listensCount: listens,
      );
    } catch (_) {}
  }

  Future<void> toggleLike(String podcastId) async {
    final currentList = state.value;
    if (currentList == null) return;
    final index = currentList.indexWhere((p) => p.id == podcastId);
    if (index == -1) return;
    final currentPod = currentList[index];
    final wasLiked = currentPod.likedByMe;
    final newLiked = !wasLiked;
    final newCount = newLiked
        ? currentPod.likesCount + 1
        : (currentPod.likesCount > 0 ? currentPod.likesCount - 1 : 0);

    // Optimistic update
    final updatedList = List<CreatorPodcast>.from(currentList);
    updatedList[index] = currentPod.copyWith(
      likedByMe: newLiked,
      likesCount: newCount,
    );
    state = AsyncValue.data(updatedList);

    try {
      if (newLiked) {
        final res = await _repo.likePodcast(podcastId);
        final serverCount = (res['likeCount'] as num?)?.toInt() ?? newCount;
        final latest = List<CreatorPodcast>.from(state.value ?? updatedList);
        final idx = latest.indexWhere((p) => p.id == podcastId);
        if (idx != -1) {
          latest[idx] = latest[idx].copyWith(
            likedByMe: true,
            likesCount: serverCount,
          );
          state = AsyncValue.data(latest);
        }
      } else {
        final res = await _repo.unlikePodcast(podcastId);
        final serverCount = (res['likeCount'] as num?)?.toInt() ?? newCount;
        final latest = List<CreatorPodcast>.from(state.value ?? updatedList);
        final idx = latest.indexWhere((p) => p.id == podcastId);
        if (idx != -1) {
          latest[idx] = latest[idx].copyWith(
            likedByMe: false,
            likesCount: serverCount,
          );
          state = AsyncValue.data(latest);
        }
      }
    } catch (_) {
      // Revert if error
      final revertList = List<CreatorPodcast>.from(state.value ?? updatedList);
      final idx = revertList.indexWhere((p) => p.id == podcastId);
      if (idx != -1) {
        revertList[idx] = currentPod;
        state = AsyncValue.data(revertList);
      }
    }
  }
}

final creatorPodcastsProvider =
    NotifierProvider<CreatorPodcastsNotifier, AsyncValue<List<CreatorPodcast>>>(
      CreatorPodcastsNotifier.new,
    );

// Custom Requests Controller
class CreatorRequestsNotifier
    extends Notifier<AsyncValue<List<PodcastRequest>>> {
  @override
  AsyncValue<List<PodcastRequest>> build() {
    Future.microtask(() => loadRequests());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadRequests() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getRequests();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptRequest(
    String id, {
    String? responseText,
    List<Map<String, dynamic>>? milestones,
  }) async {
    await _repo.acceptRequest(
      id,
      responseText: responseText,
      milestones: milestones,
    );
    await loadRequests();
  }

  Future<void> rejectRequest(String id, String reason) async {
    await _repo.rejectRequest(id, reason);
    await loadRequests();
  }

  Future<ContractAgreement> proposeContract(
    String requestId, {
    required String responseText,
    required List<ContractProposalStageInput> milestones,
  }) async {
    final agreement = await _repo.proposeContract(
      requestId,
      responseText: responseText,
      milestones: milestones,
    );
    await loadRequests();
    return agreement;
  }

  Future<ContractAgreement?> getContractAgreement(String requestId) async {
    return _repo.getContractAgreement(requestId);
  }

  Future<ContractAgreement> signContract(
    String requestId, {
    required int contractVersion,
    required String contentHash,
  }) async {
    final agreement = await _repo.signContract(
      requestId,
      contractVersion: contractVersion,
      contentHash: contentHash,
    );
    await loadRequests();
    return agreement;
  }

  Future<void> requestTermination(
    String requestId, {
    required String reason,
    String? listenerWinAction,
  }) async {
    await _repo.requestTermination(
      requestId,
      reason: reason,
      listenerWinAction: listenerWinAction,
    );
    await loadRequests();
  }

  Future<ContractTerminationStatus?> getTerminationRequest(
    String requestId,
  ) async {
    return _repo.getTerminationRequest(requestId);
  }

  Future<void> disputeMilestone(
    String milestoneId, {
    required String reason,
    String? listenerWinAction,
  }) async {
    await _repo.disputeMilestone(
      milestoneId,
      reason: reason,
      listenerWinAction: listenerWinAction,
    );
    await loadRequests();
  }

  Future<void> confirmContractDispute(
    String disputeId, {
    String? listenerWinAction,
  }) async {
    await _repo.confirmContractDispute(
      disputeId,
      listenerWinAction: listenerWinAction,
    );
    await loadRequests();
  }

  Future<void> withdrawContractDispute(String disputeId) async {
    await _repo.withdrawContractDispute(disputeId);
    await loadRequests();
  }

  Future<void> confirmMilestoneDispute(
    String milestoneId,
    String disputeId, {
    String? listenerWinAction,
  }) async {
    await _repo.confirmMilestoneDispute(
      milestoneId,
      disputeId,
      listenerWinAction: listenerWinAction,
    );
    await loadRequests();
  }

  Future<void> withdrawMilestoneDispute(
    String milestoneId,
    String disputeId,
  ) async {
    await _repo.withdrawMilestoneDispute(milestoneId, disputeId);
    await loadRequests();
  }

  Future<List<MilestoneSubmissionItem>> getMilestoneSubmissions(
    String milestoneId,
  ) async {
    return _repo.getMilestoneSubmissions(milestoneId);
  }

  Future<String?> getMilestoneMediaUrl(
    String milestoneId,
    String submissionId,
  ) async {
    return _repo.getMilestoneMediaUrl(milestoneId, submissionId);
  }

  Future<List<Map<String, dynamic>>> getMilestoneDrafts(String milestoneId) {
    return _repo.getMilestoneDrafts(milestoneId);
  }

  Future<void> deliverMilestoneDraft(String milestoneId, String draftId) async {
    await _repo.deliverMilestoneDraft(milestoneId, draftId);
    await loadRequests();
  }

  Future<void> cancelMilestoneDraft(String milestoneId, String draftId) async {
    await _repo.cancelMilestoneDraft(milestoneId, draftId);
    await loadRequests();
  }

  Future<void> deliverWork(
    String id,
    String fileUrl,
    String note, {
    List<int>? fileBytes,
    String? filename,
    String? milestoneId,
  }) async {
    await _repo.deliverWork(
      id,
      fileUrl,
      note,
      fileBytes: fileBytes,
      filename: filename,
      milestoneId: milestoneId,
    );
    await loadRequests();
  }

  Future<void> sendMessage(String requestId, String message) async {
    await _repo.sendChatMessage(requestId, message);
    await loadRequests();
  }
}

final creatorRequestsProvider =
    NotifierProvider<CreatorRequestsNotifier, AsyncValue<List<PodcastRequest>>>(
      CreatorRequestsNotifier.new,
    );

// Wallet Controller
class WalletState {
  final int available;
  final int pending;
  final int holding;
  final int totalWithdrawn;
  final List<WalletTransaction> transactions;

  const WalletState({
    required this.available,
    required this.pending,
    required this.holding,
    required this.totalWithdrawn,
    required this.transactions,
  });
}

class WalletNotifier extends Notifier<AsyncValue<WalletState>> {
  @override
  AsyncValue<WalletState> build() {
    Future.microtask(() => loadWallet());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadWallet() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data(
        WalletState(
          available: 0,
          pending: 0,
          holding: 0,
          totalWithdrawn: 0,
          transactions: [],
        ),
      );
      return;
    }
    try {
      state = const AsyncValue.loading();
      final balance = await _repo.getWalletBalance();
      final txs = await _repo.getTransactions();
      state = AsyncValue.data(
        WalletState(
          available: balance['available'] ?? 0,
          pending: balance['pending'] ?? 0,
          holding: balance['holding'] ?? 0,
          totalWithdrawn: balance['totalWithdrawn'] ?? 0,
          transactions: txs,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> withdrawMoney(
    int amount,
    String bankAccountId,
    String pin,
  ) async {
    await _repo.withdrawMoney(amount, bankAccountId, pin);
    await loadWallet();
  }

  Future<void> releaseFunds() async {
    await _repo.releaseFunds();
    await loadWallet();
  }
}

final walletProvider =
    NotifierProvider<WalletNotifier, AsyncValue<WalletState>>(
      WalletNotifier.new,
    );

// Bank Accounts Controller
class BankAccountsNotifier extends Notifier<AsyncValue<List<BankAccount>>> {
  @override
  AsyncValue<List<BankAccount>> build() {
    Future.microtask(() => loadAccounts());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadAccounts() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getBankAccounts();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAccount(
    String bankName,
    String accountNumber,
    String accountHolder,
  ) async {
    await _repo.addBankAccount(bankName, accountNumber, accountHolder);
    await loadAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await _repo.deleteBankAccount(id);
    await loadAccounts();
  }
}

final bankAccountsProvider =
    NotifierProvider<BankAccountsNotifier, AsyncValue<List<BankAccount>>>(
      BankAccountsNotifier.new,
    );

// Comments Controller
class CreatorCommentsNotifier
    extends Notifier<AsyncValue<List<StudioComment>>> {
  @override
  AsyncValue<List<StudioComment>> build() {
    Future.microtask(() => loadComments());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadComments() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getComments();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> togglePin(String id) async {
    await _repo.togglePinComment(id);
    await loadComments();
  }

  Future<void> toggleHide(String id) async {
    await _repo.toggleHideComment(id);
    await loadComments();
  }

  Future<void> deleteComment(String id) async {
    try {
      await _repo.deleteComment(id);
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((c) => c.id != id).toList());
    } catch (_) {}
    await loadComments();
  }

  Future<void> toggleCommentLike(String id) async {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final target = current[index];
    final wasLiked = target.likedByMe;
    final newLiked = !wasLiked;
    final newCount = newLiked
        ? target.likesCount + 1
        : (target.likesCount > 0 ? target.likesCount - 1 : 0);

    // Optimistic update
    final updated = List<StudioComment>.from(current);
    updated[index] = target.copyWith(likedByMe: newLiked, likesCount: newCount);
    state = AsyncValue.data(updated);

    try {
      if (newLiked) {
        final res = await _repo.likeComment(id);
        final serverCount = (res['likeCount'] as num?)?.toInt() ?? newCount;
        final list = List<StudioComment>.from(state.value ?? updated);
        final idx = list.indexWhere((c) => c.id == id);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(
            likedByMe: true,
            likesCount: serverCount,
          );
          state = AsyncValue.data(list);
        }
      } else {
        final res = await _repo.unlikeComment(id);
        final serverCount = (res['likeCount'] as num?)?.toInt() ?? newCount;
        final list = List<StudioComment>.from(state.value ?? updated);
        final idx = list.indexWhere((c) => c.id == id);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(
            likedByMe: false,
            likesCount: serverCount,
          );
          state = AsyncValue.data(list);
        }
      }
    } catch (_) {
      final revertList = List<StudioComment>.from(state.value ?? updated);
      final idx = revertList.indexWhere((c) => c.id == id);
      if (idx != -1) {
        revertList[idx] = target;
        state = AsyncValue.data(revertList);
      }
    }
  }

  Future<StudioComment?> addComment(
    StudioComment comment, {
    String? podcastId,
  }) async {
    final targetPodcastId = podcastId ?? comment.podcastId;
    if (targetPodcastId != null && targetPodcastId.isNotEmpty) {
      final created = await _repo.addCommentToPodcast(
        podcastId: targetPodcastId,
        content: comment.content,
        timestampSeconds: comment.timestampSeconds,
        podcastTitle: comment.podcastTitle,
      );
      if (created != null) {
        final current = state.value ?? [];
        state = AsyncValue.data([created, ...current]);
        // Update comments count in creatorPodcastsProvider
        final podcasts = ref.read(creatorPodcastsProvider).value;
        if (podcasts != null) {
          final pod = podcasts.cast<CreatorPodcast?>().firstWhere(
            (p) => p?.id == targetPodcastId,
            orElse: () => null,
          );
          if (pod != null) {
            ref
                .read(creatorPodcastsProvider.notifier)
                .updatePodcastStats(
                  podcastId: targetPodcastId,
                  commentsCount: pod.commentsCount + 1,
                );
          }
        }
        return created;
      }
    }

    final current = state.value ?? [];
    state = AsyncValue.data([comment, ...current]);
    return comment;
  }
}

final creatorCommentsProvider =
    NotifierProvider<CreatorCommentsNotifier, AsyncValue<List<StudioComment>>>(
      CreatorCommentsNotifier.new,
    );

// Series Controller
class CreatorSeriesNotifier extends Notifier<AsyncValue<List<CreatorSeries>>> {
  @override
  AsyncValue<List<CreatorSeries>> build() {
    Future.microtask(() => loadSeries());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadSeries() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getSeries();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CreatorSeries?> createSeries({
    required String title,
    required String slug,
    required String categoryId,
    String description = '',
    String coverUrl = '',
  }) async {
    final series = await _repo.createSeries(
      title: title,
      slug: slug,
      categoryId: categoryId,
      description: description,
      coverUrl: coverUrl,
    );
    await loadSeries();
    return series;
  }

  Future<CreatorSeries?> updateSeries({
    required String seriesId,
    required String title,
    required String slug,
    required String categoryId,
    String description = '',
    String coverUrl = '',
  }) async {
    final series = await _repo.updateSeries(
      seriesId: seriesId,
      title: title,
      slug: slug,
      categoryId: categoryId,
      description: description,
      coverUrl: coverUrl,
    );
    await loadSeries();
    return series;
  }

  Future<bool> deleteSeries(String seriesId) async {
    final ok = await _repo.deleteSeries(seriesId);
    await loadSeries();
    return ok;
  }

  Future<CreatorSeries?> getSeriesById(String seriesId) async {
    return _repo.getSeriesById(seriesId);
  }

  Future<List<CreatorPodcast>> getSeriesPodcasts(String seriesId) async {
    return _repo.getSeriesPodcasts(seriesId);
  }
}

final creatorSeriesProvider =
    NotifierProvider<CreatorSeriesNotifier, AsyncValue<List<CreatorSeries>>>(
      CreatorSeriesNotifier.new,
    );

// Forms Controller
class CreatorFormsNotifier extends Notifier<AsyncValue<List<InteractiveForm>>> {
  @override
  AsyncValue<List<InteractiveForm>> build() {
    Future.microtask(() => loadForms());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadForms() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getForms();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createForm(
    String title,
    String description,
    List<FormQuestion> questions,
  ) async {
    await _repo.createForm(title, description, questions);
    await loadForms();
  }
}

final creatorFormsProvider =
    NotifierProvider<CreatorFormsNotifier, AsyncValue<List<InteractiveForm>>>(
      CreatorFormsNotifier.new,
    );

// Livestreams (Agora RTC)
class CreatorLivestreamsNotifier
    extends Notifier<AsyncValue<List<CreatorLivestreamItem>>> {
  @override
  AsyncValue<List<CreatorLivestreamItem>> build() {
    Future.microtask(() => loadLivestreams());
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadLivestreams() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getLivestreams();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CreatorLivestreamItem> createLivestream({
    required String title,
    String? description,
    DateTime? scheduledAt,
  }) async {
    final item = await _repo.createLivestream(
      title: title,
      description: description,
      scheduledAt: scheduledAt,
    );
    await loadLivestreams();
    return item;
  }

  Future<AgoraJoinResponse> startLivestream(String livestreamId) async {
    final res = await _repo.startLivestream(livestreamId);
    await loadLivestreams();
    return res;
  }

  Future<AgoraJoinResponse> renewToken(String livestreamId) async {
    return _repo.renewLivestreamToken(livestreamId);
  }

  Future<CreatorLivestreamItem> endLivestream(String livestreamId) async {
    final res = await _repo.endLivestream(livestreamId);
    await loadLivestreams();
    return res;
  }
}

final creatorLivestreamsProvider =
    NotifierProvider<
      CreatorLivestreamsNotifier,
      AsyncValue<List<CreatorLivestreamItem>>
    >(CreatorLivestreamsNotifier.new);

// Channel Membership Plans
class CreatorChannelPlansNotifier
    extends Notifier<AsyncValue<List<CreatorChannelPlan>>> {
  @override
  AsyncValue<List<CreatorChannelPlan>> build() {
    Future.microtask(loadPlans);
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadPlans() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getMyChannelMembershipPlans();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CreatorChannelPlan> selectTemplate(String templateCode) async {
    final plan = await _repo.selectMembershipTemplate(templateCode);
    await loadPlans();
    return plan;
  }

  Future<CreatorChannelPlan> updatePrice(String planId, double price) async {
    final plan = await _repo.updateMembershipPlanPrice(planId, price);
    await loadPlans();
    return plan;
  }
}

final creatorChannelPlansProvider =
    NotifierProvider<
      CreatorChannelPlansNotifier,
      AsyncValue<List<CreatorChannelPlan>>
    >(CreatorChannelPlansNotifier.new);

final creatorPlanTemplatesProvider = FutureProvider<List<CreatorPlanTemplate>>((
  ref,
) async {
  final repo = ref.watch(creatorRepositoryProvider);
  return repo.getMembershipPlanTemplates();
});

final creatorMembershipsProvider =
    FutureProvider.family<PageCreatorMembers, String>((ref, status) async {
      final repo = ref.watch(creatorRepositoryProvider);
      return repo.getCreatorMemberships(status: status, page: 0, size: 50);
    });

// Studio Notifications
class CreatorNotificationsNotifier
    extends Notifier<AsyncValue<List<CreatorStudioNotification>>> {
  @override
  AsyncValue<List<CreatorStudioNotification>> build() {
    Future.microtask(loadNotifications);
    return const AsyncValue.loading();
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadNotifications() async {
    final token = ref.read(creatorAccessTokenProvider);
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final list = await _repo.getNotifications();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(String id) async {
    final current = state.value ?? [];
    state = AsyncValue.data([
      for (final n in current)
        if (n.id == id) n.copyWith(read: true) else n,
    ]);
    await _repo.markNotificationAsRead(id);
  }

  Future<void> markAllAsRead() async {
    final current = state.value ?? [];
    state = AsyncValue.data([for (final n in current) n.copyWith(read: true)]);
    for (final n in current.where((item) => !item.read)) {
      await _repo.markNotificationAsRead(n.id);
    }
  }
}

final creatorNotificationsProvider =
    NotifierProvider<
      CreatorNotificationsNotifier,
      AsyncValue<List<CreatorStudioNotification>>
    >(CreatorNotificationsNotifier.new);

final unreadCreatorNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(creatorNotificationsProvider).value ?? [];
  return notifs.where((n) => !n.read).length;
});
