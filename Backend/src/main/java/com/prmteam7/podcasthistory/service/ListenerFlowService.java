package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.ListenerRequests.CommentCreate;
import com.prmteam7.podcasthistory.config.PackageFeatures;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.CommentUpdate;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.ListeningProgress;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.MembershipCheckout;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.ReportCreate;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.ReportUpdate;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.SeriesRequestCreate;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.SeriesRequestUpdate;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.CategoryItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.CommentItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.CommentLikeSummary;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.CreatorItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.FollowItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.LikeSummary;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.ListeningHistoryItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.MembershipCheckoutItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.MembershipPlanItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.PlaybackItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.PodcastItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.ReportItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.SavedPodcastItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.SeriesRequestItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.SubscriptionItem;
import com.prmteam7.podcasthistory.exception.InvalidFlowRequestException;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Category;
import com.prmteam7.podcasthistory.model.Comment;
import com.prmteam7.podcasthistory.model.CommentLike;
import com.prmteam7.podcasthistory.model.Follow;
import com.prmteam7.podcasthistory.model.ListeningHistory;
import com.prmteam7.podcasthistory.model.MembershipPlan;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.model.PodcastLike;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.Report;
import com.prmteam7.podcasthistory.model.SavedPodcast;
import com.prmteam7.podcasthistory.model.SeriesRequest;
import com.prmteam7.podcasthistory.model.Subscription;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.CategoryRepository;
import com.prmteam7.podcasthistory.repository.CommentRepository;
import com.prmteam7.podcasthistory.repository.CommentLikeRepository;
import com.prmteam7.podcasthistory.repository.FollowRepository;
import com.prmteam7.podcasthistory.repository.ListeningHistoryRepository;
import com.prmteam7.podcasthistory.repository.MembershipPlanRepository;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.PodcastLikeRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.ReportRepository;
import com.prmteam7.podcasthistory.repository.RequestResponseRepository;
import com.prmteam7.podcasthistory.repository.SavedPodcastRepository;
import com.prmteam7.podcasthistory.repository.SeriesRequestRepository;
import com.prmteam7.podcasthistory.repository.SubscriptionRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Set;
import java.util.HashSet;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Service
public class ListenerFlowService {

  private static final int DEFAULT_PAGE_SIZE = 20;
  private static final int MAX_PAGE_SIZE = 100;

  private final AppUserRepository userRepository;
  private final CategoryRepository categoryRepository;
  private final ProducerProfileRepository producerProfileRepository;
  private final PodcastRepository podcastRepository;
  private final PodcastLikeRepository podcastLikeRepository;
  private final CommentRepository commentRepository;
  private final CommentLikeRepository commentLikeRepository;
  private final ReportRepository reportRepository;
  private final RequestResponseRepository requestResponseRepository;
  private final FollowRepository followRepository;
  private final SavedPodcastRepository savedPodcastRepository;
  private final ListeningHistoryRepository listeningHistoryRepository;
  private final MembershipPlanRepository membershipPlanRepository;
  private final SubscriptionRepository subscriptionRepository;
  private final PaymentRepository paymentRepository;
  private final SeriesRequestRepository seriesRequestRepository;
  private final SepayService sepayService;
  private final R2PlaybackUrlService playbackUrlService;
  private final CommentRealtimeHub commentRealtimeHub;
  private final PackageFeatures packageFeatures;
  private final AudienceNotificationService audienceNotifications;

  public ListenerFlowService(
      AppUserRepository userRepository,
      CategoryRepository categoryRepository,
      ProducerProfileRepository producerProfileRepository,
      PodcastRepository podcastRepository,
      PodcastLikeRepository podcastLikeRepository,
      CommentRepository commentRepository,
      CommentLikeRepository commentLikeRepository,
      ReportRepository reportRepository,
      RequestResponseRepository requestResponseRepository,
      FollowRepository followRepository,
      SavedPodcastRepository savedPodcastRepository,
      ListeningHistoryRepository listeningHistoryRepository,
      MembershipPlanRepository membershipPlanRepository,
      SubscriptionRepository subscriptionRepository,
      PaymentRepository paymentRepository,
      SeriesRequestRepository seriesRequestRepository,
      SepayService sepayService,
      R2PlaybackUrlService playbackUrlService,
      CommentRealtimeHub commentRealtimeHub,
      PackageFeatures packageFeatures,
      AudienceNotificationService audienceNotifications) {
    this.userRepository = userRepository;
    this.categoryRepository = categoryRepository;
    this.producerProfileRepository = producerProfileRepository;
    this.podcastRepository = podcastRepository;
    this.podcastLikeRepository = podcastLikeRepository;
    this.commentRepository = commentRepository;
    this.commentLikeRepository = commentLikeRepository;
    this.reportRepository = reportRepository;
    this.requestResponseRepository = requestResponseRepository;
    this.followRepository = followRepository;
    this.savedPodcastRepository = savedPodcastRepository;
    this.listeningHistoryRepository = listeningHistoryRepository;
    this.membershipPlanRepository = membershipPlanRepository;
    this.subscriptionRepository = subscriptionRepository;
    this.paymentRepository = paymentRepository;
    this.seriesRequestRepository = seriesRequestRepository;
    this.sepayService = sepayService;
    this.playbackUrlService = playbackUrlService;
    this.commentRealtimeHub = commentRealtimeHub;
    this.packageFeatures = packageFeatures;
    this.audienceNotifications = audienceNotifications;
  }

