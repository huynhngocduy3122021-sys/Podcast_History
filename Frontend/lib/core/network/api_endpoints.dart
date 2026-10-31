class ApiEndpoints {
  // Base URLs
  static const String defaultBaseUrl =
      'https://bullpen-viewer-overfill.ngrok-free.dev';
  static const String emulatorBaseUrl =
      'https://bullpen-viewer-overfill.ngrok-free.dev';

  // Auth
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';

  // Categories
  static const String categories = '/api/categories';

  // Listener escrow contract flow
  static const String createContractRequest = '/api/requests/contract';
  static String contractRequestDetail(String requestId) =>
      '/api/requests/$requestId/contract-request';
  static String cancelContractRequest(String requestId) =>
      '/api/requests/$requestId/contract/cancel';

  // Creator Applications
  static const String creatorApplications = '/api/creator-applications';
  static const String myCreatorApplication = '/api/creator-applications/me';

  // Creator Content Flow
  static const String creatorSeries = '/api/creator/series';
  static String creatorSeriesById(String id) => '/api/creator/series/$id';
  static String creatorSeriesPodcasts(String id) =>
      '/api/creator/series/$id/podcasts';

  static const String creatorPodcasts = '/api/creator/podcasts';
  static String creatorPodcastById(String id) => '/api/creator/podcasts/$id';
  static String creatorPodcastVideo(String id) =>
      '/api/creator/podcasts/$id/video';
  static String creatorPodcastThumbnail(String id) =>
      '/api/creator/podcasts/$id/thumbnail';
  static String creatorPodcastSubmit(String id) =>
      '/api/creator/podcasts/$id/submit';
  static String creatorPodcastSeries(String id) =>
      '/api/creator/podcasts/$id/series';
  static String creatorPodcastReferences(String id) =>
      '/api/creator/podcasts/$id/references';
  static String creatorPodcastReferenceFile(String podcastId, String refId) =>
      '/api/creator/podcasts/$podcastId/references/$refId/file';
  static String creatorPodcastReviews(String id) =>
      '/api/creator/podcasts/$id/reviews';
  static String creatorPodcastAppeals(String id) =>
      '/api/creator/podcasts/$id/appeals';
  static String creatorDashboard({String period = '7d'}) =>
      '/api/creator/dashboard?period=$period';

  // Creator Requests (Podcast theo yêu cầu & Hợp đồng Escrow)
  static const String incomingRequests = '/api/creator/requests/incoming';
  static const String creatorContractRequests =
      '/api/creator/requests/contracts';
  static String acceptRequest(String id) => '/api/creator/requests/$id/accept';
  static String rejectRequest(String id) => '/api/creator/requests/$id/reject';
  static String creatorProposal(String requestId) =>
      '/api/creator/requests/$requestId/proposal';
  static String requestContract(String requestId) =>
      '/api/requests/$requestId/contract';
  static String signContract(String requestId) =>
      '/api/requests/$requestId/contract/sign';
  static String cancelContract(String requestId) =>
      '/api/requests/$requestId/contract/cancel';
  static String requestMilestones(String id) => '/api/requests/$id/milestones';
  static String requestChatMessages(String id) =>
      '/api/requests/$id/chat/messages';
  static String submitMilestone(String milestoneId) =>
      '/api/creator/milestones/$milestoneId/submissions';
  static String milestoneDrafts(String milestoneId) =>
      '/api/creator/milestones/$milestoneId/drafts';
  static String milestoneDraftMedia(String milestoneId, String draftId) =>
      '/api/creator/milestones/$milestoneId/drafts/$draftId/media';
  static String deliverMilestoneDraft(String milestoneId, String draftId) =>
      '/api/creator/milestones/$milestoneId/drafts/$draftId/deliver';
  static String cancelMilestoneDraft(String milestoneId, String draftId) =>
      '/api/creator/milestones/$milestoneId/drafts/$draftId/cancel';
  static String milestoneSubmissions(String milestoneId) =>
      '/api/milestones/$milestoneId/submissions';
  static String milestoneMedia(String milestoneId, String submissionId) =>
      '/api/milestones/$milestoneId/submissions/$submissionId/media';
  static String contractTerminationRequest(String requestId) =>
      '/api/requests/$requestId/termination-requests';
  static String getContractTerminationRequest(String requestId) =>
      '/api/requests/$requestId/termination-request';
  static String milestoneDispute(String milestoneId) =>
      '/api/milestones/$milestoneId/disputes';

  // Comments & Likes & History
  static String podcastComments(String podcastId) =>
      '/api/podcasts/$podcastId/comments';
  static String podcastLikes(String podcastId) =>
      '/api/podcasts/$podcastId/likes';
  static String podcastLike(String podcastId) =>
      '/api/podcasts/$podcastId/like';
  static String podcastListeningProgress(String podcastId) =>
      '/api/podcasts/$podcastId/listening-progress';
  static String commentById(String commentId) => '/api/comments/$commentId';
  static String commentLikes(String commentId) =>
      '/api/comments/$commentId/likes';
  static String commentLike(String commentId) =>
      '/api/comments/$commentId/like';
  static const String creatorCommentsContract = '/api/creator/comments';

  // Wallet & Bank (Contract endpoints - skipped or graceful fallback if BE not yet implemented)
  static const String creatorWallet = '/api/creator/wallet/balance';
  static const String creatorTransactions = '/api/creator/wallet/transactions';
  static const String creatorReleaseFunds = '/api/creator/wallet/release-funds';
  static const String creatorWithdraw = '/api/creator/wallet/withdrawals';
  static const String creatorBankAccounts =
      '/api/creator/wallet/payout-accounts';

  // Forms & Polls
  static const String creatorForms = '/api/creator/forms';
  static const String creatorPolls = '/api/creator/polls';
  static String creatorPollById(String id) => '/api/creator/polls/$id';
  static String creatorPollPublish(String id) =>
      '/api/creator/polls/$id/publish';
  static String creatorPollClose(String id) => '/api/creator/polls/$id/close';
  static String creatorPollResults(String id) =>
      '/api/creator/polls/$id/results';
  static String creatorPollResponses(String id) =>
      '/api/creator/polls/$id/responses';
  static const String creatorUpgradePremium = '/api/creator/upgrade-premium';
  static const String creatorSystemPlans = '/api/creator/system-plans';
  static const String creatorSystemPlansMe = '/api/creator/system-plans/me';
  static const String creatorPendingCheckout =
      '/api/creator/system-plans/me/pending-checkout';
  static String creatorSystemPlanSubscribe(String planId) =>
      '/api/creator/system-plans/$planId/subscribe';
  static String meCheckout(String checkoutId) =>
      '/api/me/checkouts/$checkoutId';

  // Creator Livestreams (Agora RTC)
  static const String creatorLivestreams = '/api/creator/livestreams';
  static String creatorLivestreamById(String id) =>
      '/api/creator/livestreams/$id';
  static String creatorLivestreamStart(String id) =>
      '/api/creator/livestreams/$id/start';
  static String creatorLivestreamToken(String id) =>
      '/api/creator/livestreams/$id/token';
  static String creatorLivestreamEnd(String id) =>
      '/api/creator/livestreams/$id/end';

  // Creator Channel Membership Plans
  static const String creatorMembershipPlans = '/api/creator/membership-plans';
  static const String creatorMembershipTemplates =
      '/api/creator/membership-plans/templates';
  static String selectMembershipTemplate(String code) =>
      '/api/creator/membership-plans/templates/$code/select';
  static String updateMembershipPlanPrice(String planId) =>
      '/api/creator/membership-plans/$planId/price';
  static String creatorMemberships({
    String status = 'ACTIVE',
    int page = 0,
    int size = 20,
  }) => '/api/creator/memberships?status=$status&page=$page&size=$size';

  // Notifications
  static const String notifications = '/api/me/notifications';
  static String markNotificationRead(String id) =>
      '/api/me/notifications/$id/read';
}
