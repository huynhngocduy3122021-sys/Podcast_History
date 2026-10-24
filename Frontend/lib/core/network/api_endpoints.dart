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

  // Creator Requests (Podcast theo yêu cầu)
  static const String incomingRequests = '/api/creator/requests/incoming';
  static String acceptRequest(String id) => '/api/creator/requests/$id/accept';
  static String rejectRequest(String id) => '/api/creator/requests/$id/reject';
  static String requestMilestones(String id) => '/api/requests/$id/milestones';
  static String submitMilestone(String milestoneId) =>
      '/api/creator/milestones/$milestoneId/submissions';

  // Comments & Likes
  static String podcastComments(String podcastId) =>
      '/api/podcasts/$podcastId/comments';
  static String podcastLikes(String podcastId) =>
      '/api/podcasts/$podcastId/likes';
  static String podcastLike(String podcastId) =>
      '/api/podcasts/$podcastId/like';
  static String commentById(String commentId) => '/api/comments/$commentId';
  static String commentLikes(String commentId) =>
      '/api/comments/$commentId/likes';
  static String commentLike(String commentId) =>
      '/api/comments/$commentId/like';
  static const String creatorCommentsContract = '/api/creator/comments';

  // Wallet & Bank (Contract endpoints - skipped or graceful fallback if BE not yet implemented)
  static const String creatorWallet = '/api/creator/wallet/balance';
  static const String creatorTransactions = '/api/creator/wallet/withdrawals';
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
}