  @Transactional(readOnly = true)
  public Page<PodcastItem> searchPodcasts(
      String search, UUID categoryId, UUID creatorId, UUID seriesId, int page, int size) {
    String query =
        search == null || search.isBlank()
            ? null
            : "%" + search.trim().toLowerCase(Locale.ROOT) + "%";
    return podcastRepository
        .searchPublished(query, categoryId, creatorId, seriesId, pageRequest(page, size))
        .map(this::toPodcastItem);
  }

  @Transactional(readOnly = true)
  public PodcastItem getPodcast(UUID userId, UUID podcastId) {
    return toPodcastItem(requireVisiblePodcast(userId, podcastId));
  }

  @Transactional(readOnly = true)
  public java.util.List<CategoryItem> getCategories() {
    return categoryRepository.findAllByIsActiveTrueOrderByNameAsc().stream()
        .map(this::toCategoryItem)
        .toList();
  }

  @Transactional(readOnly = true)
  public java.util.List<CreatorItem> getCreators(String search) {
    String query = search == null ? "" : search.trim();
    java.util.List<ProducerProfile> creators = query.isEmpty()
        ? producerProfileRepository.findAllByVerificationStatusIgnoreCaseOrderByChannelNameAsc("APPROVED")
        : producerProfileRepository
            .findAllByVerificationStatusIgnoreCaseAndChannelNameContainingIgnoreCaseOrderByChannelNameAsc(
                "APPROVED", query);
    return creators.stream().map(this::toCreatorItem).toList();
  }

  @Transactional(readOnly = true)
  public CreatorItem getCreator(UUID creatorId) {
    return toCreatorItem(requireCreator(creatorId));
  }

  @Transactional(readOnly = true)
  public PlaybackItem getPlayback(UUID userId, UUID podcastId) {
    Podcast podcast = requireVisiblePodcast(userId, podcastId);
    assertCanPlay(userId, podcast);
    String storedMedia = podcast.getMediaUrl();
    R2PlaybackUrlService.PlaybackUrl playback =
        playbackUrlService.create(storedMedia,
            packageFeatures.membershipsEnabled() && Boolean.TRUE.equals(podcast.getIsExclusive()));
    int resume =
        listeningHistoryRepository
            .findByUser_UserIdAndPodcast_PodcastId(userId, podcastId)
            .map(history -> history.getProgressSeconds() == null ? 0 : history.getProgressSeconds())
            .orElse(0);
    return new PlaybackItem(
        podcastId, playback.url(), playback.expiresAt(), podcast.getDurationSeconds(), resume);
  }

  @Transactional
  public ListeningHistoryItem saveProgress(UUID userId, UUID podcastId, ListeningProgress request) {
    lockListenerMutation(userId);
    Podcast podcast = requireVisiblePodcast(userId, podcastId);
    assertCanPlay(userId, podcast);
    AppUser user = requireUser(userId);
    ListeningHistory history =
        listeningHistoryRepository
            .findByUser_UserIdAndPodcast_PodcastId(userId, podcastId)
            .orElseGet(ListeningHistory::new);
    history.setUser(user);
    history.setPodcast(podcast);
    int max =
        podcast.getDurationSeconds() == null
            ? request.progressSeconds()
            : Math.max(podcast.getDurationSeconds(), 0);
    int progress = Math.min(request.progressSeconds(), max);
    history.setProgressSeconds(progress);
    history.setCompleted(
        Boolean.TRUE.equals(request.completed())
            || (podcast.getDurationSeconds() != null && progress >= podcast.getDurationSeconds()));
    history.setLastListenedAt(Instant.now());
    return toListeningItem(listeningHistoryRepository.save(history));
  }

  @Transactional(readOnly = true)
  public Page<ListeningHistoryItem> getListeningHistory(UUID userId, int page, int size) {
    return listeningHistoryRepository
        .findAllByUser_UserIdOrderByLastListenedAtDesc(userId, pageRequest(page, size))
        .map(this::toListeningItem);
  }

  @Transactional(readOnly = true)
  public ListeningHistoryItem getListeningHistory(UUID userId, UUID podcastId) {
    return listeningHistoryRepository
        .findByUser_UserIdAndPodcast_PodcastId(userId, podcastId)
        .map(this::toListeningItem)
        .orElseThrow(
            () -> new ResourceNotFoundException("Không tìm thấy lịch sử nghe podcast này."));
  }

