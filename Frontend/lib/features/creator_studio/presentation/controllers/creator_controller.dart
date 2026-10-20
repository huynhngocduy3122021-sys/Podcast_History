import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/core/network/api_client.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/data/repositories/api_creator_repository.dart';
import 'package:podcast_history/features/creator_studio/domain/creator_repository.dart';

// Inject the authenticated session into Creator Studio API calls.
final creatorAccessTokenProvider = Provider<String?>((ref) => null);

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(initialToken: ref.watch(creatorAccessTokenProvider));
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
}

final creatorProfileProvider =
    NotifierProvider<CreatorProfileNotifier, AsyncValue<CreatorProfile>>(
      CreatorProfileNotifier.new,
    );

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

final categoriesProvider = NotifierProvider<
    CreatorCategoriesNotifier,
    AsyncValue<List<CreatorCategory>>>(
  CreatorCategoriesNotifier.new,
);

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
    return pod;
  }

  Future<CreatorPodcast> submitPodcast(String id) async {
    final pod = await _repo.submitPodcast(id);
    await loadPodcasts();
    return pod;
  }

  Future<void> deletePodcast(String id) async {
    await _repo.deletePodcast(id);
    await loadPodcasts();
    ref.read(creatorProfileProvider.notifier).loadProfile();
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

  Future<void> acceptRequest(String id) async {
    await _repo.acceptRequest(id);
    await loadRequests();
  }

  Future<void> rejectRequest(String id, String reason) async {
    await _repo.rejectRequest(id, reason);
    await loadRequests();
  }

  Future<void> deliverWork(
    String id,
    String fileUrl,
    String note, {
    List<int>? fileBytes,
    String? filename,
  }) async {
    await _repo.deliverWork(
      id,
      fileUrl,
      note,
      fileBytes: fileBytes,
      filename: filename,
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
    await _repo.deleteComment(id);
    await loadComments();
  }

  Future<void> addComment(StudioComment comment, {String? podcastId}) async {
    final current = state.value ?? [];
    state = AsyncValue.data([comment, ...current]);
    if (podcastId != null) {
      await _repo.addCommentToPodcast(
        podcastId: podcastId,
        content: comment.content,
        timestampSeconds: comment.timestampSeconds,
        podcastTitle: comment.podcastTitle,
      );
      await loadComments();
    }
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
