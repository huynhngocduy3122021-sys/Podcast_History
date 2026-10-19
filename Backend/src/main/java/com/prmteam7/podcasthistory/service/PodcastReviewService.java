package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastReviewItem;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastReviewResult;
import com.prmteam7.podcasthistory.exception.InvalidFlowRequestException;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.ModerationReview;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.model.Series;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ModerationReviewRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PodcastReviewService {

  private final AppUserRepository appUserRepository;
  private final PodcastRepository podcastRepository;
  private final ModerationReviewRepository moderationReviewRepository;
  private final AdminSupportService support;
  private final R2PlaybackUrlService playback;

  public PodcastReviewService(
      AppUserRepository appUserRepository,
      PodcastRepository podcastRepository,
      ModerationReviewRepository moderationReviewRepository,
      AdminSupportService support,
      R2PlaybackUrlService playback) {
    this.appUserRepository = appUserRepository;
    this.podcastRepository = podcastRepository;
    this.moderationReviewRepository = moderationReviewRepository;
    this.support = support;
    this.playback = playback;
  }

  @Transactional(readOnly = true)
  public org.springframework.data.domain.Page<PodcastReviewItem> page(
      UUID actor, String status, int page, int size) {
    support.actor(actor, false);
    return podcastRepository
        .findAll(AdminSupportService.status(status), AdminSupportService.page(page, size))
        .map(this::toReviewItem);
  }

  @Transactional(readOnly = true)
  public com.prmteam7.podcasthistory.dto.response.AdminResponses.PodcastDetail detail(
      UUID actor, UUID id) {
    support.actor(actor, false);
    Podcast p =
        podcastRepository
            .findByPodcastId(id)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
    return new com.prmteam7.podcasthistory.dto.response.AdminResponses.PodcastDetail(
        toReviewItem(p), history(actor, id, 0, 20).getContent());
  }

  @Transactional(readOnly = true)
  public com.prmteam7.podcasthistory.dto.response.AdminResponses.Preview preview(
      UUID actor, UUID id) {
    support.actor(actor, false);
    Podcast p =
        podcastRepository
            .findByPodcastId(id)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
    AdminSupportService.state(
        p.getStatus(), "DRAFT", "PENDING_REVIEW", "APPROVED", "PUBLISHED", "REJECTED", "HIDDEN");
    supportPreviewMedia(p);
    var url = playback.create(p.getMediaUrl(), true);
    return new com.prmteam7.podcasthistory.dto.response.AdminResponses.Preview(
        id, url.url(), url.expiresAt());
  }

  private void supportPreviewMedia(Podcast p) {
    if (p.getMediaUrl() == null || p.getMediaUrl().isBlank())
      throw new ResourceNotFoundException("Podcast chưa có media video hoặc audio.");
  }

  @Transactional(readOnly = true)
  public org.springframework.data.domain.Page<
          com.prmteam7.podcasthistory.dto.response.AdminResponses.ReviewItem>
      history(UUID actor, UUID id, int page, int size) {
    support.actor(actor, false);
    return reviewHistory(id, page, size);
  }

  @Transactional(readOnly = true)
  public org.springframework.data.domain.Page<
          com.prmteam7.podcasthistory.dto.response.AdminResponses.ReviewItem>
      creatorHistory(UUID actor, UUID id, int page, int size) {
    var user = support.user(actor);
    var podcast =
        podcastRepository
            .findByPodcastId(id)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
    if (!podcast.getProducerProfile().getUser().getUserId().equals(user.getUserId()))
      throw new ResourceForbiddenException("Podcast không thuộc kênh của bạn.");
    return reviewHistory(id, page, size);
  }

  private org.springframework.data.domain.Page<
          com.prmteam7.podcasthistory.dto.response.AdminResponses.ReviewItem>
      reviewHistory(UUID id, int page, int size) {
    if (!podcastRepository.existsById(id))
      throw new ResourceNotFoundException("Không tìm thấy podcast.");
    return moderationReviewRepository
        .findAllByPodcast_PodcastIdOrderByReviewedAtDesc(id, AdminSupportService.page(page, size))
        .map(
            r ->
                new com.prmteam7.podcasthistory.dto.response.AdminResponses.ReviewItem(
                    r.getModerationReviewId(),
                    r.getReviewerUser().getUserId(),
                    r.getReviewerUser().getDisplayName(),
                    r.getDecision(),
                    r.getNote(),
                    r.getReviewedAt()));
  }

  @Transactional(readOnly = true)
  public List<PodcastReviewItem> listPodcasts(String status) {
    if (status == null || status.isBlank()) {
      return podcastRepository.findAllByOrderByCreatedAtDesc().stream()
          .map(this::toReviewItem)
          .toList();
    }
    String normalized = status.trim().toUpperCase(Locale.ROOT);
    if (!List.of(
            "DRAFT", "PENDING_REVIEW", "APPROVED", "REJECTED", "PUBLISHED", "DELETED", "HIDDEN")
        .contains(normalized)) {
      throw new InvalidFlowRequestException("Trạng thái podcast không hợp lệ.");
    }
    return podcastRepository.findAllByStatusIgnoreCaseOrderByCreatedAtDesc(normalized).stream()
        .map(this::toReviewItem)
        .toList();
  }

  @Transactional(readOnly = true)
  public List<PodcastReviewItem> pendingReview() {
    return podcastRepository.findAllByStatusIgnoreCaseOrderByUpdatedAtAsc("PENDING_REVIEW").stream()
        .map(this::toReviewItem)
        .toList();
  }

  @Transactional
  public PodcastReviewResult approve(UUID reviewerId, UUID podcastId, String note) {
    return review(reviewerId, podcastId, "APPROVED", note);
  }

  @Transactional
  public PodcastReviewResult reject(UUID reviewerId, UUID podcastId, String note) {
    if (note == null || note.isBlank()) {
      throw new InvalidFlowRequestException("Vui lòng nhập lý do từ chối podcast.");
    }
    return review(reviewerId, podcastId, "REJECTED", note);
  }

  private PodcastReviewResult review(
      UUID reviewerId, UUID podcastId, String decision, String note) {
    AppUser reviewer = support.actor(reviewerId, false);

    Podcast podcast =
        podcastRepository
            .lockById(podcastId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
    if (!"PENDING_REVIEW".equalsIgnoreCase(podcast.getStatus())) {
      throw new ResourceConflictException("Podcast không ở trạng thái chờ duyệt.");
    }

    Instant reviewedAt = Instant.now();
    podcast.setStatus(decision);
    podcast.setPublishedAt("APPROVED".equals(decision) ? reviewedAt : null);
    podcastRepository.save(podcast);

    ModerationReview review = new ModerationReview();
    review.setPodcast(podcast);
    review.setReviewerUser(reviewer);
    review.setDecision(decision);
    review.setNote(note == null || note.isBlank() ? null : note.trim());
    review.setReviewedAt(reviewedAt);
    moderationReviewRepository.save(review);
    support.audit(reviewer, decision, "PODCAST", podcastId, review.getNote());
    support.notify(
        podcast.getProducerProfile().getUser(),
        "PODCAST_REVIEW",
        "Kết quả duyệt podcast",
        podcast.getTitle()
            + ": "
            + decision
            + (review.getNote() == null ? "" : " — " + review.getNote()));

    return new PodcastReviewResult(podcastId, decision, review.getNote(), reviewedAt);
  }

  private PodcastReviewItem toReviewItem(Podcast podcast) {
    Series series = podcast.getSeries();
    return new PodcastReviewItem(
        podcast.getPodcastId(),
        podcast.getProducerProfile().getProducerProfileId(),
        podcast.getProducerProfile().getChannelName(),
        podcast.getCategory().getCategoryId(),
        podcast.getCategory().getName(),
        series == null ? null : series.getSeriesId(),
        series == null ? null : series.getTitle(),
        podcast.getTitle(),
        podcast.getDescription(),
        podcast.getMediaUrl(),
        podcast.getMediaType(),
        podcast.getThumbnailUrl(),
        podcast.getDurationSeconds(),
        podcast.getIsExclusive(),
        com.prmteam7.podcasthistory.enums.PodcastVisibility.fromExclusive(podcast.getIsExclusive()),
        podcast.getStatus(),
        podcast.getUpdatedAt());
  }
}