  @Transactional
  public void deleteListeningHistory(UUID userId, UUID podcastId) {
    lockListenerMutation(userId);
    ListeningHistory history =
        listeningHistoryRepository
            .findByUser_UserIdAndPodcast_PodcastId(userId, podcastId)
            .orElseThrow(
                () -> new ResourceNotFoundException("Không tìm thấy lịch sử nghe podcast này."));
    listeningHistoryRepository.delete(history);
  }

  @Transactional(readOnly = true)
  public LikeSummary getLikeSummary(UUID userId, UUID podcastId) {
    requirePublishedPodcast(podcastId);
    return new LikeSummary(
        podcastId,
        podcastLikeRepository.countByPodcast_PodcastId(podcastId),
        podcastLikeRepository.existsByUser_UserIdAndPodcast_PodcastId(userId, podcastId));
  }

  @Transactional
  public LikeSummary likePodcast(UUID userId, UUID podcastId) {
    lockListenerMutation(userId);
    Podcast podcast = requirePublishedPodcast(podcastId);
    if (!podcastLikeRepository.existsByUser_UserIdAndPodcast_PodcastId(userId, podcastId)) {
      PodcastLike like = new PodcastLike();
      like.setUser(requireUser(userId));
      like.setPodcast(podcast);
      podcastLikeRepository.save(like);
    }
    return getLikeSummary(userId, podcastId);
  }

  @Transactional
  public LikeSummary unlikePodcast(UUID userId, UUID podcastId) {
    lockListenerMutation(userId);
    requirePublishedPodcast(podcastId);
    podcastLikeRepository
        .findByUser_UserIdAndPodcast_PodcastId(userId, podcastId)
        .ifPresent(podcastLikeRepository::delete);
    return getLikeSummary(userId, podcastId);
  }

  @Transactional(readOnly = true)
  public Page<CommentItem> getComments(UUID userId, UUID podcastId, int page, int size) {
    requirePublishedPodcast(podcastId);
    Page<Comment> comments = commentRepository.findVisibleByPodcastId(podcastId, pageRequest(page, size));
    List<UUID> commentIds = comments.getContent().stream().map(Comment::getCommentId).toList();
    if (commentIds.isEmpty()) return comments.map(comment -> toCommentItem(comment, 0, false));

    Map<UUID, Long> counts = new HashMap<>();
    for (Object[] row : commentLikeRepository.countByCommentIds(commentIds)) {
      counts.put((UUID) row[0], ((Number) row[1]).longValue());
    }
    Set<UUID> liked = new HashSet<>(commentLikeRepository.likedCommentIds(userId, commentIds));
    return comments.map(comment -> toCommentItem(comment,
        counts.getOrDefault(comment.getCommentId(), 0L), liked.contains(comment.getCommentId())));
  }

  @Transactional(readOnly = true)
  public CommentLikeSummary getCommentLikeSummary(UUID userId, UUID commentId) {
    Comment comment = requireComment(commentId);
    requirePublishedPodcast(comment.getPodcast().getPodcastId());
    return new CommentLikeSummary(commentId, commentLikeRepository.countByComment_CommentId(commentId),
        commentLikeRepository.existsByUser_UserIdAndComment_CommentId(userId, commentId));
  }

  @Transactional
  public CommentLikeSummary likeComment(UUID userId, UUID commentId) {
    lockListenerMutation(userId);
    Comment comment = requireComment(commentId);
    requirePublishedPodcast(comment.getPodcast().getPodcastId());
    if (!commentLikeRepository.existsByUser_UserIdAndComment_CommentId(userId, commentId)) {
      CommentLike like = new CommentLike();
      like.setUser(requireUser(userId));
      like.setComment(comment);
      commentLikeRepository.save(like);
    }
    return getCommentLikeSummary(userId, commentId);
  }

  @Transactional
  public CommentLikeSummary unlikeComment(UUID userId, UUID commentId) {
    lockListenerMutation(userId);
    Comment comment = requireComment(commentId);
    requirePublishedPodcast(comment.getPodcast().getPodcastId());
    commentLikeRepository.findByUser_UserIdAndComment_CommentId(userId, commentId)
        .ifPresent(commentLikeRepository::delete);
    return getCommentLikeSummary(userId, commentId);
  }

  @Transactional
  public CommentItem createComment(UUID userId, UUID podcastId, CommentCreate request) {
    Podcast podcast = requirePublishedPodcast(podcastId);
    Integer timestamp = request.timestampSeconds();
    if (timestamp != null && (timestamp < 0
        || (podcast.getDurationSeconds() != null && timestamp > podcast.getDurationSeconds()))) {
      throw new InvalidFlowRequestException("Mốc bình luận phải nằm trong khoảng thời gian của video.");
    }
    Comment comment = new Comment();
    comment.setUser(requireUser(userId));
    comment.setPodcast(podcast);
    comment.setContent(request.content().trim());
    comment.setTimestampSeconds(timestamp);
    comment.setStatus("VISIBLE");
    CommentItem response = toCommentItem(commentRepository.save(comment), 0, false);
    audienceNotifications.newComment(podcast, comment.getUser(), response.commentId());
    publishAfterCommit(podcastId, response);
    return response;
  }

