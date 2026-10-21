package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.*;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.enums.*;
import com.prmteam7.podcasthistory.exception.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.time.Instant;
import java.util.*;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class AdminContentService {
  private final AdminSupportService support;
  private final ReportRepository reports;
  private final PodcastRepository podcasts;
  private final CommentRepository comments;
  private final ModerationReviewRepository reviews;
  private final PodcastAppealRepository appeals;

  public AdminContentService(
      AdminSupportService support,
      ReportRepository reports,
      PodcastRepository podcasts,
      CommentRepository comments,
      ModerationReviewRepository reviews,
      PodcastAppealRepository appeals) {
    this.support = support;
    this.reports = reports;
    this.podcasts = podcasts;
    this.comments = comments;
    this.reviews = reviews;
    this.appeals = appeals;
  }

  public Page<ReportItem> listReports(UUID actor, String status, int page, int size) {
    support.actor(actor, false);
    return reports
        .findAll(AdminSupportService.status(status), AdminSupportService.page(page, size))
        .map(r -> reportItem(r, false));
  }

  public ReportItem report(UUID actor, UUID id) {
    support.actor(actor, false);
    return reportItem(
        reports
            .findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy report.")),
        true);
  }

  @Transactional
  public ReportItem claim(UUID actor, UUID id) {
    var reviewer = support.actor(actor, false);
    var report = lockReport(id);
    AdminSupportService.state(report.getStatus(), "PENDING", "UNDER_REVIEW");
    if (report.getAssignedTo() != null
        && !report.getAssignedTo().getUserId().equals(actor)
        && !reviewer.getRole().getRoleCode().equals("ADMIN"))
      throw new ResourceConflictException("Report đã được người khác nhận xử lý.");
    report.setAssignedTo(reviewer);
    report.setStatus("UNDER_REVIEW");
    support.audit(reviewer, "CLAIM_REPORT", "REPORT", id, "Nhận xử lý report.");
    return reportItem(report, true);
  }

  @Transactional
  public ReportItem resolve(UUID actor, UUID id, ResolveReport request) {
    var reviewer = support.actor(actor, false);
    var report = lockReport(id);
    AdminSupportService.state(report.getStatus(), "PENDING", "UNDER_REVIEW");
    if (report.getAssignedTo() != null
        && !report.getAssignedTo().getUserId().equals(actor)
        && !reviewer.getRole().getRoleCode().equals("ADMIN"))
      throw new ResourceConflictException("Report thuộc người xử lý khác.");
    report.setAssignedTo(reviewer);
    if (request.action() != ReportAction.DISMISS) {
      if (report.getPodcast() != null) {
        Podcast podcast = lockPodcast(report.getPodcast().getPodcastId());
        AdminSupportService.state(podcast.getStatus(), "APPROVED", "PUBLISHED", "HIDDEN");
        podcast.setStatus(request.action() == ReportAction.DELETE_CONTENT ? "DELETED" : "HIDDEN");
        podcast.setPublishedAt(null);
        recordReview(reviewer, podcast, report, request.action().name(), request.note());
        support.notify(
            podcast.getProducerProfile().getUser(),
            "PODCAST_MODERATION",
            "Nội dung bị xử lý",
            request.note());
      } else if (report.getComment() != null) {
        Comment comment =
            comments
                .lockById(report.getComment().getCommentId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy comment."));
        comment.setStatus(request.action() == ReportAction.DELETE_CONTENT ? "DELETED" : "HIDDEN");
        if (request.action() == ReportAction.DELETE_CONTENT) comment.setDeletedAt(Instant.now());
        recordReview(reviewer, null, report, request.action().name(), request.note());
        support.notify(
            comment.getUser(), "COMMENT_MODERATION", "Bình luận bị xử lý", request.note());
      } else
        throw new ResourceConflictException("Chưa hỗ trợ xử lý nội dung livestream qua API này.");
    } else recordReview(reviewer, null, report, "DISMISS", request.note());
    report.setStatus(request.action() == ReportAction.DISMISS ? "DISMISSED" : "RESOLVED");
    report.setResolvedAt(Instant.now());
    support.audit(reviewer, "RESOLVE_REPORT", "REPORT", id, request.note());
    support.notify(
        report.getUser(),
        "REPORT_RESULT",
        "Kết quả báo cáo",
        request.action() + ": " + request.note());
    return reportItem(reports.save(report), true);
  }

  @Transactional
  public void moderate(UUID actor, UUID id, String action, String note) {
    var reviewer = support.actor(actor, false);
    Podcast podcast = lockPodcast(id);
    if (action.equals("RESTORE")) {
      AdminSupportService.state(podcast.getStatus(), "HIDDEN");
      podcast.setStatus("PENDING_REVIEW");
    } else {
      AdminSupportService.state(
          podcast.getStatus(),
          "APPROVED",
          "PUBLISHED",
          "PENDING_REVIEW",
          "REJECTED",
          "DRAFT",
          "HIDDEN");
      podcast.setStatus(action.equals("DELETE") ? "DELETED" : "HIDDEN");
    }
    podcast.setPublishedAt(null);
    recordReview(reviewer, podcast, null, action, note);
    support.audit(reviewer, action, "PODCAST", id, note);
    support.notify(
        podcast.getProducerProfile().getUser(),
        "PODCAST_MODERATION",
        "Thay đổi trạng thái podcast",
        action + ": " + note);
  }

  public Page<AppealItem> listAppeals(UUID actor, String status, int page, int size) {
    support.actor(actor, false);
    return appeals
        .findAll(AdminSupportService.status(status), AdminSupportService.page(page, size))
        .map(this::appealItem);
  }

  public AppealItem appeal(UUID actor, UUID id) {
    support.actor(actor, false);
    return appealItem(
        appeals
            .findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy khiếu nại.")));
  }

  @Transactional
  public AppealItem resolveAppeal(UUID actor, UUID id, ResolveAppeal request) {
    var reviewer = support.actor(actor, false);
    // Lock podcast before appeal, matching the create path and avoiding lock-order inversion.
    var existing =
        appeals
            .findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy khiếu nại."));
    Podcast podcast = lockPodcast(existing.getPodcast().getPodcastId());
    var appeal =
        appeals
            .lockById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy khiếu nại."));
    AdminSupportService.state(appeal.getStatus(), "PENDING");
    if (request.decision() == CaseDecision.ACCEPT) {
      AdminSupportService.state(podcast.getStatus(), "HIDDEN", "REJECTED");
      if (podcast.getMediaUrl() == null || podcast.getMediaUrl().isBlank())
        throw new ResourceConflictException("Podcast chưa có video để xét duyệt lại.");
      podcast.setStatus("PENDING_REVIEW");
      podcast.setPublishedAt(null);
    }
    appeal.setStatus(request.decision() == CaseDecision.ACCEPT ? "ACCEPTED" : "REJECTED");
    appeal.setReviewer(reviewer);
    appeal.setNote(request.note());
    appeal.setResolvedAt(Instant.now());
    recordReview(reviewer, podcast, null, "APPEAL_" + request.decision(), request.note());
    support.audit(reviewer, "RESOLVE_APPEAL", "PODCAST_APPEAL", id, request.note());
    support.notify(
        appeal.getApplicant(),
        "APPEAL_RESULT",
        "Kết quả khiếu nại",
        request.decision() + ": " + request.note());
    return appealItem(appeals.save(appeal));
  }

  @Transactional
  public AppealItem createAppeal(UUID userId, UUID podcastId, String reason) {
    var user = support.user(userId);
    Podcast podcast = lockPodcast(podcastId);
    if (!podcast.getProducerProfile().getUser().getUserId().equals(userId))
      throw new ResourceForbiddenException("Không phải podcast của bạn.");
    AdminSupportService.state(podcast.getStatus(), "HIDDEN", "REJECTED");
    if (appeals.existsByPodcast_PodcastIdAndStatus(podcastId, "PENDING"))
      throw new ResourceConflictException("Đã có khiếu nại đang chờ.");
    PodcastAppeal appeal = new PodcastAppeal();
    appeal.setPodcast(podcast);
    appeal.setApplicant(user);
    appeal.setReason(reason);
    appeal.setStatus("PENDING");
    return appealItem(appeals.save(appeal));
  }

  public Page<AppealItem> myAppeals(UUID userId, UUID podcastId, int page, int size) {
    var user = support.user(userId);
    var podcast =
        podcasts
            .findByPodcastId(podcastId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
    if (!podcast.getProducerProfile().getUser().getUserId().equals(user.getUserId()))
      throw new ResourceForbiddenException("Không phải podcast của bạn.");
    return appeals
        .findAll(
            (r, q, c) -> c.equal(r.get("podcast").get("podcastId"), podcastId),
            AdminSupportService.page(page, size))
        .map(this::appealItem);
  }

  private void recordReview(
      AppUser reviewer, Podcast podcast, Report report, String decision, String note) {
    ModerationReview review = new ModerationReview();
    review.setReviewerUser(reviewer);
    review.setPodcast(podcast);
    review.setReport(report);
    review.setDecision(decision);
    review.setNote(note);
    review.setReviewedAt(Instant.now());
    reviews.save(review);
  }

  private Podcast lockPodcast(UUID id) {
    return podcasts
        .lockById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
  }

  private Report lockReport(UUID id) {
    return reports
        .lockById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy report."));
  }

  private ReviewItem reviewItem(ModerationReview r) {
    return new ReviewItem(
        r.getModerationReviewId(),
        r.getReviewerUser().getUserId(),
        r.getReviewerUser().getDisplayName(),
        r.getDecision(),
        r.getNote(),
        r.getReviewedAt());
  }

  private ReportItem reportItem(Report r, boolean detail) {
    String type =
        r.getPodcast() != null ? "PODCAST" : r.getComment() != null ? "COMMENT" : "LIVESTREAM";
    UUID target =
        r.getPodcast() != null
            ? r.getPodcast().getPodcastId()
            : r.getComment() != null
                ? r.getComment().getCommentId()
                : r.getLivestream().getLivestreamId();
    return new ReportItem(
        r.getReportId(),
        r.getUser().getUserId(),
        r.getUser().getDisplayName(),
        type,
        target,
        r.getReasonCode(),
        r.getDescription(),
        r.getStatus(),
        r.getAssignedTo() == null ? null : r.getAssignedTo().getUserId(),
        r.getCreatedAt(),
        r.getResolvedAt(),
        detail
            ? reviews.findAllByReport_ReportIdOrderByReviewedAtDesc(r.getReportId()).stream()
                .map(this::reviewItem)
                .toList()
            : List.of());
  }

  private AppealItem appealItem(PodcastAppeal a) {
    return new AppealItem(
        a.getAppealId(),
        a.getPodcast().getPodcastId(),
        a.getApplicant().getUserId(),
        a.getReason(),
        a.getStatus(),
        a.getNote(),
        a.getReviewer() == null ? null : a.getReviewer().getUserId(),
        a.getCreatedAt(),
        a.getResolvedAt());
  }
}
