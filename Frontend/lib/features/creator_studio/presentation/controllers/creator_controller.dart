import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_history/features/creator_studio/data/mock_creator_data.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/data/repositories/mock_creator_repository.dart';
import 'package:podcast_history/features/creator_studio/domain/creator_repository.dart';

// Single repository instance
final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  return MockCreatorRepository();
});

// Profile Controller
class CreatorProfileNotifier extends Notifier<AsyncValue<CreatorProfile>> {
  @override
  AsyncValue<CreatorProfile> build() {
    return AsyncValue.data(MockCreatorData.creatorProfile);
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadProfile() async {
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
    required String handle,
    required String bio,
    required String category,
    required String socialLink,
    required String sampleVoiceName,
  }) async {
    await _repo.submitRegistration(
      channelName: channelName,
      handle: handle,
      bio: bio,
      category: category,
      socialLink: socialLink,
      sampleVoiceName: sampleVoiceName,
    );
    await loadProfile();
  }

  Future<void> upgradeToPremium() async {
    await _repo.upgradeToPremium();
    await loadProfile();
  }
}

final creatorProfileProvider = NotifierProvider<CreatorProfileNotifier, AsyncValue<CreatorProfile>>(
  CreatorProfileNotifier.new,
);

// Podcasts Controller
class CreatorPodcastsNotifier extends Notifier<AsyncValue<List<CreatorPodcast>>> {
  @override
  AsyncValue<List<CreatorPodcast>> build() {
    return AsyncValue.data(MockCreatorData.podcasts);
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadPodcasts({PodcastStatus? filter}) async {
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getPodcasts(filterStatus: filter);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createPodcast({
    required String title,
    required String description,
    required String eraTag,
    required String sources,
    required bool isExclusive,
    required String coverUrl,
    required String? audioFileName,
    required Duration duration,
  }) async {
    await _repo.createPodcast(
      title: title,
      description: description,
      eraTag: eraTag,
      sources: sources,
      isExclusive: isExclusive,
      coverUrl: coverUrl,
      audioFileName: audioFileName,
      duration: duration,
    );
    await loadPodcasts();
    ref.read(creatorProfileProvider.notifier).loadProfile();
  }

  Future<void> deletePodcast(String id) async {
    await _repo.deletePodcast(id);
    await loadPodcasts();
    ref.read(creatorProfileProvider.notifier).loadProfile();
  }
}

final creatorPodcastsProvider = NotifierProvider<CreatorPodcastsNotifier, AsyncValue<List<CreatorPodcast>>>(
  CreatorPodcastsNotifier.new,
);

// Custom Requests Controller
class CreatorRequestsNotifier extends Notifier<AsyncValue<List<PodcastRequest>>> {
  @override
  AsyncValue<List<PodcastRequest>> build() {
    return AsyncValue.data(MockCreatorData.requests);
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadRequests() async {
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

  Future<void> deliverWork(String id, String fileUrl, String note) async {
    await _repo.deliverWork(id, fileUrl, note);
    await loadRequests();
  }

  Future<void> sendMessage(String requestId, String message) async {
    await _repo.sendChatMessage(requestId, message);
    await loadRequests();
  }
}

final creatorRequestsProvider = NotifierProvider<CreatorRequestsNotifier, AsyncValue<List<PodcastRequest>>>(
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
    return AsyncValue.data(WalletState(
      available: 6850000,
      pending: 1200000,
      holding: 1500000,
      totalWithdrawn: 8500000,
      transactions: MockCreatorData.transactions,
    ));
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadWallet() async {
    try {
      state = const AsyncValue.loading();
      final balance = await _repo.getWalletBalance();
      final txs = await _repo.getTransactions();
      state = AsyncValue.data(WalletState(
        available: balance['available'] ?? 0,
        pending: balance['pending'] ?? 0,
        holding: balance['holding'] ?? 0,
        totalWithdrawn: balance['totalWithdrawn'] ?? 0,
        transactions: txs,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> withdrawMoney(int amount, String bankAccountId, String pin) async {
    await _repo.withdrawMoney(amount, bankAccountId, pin);
    await loadWallet();
  }

  Future<void> releaseFunds() async {
    await _repo.releaseFunds();
    await loadWallet();
  }
}

final walletProvider = NotifierProvider<WalletNotifier, AsyncValue<WalletState>>(
  WalletNotifier.new,
);

// Bank Accounts Controller
class BankAccountsNotifier extends Notifier<AsyncValue<List<BankAccount>>> {
  @override
  AsyncValue<List<BankAccount>> build() {
    return AsyncValue.data(MockCreatorData.bankAccounts);
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadAccounts() async {
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getBankAccounts();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAccount(String bankName, String accountNumber, String accountHolder) async {
    await _repo.addBankAccount(bankName, accountNumber, accountHolder);
    await loadAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await _repo.deleteBankAccount(id);
    await loadAccounts();
  }
}

final bankAccountsProvider = NotifierProvider<BankAccountsNotifier, AsyncValue<List<BankAccount>>>(
  BankAccountsNotifier.new,
);

// Comments Controller
class CreatorCommentsNotifier extends Notifier<AsyncValue<List<StudioComment>>> {
  @override
  AsyncValue<List<StudioComment>> build() {
    return AsyncValue.data(MockCreatorData.comments);
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadComments() async {
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
}

final creatorCommentsProvider = NotifierProvider<CreatorCommentsNotifier, AsyncValue<List<StudioComment>>>(
  CreatorCommentsNotifier.new,
);

// Forms Controller
class CreatorFormsNotifier extends Notifier<AsyncValue<List<InteractiveForm>>> {
  @override
  AsyncValue<List<InteractiveForm>> build() {
    return AsyncValue.data(MockCreatorData.forms);
  }

  CreatorRepository get _repo => ref.read(creatorRepositoryProvider);

  Future<void> loadForms() async {
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getForms();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createForm(String title, String description, List<FormQuestion> questions) async {
    await _repo.createForm(title, description, questions);
    await loadForms();
  }
}

final creatorFormsProvider = NotifierProvider<CreatorFormsNotifier, AsyncValue<List<InteractiveForm>>>(
  CreatorFormsNotifier.new,
);