  @Transactional
  public CommentItem updateComment(UUID userId, UUID commentId, CommentUpdate request) {
    Comment comment = requireComment(commentId);
    assertOwner(userId, comment.getUser().getUserId(), "Bạn chỉ được sửa bình luận của mình.");
    comment.setContent(request.content().trim());
    commentRepository.save(comment);
    return toCommentItem(comment, commentLikeRepository.countByComment_CommentId(commentId),
        commentLikeRepository.existsByUser_UserIdAndComment_CommentId(userId, commentId));
  }

  @Transactional
  public void deleteComment(UUID userId, UUID commentId) {
    Comment comment = requireComment(commentId);
    assertOwner(userId, comment.getUser().getUserId(), "Bạn chỉ được xóa bình luận của mình.");
    comment.setDeletedAt(Instant.now());
    comment.setStatus("DELETED");
    commentRepository.save(comment);
  }

  @Transactional(readOnly = true)
  public org.springframework.web.servlet.mvc.method.annotation.SseEmitter subscribeToComments(
      UUID podcastId) {
    requirePublishedPodcast(podcastId);
    return commentRealtimeHub.subscribe(podcastId);
  }

  @Transactional
  public ReportItem createReport(UUID userId, ReportCreate request) {
    String targetType = request.targetType().trim().toUpperCase(Locale.ROOT);
    Report report = new Report();
    report.setUser(requireUser(userId));
    if (targetType.equals("PODCAST")) {
      report.setPodcast(requirePublishedPodcast(request.targetId()));
    } else if (targetType.equals("COMMENT")) {
      report.setComment(requireComment(request.targetId()));
    } else {
      throw new InvalidFlowRequestException("targetType chỉ nhận PODCAST hoặc COMMENT.");
    }
    report.setReasonCode(request.reasonCode().trim().toUpperCase(Locale.ROOT));
    report.setDescription(trimToNull(request.description()));
    report.setStatus("PENDING");
    return toReportItem(reportRepository.save(report));
  }

  @Transactional(readOnly = true)
  public Page<ReportItem> getReports(UUID userId, int page, int size) {
    return reportRepository
        .findAllByUser_UserIdOrderByCreatedAtDesc(userId, pageRequest(page, size))
        .map(this::toReportItem);
  }

  @Transactional
  public ReportItem updateReport(UUID userId, UUID reportId, ReportUpdate request) {
    Report report = requireReport(userId, reportId);
    requirePending(report.getStatus(), "Chỉ sửa được báo cáo đang chờ xử lý.");
    report.setReasonCode(request.reasonCode().trim().toUpperCase(Locale.ROOT));
    report.setDescription(trimToNull(request.description()));
    return toReportItem(reportRepository.save(report));
  }

  @Transactional
  public void deleteReport(UUID userId, UUID reportId) {
    Report report = requireReport(userId, reportId);
    requirePending(report.getStatus(), "Chỉ rút được báo cáo đang chờ xử lý.");
    report.setStatus("WITHDRAWN");
    reportRepository.save(report);
  }

  @Transactional(readOnly = true)
  public Page<FollowItem> getFollows(UUID userId, int page, int size) {
    return followRepository
        .findAllByUser_UserIdOrderByCreatedAtDesc(userId, pageRequest(page, size))
        .map(this::toFollowItem);
  }

  @Transactional
  public FollowItem followCreator(UUID userId, UUID creatorId) {
    lockListenerMutation(userId);
    ProducerProfile creator = requireCreator(creatorId);
    assertOwnerNotSelf(userId, creator.getUser().getUserId());
    Follow follow =
        followRepository
            .findByUser_UserIdAndProducerProfile_ProducerProfileId(userId, creatorId)
            .orElseGet(
                () -> {
                  Follow created = new Follow();
                  created.setUser(requireUser(userId));
                  created.setProducerProfile(creator);
                  Follow saved = followRepository.save(created);
                  audienceNotifications.newFollower(creator.getUser(), saved.getUser(), creatorId);
                  return saved;
                });
    return toFollowItem(follow);
  }

  @Transactional
  public void unfollowCreator(UUID userId, UUID creatorId) {
    lockListenerMutation(userId);
    Follow follow =
        followRepository
            .findByUser_UserIdAndProducerProfile_ProducerProfileId(userId, creatorId)
            .orElseThrow(() -> new ResourceNotFoundException("Bạn chưa theo dõi creator này."));
    followRepository.delete(follow);
  }

  @Transactional(readOnly = true)
  public Page<SavedPodcastItem> getSavedPodcasts(UUID userId, int page, int size) {
    return savedPodcastRepository
        .findAllByUser_UserIdOrderByCreatedAtDesc(userId, pageRequest(page, size))
        .map(this::toSavedPodcastItem);
  }

