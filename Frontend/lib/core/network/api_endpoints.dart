class ApiEndpoints {
  // Base URLs
  static const String defaultBaseUrl = 'http://localhost:8081';
  static const String emulatorBaseUrl = 'http://10.0.2.2:8081';

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
  static String creatorSeriesPodcasts(String id) => '/api/creator/series/$id/podcasts';

  static const String creatorPodcasts = '/api/creator/podcasts';
  static String creatorPodcastById(String id) => '/api/creator/podcasts/$id';
  static String creatorPodcastVideo(String id) => '/api/creator/podcasts/$id/video';
  static String creatorPodcastSubmit(String id) => '/api/creator/podcasts/$id/submit';
  static String creatorPodcastSeries(String id) => '/api/creator/podcasts/$id/series';
  static String creatorPodcastReferences(String id) => '/api/creator/podcasts/$id/references';
  static String creatorPodcastReviews(String id) => '/api/creator/podcasts/$id/reviews';
  static String creatorPodcastAppeals(String id) => '/api/creator/podcasts/$id/appeals';

  // Uploads
  static const String uploads = '/api/uploads';

  // Creator Requests (Podcast theo yêu cầu)
  static const String incomingRequests = '/api/creator/requests/incoming';
  static String acceptRequest(String id) => '/api/creator/requests/$id/accept';
  static String rejectRequest(String id) => '/api/creator/requests/$id/reject';
  static String requestMilestones(String id) => '/api/requests/$id/milestones';
  static String submitMilestone(String milestoneId) => '/api/creator/milestones/$milestoneId/submissions';

  // Comments
  static String podcastComments(String podcastId) => '/api/podcasts/$podcastId/comments';
  static String commentById(String commentId) => '/api/comments/$commentId';
  static const String creatorCommentsContract = '/api/v1/creator/comments';

  // Wallet & Bank (Contract endpoints - skipped or graceful fallback if BE not yet implemented)
  static const String creatorWallet = '/api/v1/creator/wallet';
  static const String creatorTransactions = '/api/v1/creator/wallet/transactions';
  static const String creatorReleaseFunds = '/api/v1/creator/wallet/release-funds';
  static const String creatorWithdraw = '/api/v1/creator/wallet/withdraw';
  static const String creatorBankAccounts = '/api/v1/creator/bank-accounts';
  static String creatorBankAccountById(String id) => '/api/v1/creator/bank-accounts/$id';

  // Forms & Premium (Contract endpoints)
  static const String creatorForms = '/api/v1/creator/forms';
  static const String creatorUpgradePremium = '/api/v1/creator/upgrade-premium';
}
