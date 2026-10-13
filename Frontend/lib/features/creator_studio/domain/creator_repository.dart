import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';

abstract class CreatorRepository {
  // Profile & Registration
  Future<CreatorProfile> getProfile();
  Future<void> submitRegistration({
    required String channelName,
    required String handle,
    required String bio,
    required String category,
    required String socialLink,
    required String sampleVoiceName,
  });
  Future<void> upgradeToPremium();

  // Podcasts
  Future<List<CreatorPodcast>> getPodcasts({PodcastStatus? filterStatus});
  Future<CreatorPodcast> createPodcast({
    required String title,
    required String description,
    required String eraTag,
    required String sources,
    required bool isExclusive,
    required String coverUrl,
    required String? audioFileName,
    required Duration duration,
  });
  Future<void> deletePodcast(String id);

  // Custom Requests (Podcast theo yêu cầu)
  Future<List<PodcastRequest>> getRequests();
  Future<PodcastRequest?> getRequestById(String id);
  Future<void> acceptRequest(String id);
  Future<void> rejectRequest(String id, String reason);
  Future<void> deliverWork(String id, String fileUrl, String note);
  Future<void> sendChatMessage(String requestId, String message);

  // Wallet & Withdraw
  Future<Map<String, int>> getWalletBalance();
  Future<List<WalletTransaction>> getTransactions();
  Future<List<BankAccount>> getBankAccounts();
  Future<void> addBankAccount(String bankName, String accountNumber, String accountHolder);
  Future<void> deleteBankAccount(String id);
  Future<WalletTransaction> withdrawMoney(int amount, String bankAccountId, String pin);
  Future<void> releaseFunds();

  // Comments
  Future<List<StudioComment>> getComments();
  Future<void> togglePinComment(String id);
  Future<void> toggleHideComment(String id);

  // Forms
  Future<List<InteractiveForm>> getForms();
  Future<void> createForm(String title, String description, List<FormQuestion> questions);
}