  @Transactional
  public SavedPodcastItem savePodcast(UUID userId, UUID podcastId) {
    lockListenerMutation(userId);
    Podcast podcast = requirePublishedPodcast(podcastId);
    SavedPodcast saved =
        savedPodcastRepository
            .findByUser_UserIdAndPodcast_PodcastId(userId, podcastId)
            .orElseGet(
                () -> {
                  SavedPodcast created = new SavedPodcast();
                  created.setUser(requireUser(userId));
                  created.setPodcast(podcast);
                  return savedPodcastRepository.save(created);
                });
    return toSavedPodcastItem(saved);
  }

  @Transactional
  public void unsavePodcast(UUID userId, UUID podcastId) {
    lockListenerMutation(userId);
    SavedPodcast saved =
        savedPodcastRepository
            .findByUser_UserIdAndPodcast_PodcastId(userId, podcastId)
            .orElseThrow(
                () -> new ResourceNotFoundException("Podcast chưa có trong danh sách đã lưu."));
    savedPodcastRepository.delete(saved);
  }

  @Transactional(readOnly = true)
  public java.util.List<MembershipPlanItem> getMembershipPlans(UUID creatorId) {
    requireCreator(creatorId);
    if (!packageFeatures.membershipsEnabled()) return java.util.List.of();
    return membershipPlanRepository
        .findAllByProducerProfile_ProducerProfileIdAndStatusIgnoreCaseOrderByPriceAsc(
            creatorId, "ACTIVE")
        .stream()
        .map(this::toMembershipPlanItem)
        .toList();
  }

  @Transactional(readOnly = true)
  public java.util.List<SubscriptionItem> getSubscriptions(UUID userId) {
    var items = subscriptionRepository.findAllByUser_UserIdOrderByCreatedAtDesc(userId);
    if (items.isEmpty()) return java.util.List.of();
    var payments = paymentRepository.findLatestBySubscriptions(items.stream().map(Subscription::getSubscriptionId).toList())
        .stream().collect(java.util.stream.Collectors.toMap(p -> p.getSubscription().getSubscriptionId(), p -> p));
    return items.stream()
        .map(s -> toSubscriptionItem(s, payments.get(s.getSubscriptionId())))
        .toList();
  }

  @Transactional
  public MembershipCheckoutItem createMembershipCheckout(UUID userId, MembershipCheckout request) {
    packageFeatures.requireMemberships();
    MembershipPlan plan =
        membershipPlanRepository
            .lockById(request.membershipPlanId())
            .filter(candidate -> "ACTIVE".equalsIgnoreCase(candidate.getStatus()))
            .orElseThrow(
                () ->
                    new ResourceNotFoundException(
                        "Không tìm thấy membership plan đang hoạt động."));
    assertCreatorApproved(plan.getProducerProfile());
    if (subscriptionRepository
        .existsByUser_UserIdAndMembershipPlan_MembershipPlanIdAndStatusIgnoreCase(
            userId, plan.getMembershipPlanId(), "PENDING")) {
      throw new ResourceConflictException("Bạn đã có checkout đang chờ cho membership plan này.");
    }
    Instant now = Instant.now();
    if (subscriptionRepository
        .existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndStartAtBeforeAndEndAtAfter(
            userId, plan.getProducerProfile().getProducerProfileId(), "ACTIVE", now, now)) {
      throw new ResourceConflictException("Bạn đã có membership còn hiệu lực tại kênh này.");
    }

    Subscription subscription = new Subscription();
    subscription.setUser(requireUser(userId));
    subscription.setMembershipPlan(plan);
    subscription.setStartAt(now);
    subscription.setEndAt(now.plus(plan.getDurationDays(), java.time.temporal.ChronoUnit.DAYS));
    subscription.setStatus("PENDING");
    subscription.setAutoRenew(false);
    subscription = subscriptionRepository.save(subscription);

    Payment payment = new Payment();
    payment.setUser(requireUser(userId));
    payment.setSubscription(subscription);
    payment.setAmount(plan.getPrice());
    payment.setCurrency(plan.getCurrency());
    payment.setStatus("PENDING");
    payment.setProvider("SEPAY");
    String paymentCode = sepayService.generatePaymentCode();
    payment.setPaymentCode(paymentCode);
    String qrImageUrl = sepayService.createQrImageUrl(payment.getAmount(), paymentCode);
    payment = paymentRepository.save(payment);
    return new MembershipCheckoutItem(
        subscription.getSubscriptionId(),
        payment.getPaymentId(),
        payment.getPaymentCode(),
        qrImageUrl,
        payment.getAmount(),
        payment.getCurrency(),
        subscription.getStatus(),
        payment.getStatus(),
        "Checkout đã được tạo. Membership chỉ được kích hoạt sau khi cổng thanh toán xác nhận.");
  }

