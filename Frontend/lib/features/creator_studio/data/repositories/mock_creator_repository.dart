import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:podcast_history/features/creator_studio/domain/creator_repository.dart';
import 'package:podcast_history/features/creator_studio/data/mock_creator_data.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';

class MockCreatorRepository implements CreatorRepository {
  final _uuid = const Uuid();

  // In-memory mutable copies
  CreatorProfile _profile = MockCreatorData.creatorProfile;
  final List<CreatorPodcast> _podcasts = List.from(MockCreatorData.podcasts);
  final List<PodcastRequest> _requests = List.from(MockCreatorData.requests);
  final List<BankAccount> _bankAccounts = List.from(
    MockCreatorData.bankAccounts,
  );
  final List<WalletTransaction> _transactions = List.from(
    MockCreatorData.transactions,
  );
  final List<StudioComment> _comments = List.from(MockCreatorData.comments);
  final List<InteractiveForm> _forms = List.from(MockCreatorData.forms);

  // Wallet balances
  int _availableBalance = 6850000;
  int _pendingRelease = 1200000;
  int _holdingWithdraw = 1500000;
  final int _totalWithdrawn = 8500000;

  Future<void> _simulateDelay() async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<CreatorProfile> getProfile() async {
    await _simulateDelay();
    return _profile;
  }

  @override
  Future<void> submitRegistration({
    required String channelName,
    required String handle,
    required String bio,
    required String category,
    required String socialLink,
    required String sampleVoiceName,
  }) async {
    await _simulateDelay();
    _profile = _profile.copyWith(
      name: channelName,
      handle: handle.isEmpty ? _profile.handle : handle,
      bio: bio,
      status: CreatorStatus.pending,
      rejectReason: null,
    );
  }

  @override
  Future<void> upgradeToPremium() async {
    await _simulateDelay();
    _profile = _profile.copyWith(isPremium: true);
  }

  @override
  Future<List<CreatorPodcast>> getPodcasts({
    PodcastStatus? filterStatus,
  }) async {
    await _simulateDelay();
    if (filterStatus == null) return List.unmodifiable(_podcasts);
    return _podcasts.where((p) => p.status == filterStatus).toList();
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
  }) async {
    await _simulateDelay();
    final newPodcast = CreatorPodcast(
      id: 'pod_${_uuid.v4().substring(0, 8)}',
      title: title,
      description: description,
      coverUrl: coverUrl.isEmpty
          ? 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=400&q=80'
          : coverUrl,
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
      aiModerationScore: 0.95,
    );
    _podcasts.insert(0, newPodcast);
    _profile = _profile.copyWith(
      currentPodcastCount: _profile.currentPodcastCount + 1,
    );
    return newPodcast;
  }

  @override
  Future<void> deletePodcast(String id) async {
    await _simulateDelay();
    _podcasts.removeWhere((p) => p.id == id);
    _profile = _profile.copyWith(
      currentPodcastCount: _profile.currentPodcastCount - 1,
    );
  }

  @override
  Future<List<PodcastRequest>> getRequests() async {
    await _simulateDelay();
    return List.unmodifiable(_requests);
  }

  @override
  Future<PodcastRequest?> getRequestById(String id) async {
    await _simulateDelay();
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> acceptRequest(String id) async {
    await _simulateDelay();
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(
        status: CustomRequestStatus.accepted,
      );
    }
  }

  @override
  Future<void> rejectRequest(String id, String reason) async {
    await _simulateDelay();
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(
        status: CustomRequestStatus.rejected,
        rejectionReason: reason,
      );
    }
  }

  @override
  Future<void> deliverWork(String id, String fileUrl, String note) async {
    await _simulateDelay();
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(
        status: CustomRequestStatus.delivered,
        deliveryFileUrl: fileUrl,
        deliveryNote: note,
      );
    }
  }

  @override
  Future<void> sendChatMessage(String requestId, String message) async {
    await _simulateDelay();
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = _requests[index];
      final newMsg = RequestChatMessage(
        id: 'msg_${_uuid.v4().substring(0, 6)}',
        senderName: _profile.name,
        isCreator: true,
        message: message,
        timestamp: DateTime.now(),
      );
      final updatedMsgs = List<RequestChatMessage>.from(req.messages)
        ..add(newMsg);
      _requests[index] = req.copyWith(messages: updatedMsgs);
    }
  }

  @override
  Future<Map<String, int>> getWalletBalance() async {
    await _simulateDelay();
    return {
      'available': _availableBalance,
      'pending': _pendingRelease,
      'holding': _holdingWithdraw,
      'totalWithdrawn': _totalWithdrawn,
    };
  }

  @override
  Future<List<WalletTransaction>> getTransactions() async {
    await _simulateDelay();
    return List.unmodifiable(_transactions);
  }

  @override
  Future<List<BankAccount>> getBankAccounts() async {
    await _simulateDelay();
    return List.unmodifiable(_bankAccounts);
  }

  @override
  Future<void> addBankAccount(
    String bankName,
    String accountNumber,
    String accountHolder,
  ) async {
    await _simulateDelay();
    final newAcc = BankAccount(
      id: 'bank_${_uuid.v4().substring(0, 6)}',
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolder: accountHolder.toUpperCase(),
      isDefault: _bankAccounts.isEmpty,
    );
    _bankAccounts.add(newAcc);
  }

  @override
  Future<void> deleteBankAccount(String id) async {
    await _simulateDelay();
    _bankAccounts.removeWhere((a) => a.id == id);
  }

  @override
  Future<WalletTransaction> withdrawMoney(
    int amount,
    String bankAccountId,
    String pin,
  ) async {
    await _simulateDelay();
    if (amount > _availableBalance) {
      throw Exception('Số dư khả dụng không đủ');
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
    _transactions.insert(0, tx);
    return tx;
  }

  @override
  Future<void> releaseFunds() async {
    await _simulateDelay();
    if (_pendingRelease > 0) {
      _availableBalance += _pendingRelease;
      final released = _pendingRelease;
      _pendingRelease = 0;

      _transactions.insert(
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

  @override
  Future<List<StudioComment>> getComments() async {
    await _simulateDelay();
    return List.unmodifiable(_comments);
  }

  @override
  Future<void> togglePinComment(String id) async {
    await _simulateDelay();
    final index = _comments.indexWhere((c) => c.id == id);
    if (index != -1) {
      _comments[index] = _comments[index].copyWith(
        isPinned: !_comments[index].isPinned,
      );
    }
  }

  @override
  Future<void> toggleHideComment(String id) async {
    await _simulateDelay();
    final index = _comments.indexWhere((c) => c.id == id);
    if (index != -1) {
      _comments[index] = _comments[index].copyWith(
        isHidden: !_comments[index].isHidden,
      );
    }
  }

  @override
  Future<List<InteractiveForm>> getForms() async {
    await _simulateDelay();
    return List.unmodifiable(_forms);
  }

  @override
  Future<void> createForm(
    String title,
    String description,
    List<FormQuestion> questions,
  ) async {
    await _simulateDelay();
    final newForm = InteractiveForm(
      id: 'form_${_uuid.v4().substring(0, 8)}',
      title: title,
      description: description,
      questions: questions,
      responsesCount: 0,
      createdAt: DateTime.now(),
    );
    _forms.insert(0, newForm);
  }
}
