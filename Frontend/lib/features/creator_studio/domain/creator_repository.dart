import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_livestream_model.dart';

abstract class CreatorRepository {
  // Profile & Registration
  Future<CreatorProfile> getProfile();
  Future<void> submitRegistration({
    required String channelName,
    required String bio,
    required String socialLink,
  });
  Future<void> upgradeToPremium();

  // System Plans & Checkout
  Future<List<CreatorSystemPlan>> getSystemPlans();
  Future<CreatorSystemSubscription?> getMySystemSubscription();
  Future<CreatorCheckoutPayment> subscribeSystemPlan(String planId);
  Future<CreatorCheckoutPayment> getCheckoutStatus(String checkoutId);
  Future<void> cancelPendingCheckout();

  // Categories
  Future<List<CreatorCategory>> getCategories();

  // Dashboard
  Future<CreatorDashboardData> getDashboard({String period = '7d'});

  // Podcasts
  Future<List<CreatorPodcast>> getPodcasts({PodcastStatus? filterStatus});
  Future<CreatorPodcast?> getPodcastById(String id);
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
  });
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
  });
  Future<CreatorPodcast> submitPodcast(String podcastId);
  Future<void> deletePodcast(String id);

  // Media & Uploads
  Future<CreatorPodcast?> uploadPodcastThumbnailFile({
    required String podcastId,
    required List<int> fileBytes,
    required String filename,
    String mimeType = 'image/jpeg',
  });
  Future<bool> uploadPodcastVideoFile({
    required String podcastId,
    required List<int> fileBytes,
    required String filename,
    String mimeType = 'video/mp4',
  });
  Future<bool> assignPodcastToSeries({
    required String podcastId,
    required String seriesId,
  });
  Future<bool> removePodcastFromSeries({required String podcastId});
  Future<bool> uploadPdfReferenceFile({
    required String podcastId,
    String? referenceId,
    required List<int> fileBytes,
    required String filename,
  });

  // Custom Requests (Podcast theo yêu cầu)
  Future<List<PodcastRequest>> getRequests();
  Future<PodcastRequest?> getRequestById(String id);
  Future<void> acceptRequest(String id);
  Future<void> rejectRequest(String id, String reason);
  Future<void> deliverWork(
    String id,
    String fileUrl,
    String note, {
    List<int>? fileBytes,
    String? filename,
  });
  Future<void> sendChatMessage(String requestId, String message);

  // Wallet & Withdraw
  Future<Map<String, int>> getWalletBalance();
  Future<List<WalletTransaction>> getTransactions();
  Future<List<BankAccount>> getBankAccounts();
  Future<void> addBankAccount(
    String bankName,
    String accountNumber,
    String accountHolder,
  );
  Future<void> deleteBankAccount(String id);
  Future<WalletTransaction> withdrawMoney(
    int amount,
    String bankAccountId,
    String pin,
  );
  Future<void> releaseFunds();

  // Likes & History
  Future<Map<String, dynamic>> getPodcastLikes(String podcastId);
  Future<Map<String, dynamic>> likePodcast(String podcastId);
  Future<Map<String, dynamic>> unlikePodcast(String podcastId);
  Future<void> recordListeningProgress({
    required String podcastId,
    required int progressSeconds,
    bool completed = false,
  });

  // Comments
  Future<List<StudioComment>> getComments();
  Future<List<StudioComment>> getPodcastComments(String podcastId, {int page = 0, int size = 50});
  Future<int> getPodcastCommentsCount(String podcastId);
  Future<StudioComment?> addCommentToPodcast({
    required String podcastId,
    required String content,
    int? timestampSeconds,
    String? podcastTitle,
  });
  Future<void> deleteComment(String commentId);
  Future<void> togglePinComment(String id);
  Future<void> toggleHideComment(String id);
  Future<Map<String, dynamic>> getCommentLikes(String commentId);
  Future<Map<String, dynamic>> likeComment(String commentId);
  Future<Map<String, dynamic>> unlikeComment(String commentId);

  // Series
  Future<List<CreatorSeries>> getSeries();
  Future<CreatorSeries?> getSeriesById(String seriesId);
  Future<CreatorSeries?> createSeries({
    required String title,
    required String slug,
    required String categoryId,
    String description,
    String coverUrl,
  });
  Future<CreatorSeries?> updateSeries({
    required String seriesId,
    required String title,
    required String slug,
    required String categoryId,
    String description,
    String coverUrl,
  });
  Future<bool> deleteSeries(String seriesId);
  Future<List<CreatorPodcast>> getSeriesPodcasts(String seriesId);

  // Appeals
  Future<void> submitPodcastAppeal({
    required String podcastId,
    required String note,
  });

  // Forms
  Future<List<InteractiveForm>> getForms();
  Future<void> createForm(
    String title,
    String description,
    List<FormQuestion> questions,
  );

  // Livestreams (Agora)
  Future<List<CreatorLivestreamItem>> getLivestreams();
  Future<CreatorLivestreamItem> getLivestreamById(String livestreamId);
  Future<CreatorLivestreamItem> createLivestream({
    required String title,
    String? description,
    DateTime? scheduledAt,
  });
  Future<AgoraJoinResponse> startLivestream(String livestreamId);
  Future<AgoraJoinResponse> renewLivestreamToken(String livestreamId);
  Future<CreatorLivestreamItem> endLivestream(String livestreamId);

  // Channel Membership Plans
  Future<List<CreatorChannelPlan>> getMyChannelMembershipPlans();
  Future<List<CreatorPlanTemplate>> getMembershipPlanTemplates();
  Future<CreatorChannelPlan> selectMembershipTemplate(String templateCode);
  Future<CreatorChannelPlan> updateMembershipPlanPrice(String planId, double price);

  // Notifications
  Future<List<CreatorStudioNotification>> getNotifications({int page = 0, int size = 30});
  Future<void> markNotificationAsRead(String notificationId);
}