  @Transactional
  public void cancelSubscription(UUID userId, UUID subscriptionId) {
    // Same lock order as Admin reconciliation: payment first, then subscription.
    var linkedPayment =
        paymentRepository
            .findFirstBySubscription_SubscriptionIdOrderByCreatedAtDesc(subscriptionId)
            .flatMap(p -> paymentRepository.lockById(p.getPaymentId()));
    Subscription subscription =
        subscriptionRepository
            .lockById(subscriptionId)
            .orElseThrow(
                () -> new ResourceNotFoundException("Không tìm thấy membership subscription."));
    assertOwner(
        userId, subscription.getUser().getUserId(), "Bạn không có quyền sửa membership này.");
    if ("CANCELLED".equalsIgnoreCase(subscription.getStatus())
        || "EXPIRED".equalsIgnoreCase(subscription.getStatus())) {
      throw new ResourceConflictException("Membership đã kết thúc hoặc đã bị hủy.");
    }
    subscription.setStatus("CANCELLED");
    subscription.setAutoRenew(false);
    subscriptionRepository.save(subscription);
    linkedPayment
        .filter(payment -> "PENDING".equalsIgnoreCase(payment.getStatus()))
        .ifPresent(
            payment -> {
              payment.setStatus("CANCELLED");
              paymentRepository.save(payment);
            });
  }

  @Transactional(readOnly = true)
  public java.util.List<SeriesRequestItem> getSeriesRequests(UUID userId) {
    var items = seriesRequestRepository.findAllByUser_UserIdOrderByCreatedAtDesc(userId);
    if (items.isEmpty()) return java.util.List.of();
    var responses = requestResponseRepository.findAllBySeriesRequest_SeriesRequestIdIn(items.stream().map(SeriesRequest::getSeriesRequestId).toList())
        .stream().collect(java.util.stream.Collectors.toMap(r -> r.getSeriesRequest().getSeriesRequestId(), r -> r));
    return items.stream()
        .map(r -> toSeriesRequestItem(r, responses.get(r.getSeriesRequestId())))
        .toList();
  }

  @Transactional
  public SeriesRequestItem createSeriesRequest(
      UUID userId, UUID creatorId, SeriesRequestCreate request) {
    ProducerProfile creator = requireCreator(creatorId);
    assertCreatorApproved(creator);
    Subscription membership = null;
    if (packageFeatures.membershipsEnabled()) {
      membership = subscriptionRepository
          .findTopByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndEndAtAfterOrderByEndAtDesc(
              userId, creatorId, "ACTIVE", Instant.now())
          .filter(subscription -> !subscription.getStartAt().isAfter(Instant.now()))
          .orElseThrow(() -> new ResourceForbiddenException(
              "Bạn cần membership còn hiệu lực tại kênh này để gửi yêu cầu."));
    }
    SeriesRequest seriesRequest = new SeriesRequest();
    seriesRequest.setUser(requireUser(userId));
    seriesRequest.setProducerProfile(creator);
    seriesRequest.setRequestedTitle(request.requestedTitle().trim());
    seriesRequest.setDescription(request.description().trim());
    seriesRequest.setRequestFee(BigDecimal.ZERO);
    seriesRequest.setCurrency(membership == null ? "VND" : membership.getMembershipPlan().getCurrency());
    seriesRequest.setStatus("PENDING");
    return toSeriesRequestItem(seriesRequestRepository.save(seriesRequest));
  }

  @Transactional
  public SeriesRequestItem updateSeriesRequest(
      UUID userId, UUID requestId, SeriesRequestUpdate request) {
    SeriesRequest seriesRequest = requireSeriesRequest(userId, requestId);
    requirePending(seriesRequest.getStatus(), "Chỉ sửa được yêu cầu đang chờ creator phản hồi.");
    seriesRequest.setRequestedTitle(request.requestedTitle().trim());
    seriesRequest.setDescription(request.description().trim());
    return toSeriesRequestItem(seriesRequestRepository.save(seriesRequest));
  }

  @Transactional
  public void cancelSeriesRequest(UUID userId, UUID requestId) {
    SeriesRequest seriesRequest = requireSeriesRequest(userId, requestId);
    requirePending(seriesRequest.getStatus(), "Chỉ hủy được yêu cầu đang chờ creator phản hồi.");
    seriesRequest.setStatus("CANCELLED");
    seriesRequestRepository.save(seriesRequest);
  }

  private void assertCanPlay(UUID userId, Podcast podcast) {
    if (!packageFeatures.membershipsEnabled()) return;
    if (isOwner(userId, podcast) || !Boolean.TRUE.equals(podcast.getIsExclusive())) {
      return;
    }
    Instant now = Instant.now();
    UUID creatorId = podcast.getProducerProfile().getProducerProfileId();
    boolean subscribed =
        subscriptionRepository
            .existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndStartAtBeforeAndEndAtAfter(
                userId, creatorId, "ACTIVE", now, now);
    if (!subscribed) {
      throw new ResourceForbiddenException("Podcast này dành riêng cho thành viên của kênh.");
    }
  }

  @Transactional(readOnly = true)
  public void requireReferenceAccess(UUID userId, UUID podcastId) {
    assertCanPlay(userId, requireVisiblePodcast(userId, podcastId));
  }

  private boolean isOwner(UUID userId, Podcast podcast) {
    var profile = podcast.getProducerProfile();
    var owner = profile.getUser();
    return owner.getUserId().equals(userId)
        && Boolean.TRUE.equals(owner.getIsActive())
        && owner.getRole() != null
        && "CREATOR".equalsIgnoreCase(owner.getRole().getRoleCode())
        && "APPROVED".equalsIgnoreCase(profile.getVerificationStatus());
  }

  private Podcast requireVisiblePodcast(UUID userId, UUID podcastId) {
    requireUser(userId);
    Podcast podcast =
        podcastRepository
            .findByPodcastId(podcastId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
    if (!"DELETED".equalsIgnoreCase(podcast.getStatus()) && isOwner(userId, podcast)) {
      return podcast;
    }
    return requirePublishedPodcast(podcastId);
  }

  private Podcast requirePublishedPodcast(UUID podcastId) {
    return podcastRepository
        .findPublishedById(podcastId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast đã xuất bản."));
  }

  private AppUser requireUser(UUID userId) {
    return userRepository
        .findById(userId)
        .filter(user -> Boolean.TRUE.equals(user.getIsActive()))
        .orElseThrow(
            () -> new ResourceNotFoundException("Không tìm thấy tài khoản đang hoạt động."));
  }

  private ProducerProfile requireCreator(UUID creatorId) {
    ProducerProfile creator =
        producerProfileRepository
            .findById(creatorId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy creator."));
    assertCreatorApproved(creator);
    return creator;
  }

  private void assertCreatorApproved(ProducerProfile creator) {
    if (!"APPROVED".equalsIgnoreCase(creator.getVerificationStatus())) {
      throw new ResourceNotFoundException("Không tìm thấy creator đã được duyệt.");
    }
  }

  private Comment requireComment(UUID commentId) {
    return commentRepository
        .findVisibleById(commentId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bình luận."));
  }

  private Report requireReport(UUID userId, UUID reportId) {
    Report report =
        reportRepository
            .findById(reportId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy báo cáo."));
    assertOwner(userId, report.getUser().getUserId(), "Bạn không có quyền truy cập báo cáo này.");
    return report;
  }

  private SeriesRequest requireSeriesRequest(UUID userId, UUID requestId) {
    SeriesRequest request =
        seriesRequestRepository
            .findById(requestId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy yêu cầu podcast."));
    assertOwner(userId, request.getUser().getUserId(), "Bạn không có quyền truy cập yêu cầu này.");
    return request;
  }

  private void assertOwner(UUID currentUserId, UUID ownerId, String message) {
    if (!currentUserId.equals(ownerId)) {
      throw new ResourceForbiddenException(message);
    }
  }

  private void assertOwnerNotSelf(UUID userId, UUID creatorUserId) {
    if (userId.equals(creatorUserId)) {
      throw new ResourceConflictException("Bạn không thể theo dõi chính kênh của mình.");
    }
  }

  private void requirePending(String status, String message) {
    if (!"PENDING".equalsIgnoreCase(status)) {
      throw new ResourceConflictException(message);
    }
  }

  private Pageable pageRequest(int page, int size) {
    int safePage = Math.max(page, 0);
    int safeSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
    return PageRequest.of(safePage, safeSize, Sort.unsorted());
  }

  private void lockListenerMutation(UUID userId) {
    userRepository.lockById(userId)
        .filter(user -> Boolean.TRUE.equals(user.getIsActive()))
        .orElseThrow(() -> new ResourceForbiddenException("Tài khoản không hoạt động."));
  }

  private PodcastItem toPodcastItem(Podcast podcast) {
    var series = podcast.getSeries();
    var creator = podcast.getProducerProfile();
    var category = podcast.getCategory();
    return new PodcastItem(
        podcast.getPodcastId(),
        podcast.getTitle(),
        podcast.getDescription(),
        podcast.getMediaType(),
        podcast.getThumbnailUrl(),
        podcast.getDurationSeconds(),
        podcast.getEpisodeNumber(),
        packageFeatures.membershipsEnabled() && Boolean.TRUE.equals(podcast.getIsExclusive()),
        com.prmteam7.podcasthistory.enums.PodcastVisibility.fromExclusive(
            packageFeatures.membershipsEnabled() && Boolean.TRUE.equals(podcast.getIsExclusive())),
        podcast.getPublishedAt(),
        series == null ? null : series.getSeriesId(),
        series == null ? null : series.getTitle(),
        category.getCategoryId(),
        category.getName(),
        creator.getProducerProfileId(),
        creator.getChannelName());
  }

  private CategoryItem toCategoryItem(Category category) {
    return new CategoryItem(
        category.getCategoryId(),
        category.getName(),
        category.getSlug(),
        category.getDescription());
  }

  private CreatorItem toCreatorItem(ProducerProfile creator) {
    return new CreatorItem(
        creator.getProducerProfileId(),
        creator.getChannelName(),
        creator.getDescription(),
        creator.getAvatarUrl(),
        creator.getWebsiteUrl());
  }

  private ListeningHistoryItem toListeningItem(ListeningHistory history) {
    Podcast podcast = history.getPodcast();
    return new ListeningHistoryItem(
        history.getListeningHistoryId(),
        podcast.getPodcastId(),
        podcast.getTitle(),
        podcast.getThumbnailUrl(),
        history.getProgressSeconds(),
        history.getCompleted(),
        history.getLastListenedAt());
  }

  private CommentItem toCommentItem(Comment comment, long likeCount, boolean likedByMe) {
    AppUser user = comment.getUser();
    return new CommentItem(
        comment.getCommentId(),
        comment.getPodcast().getPodcastId(),
        user.getUserId(),
        user.getUsername(),
        user.getDisplayName(),
        user.getAvatarUrl(),
        comment.getContent(),
        comment.getTimestampSeconds(),
        comment.getStatus(),
        comment.getCreatedAt(),
        comment.getUpdatedAt(),
        likeCount,
        likedByMe);
  }

  private ReportItem toReportItem(Report report) {
    String targetType;
    UUID targetId;
    if (report.getPodcast() != null) {
      targetType = "PODCAST";
      targetId = report.getPodcast().getPodcastId();
    } else if (report.getComment() != null) {
      targetType = "COMMENT";
      targetId = report.getComment().getCommentId();
    } else {
      targetType = "LIVESTREAM";
      targetId = report.getLivestream().getLivestreamId();
    }
    return new ReportItem(
        report.getReportId(),
        targetType,
        targetId,
        report.getReasonCode(),
        report.getDescription(),
        report.getStatus(),
        report.getCreatedAt(),
        report.getResolvedAt());
  }

  private FollowItem toFollowItem(Follow follow) {
    ProducerProfile creator = follow.getProducerProfile();
    return new FollowItem(
        follow.getFollowId(),
        creator.getProducerProfileId(),
        creator.getChannelName(),
        creator.getDescription(),
        creator.getAvatarUrl(),
        follow.getCreatedAt());
  }

  private SavedPodcastItem toSavedPodcastItem(SavedPodcast saved) {
    Podcast podcast = saved.getPodcast();
    return new SavedPodcastItem(
        saved.getSavedPodcastId(),
        podcast.getPodcastId(),
        podcast.getTitle(),
        podcast.getThumbnailUrl(),
        podcast.getProducerProfile().getChannelName(),
        saved.getCreatedAt());
  }

  private MembershipPlanItem toMembershipPlanItem(MembershipPlan plan) {
    ProducerProfile creator = plan.getProducerProfile();
    return new MembershipPlanItem(
        plan.getMembershipPlanId(),
        creator.getProducerProfileId(),
        creator.getChannelName(),
        plan.getName(),
        plan.getDescription(),
        plan.getPrice(),
        plan.getCurrency(),
        plan.getDurationDays());
  }

  private SubscriptionItem toSubscriptionItem(Subscription subscription, Payment payment) {
    MembershipPlan plan = subscription.getMembershipPlan();
    return new SubscriptionItem(
        subscription.getSubscriptionId(),
        plan.getMembershipPlanId(),
        plan.getName(),
        plan.getProducerProfile().getProducerProfileId(),
        plan.getProducerProfile().getChannelName(),
        subscription.getStartAt(),
        subscription.getEndAt(),
        subscription.getStatus(),
        subscription.getAutoRenew(),
        payment == null ? null : payment.getPaymentId(),
        payment == null ? null : payment.getStatus());
  }

  private SeriesRequestItem toSeriesRequestItem(SeriesRequest request) {
    var creatorResponse =
        requestResponseRepository
            .findTopBySeriesRequest_SeriesRequestIdOrderByCreatedAtDesc(
                request.getSeriesRequestId())
            .orElse(null);
    return toSeriesRequestItem(request, creatorResponse);
  }

  private SeriesRequestItem toSeriesRequestItem(SeriesRequest request, com.prmteam7.podcasthistory.model.RequestResponse creatorResponse) {
    return new SeriesRequestItem(
        request.getSeriesRequestId(),
        request.getProducerProfile().getProducerProfileId(),
        request.getProducerProfile().getChannelName(),
        request.getRequestedTitle(),
        request.getDescription(),
        request.getRequestFee(),
        request.getCurrency(),
        request.getStatus(),
        request.getCreatedAt(),
        request.getRespondedAt(),
        creatorResponse == null ? null : creatorResponse.getResponseText(),
        creatorResponse == null ? null : creatorResponse.getResponseStatus());
  }

  private void publishAfterCommit(UUID podcastId, CommentItem comment) {
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
      TransactionSynchronizationManager.registerSynchronization(
          new TransactionSynchronization() {
            @Override
            public void afterCommit() {
              commentRealtimeHub.publish(podcastId, comment);
            }
          });
    } else {
      commentRealtimeHub.publish(podcastId, comment);
    }
  }

  private String trimToNull(String value) {
    if (value == null || value.isBlank()) {
      return null;
    }
    return value.trim();
  }
}
