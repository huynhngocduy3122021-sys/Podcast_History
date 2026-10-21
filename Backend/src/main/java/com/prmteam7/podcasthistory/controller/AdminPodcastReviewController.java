package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.CreatorRequests.ReviewNote;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastReviewItem;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastReviewResult;
import com.prmteam7.podcasthistory.service.PodcastReviewService;
import com.prmteam7.podcasthistory.service.AiModerationService;
import com.prmteam7.podcasthistory.dto.response.AiModerationItem;
import com.prmteam7.podcasthistory.dto.response.PodcastTranscriptItem;
import com.prmteam7.podcasthistory.service.PodcastTranscriptService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping({"/api/admin/podcasts", "/api/staff/podcasts"})
@Tag(name = "Admin - podcast moderation", description = "Duyệt podcast do Content Creator gửi")
@SecurityRequirement(name = "bearerAuth")
public class AdminPodcastReviewController {

  private final PodcastReviewService podcastReviewService;
  private final AiModerationService aiModerationService;
  private final PodcastTranscriptService transcriptService;

  public AdminPodcastReviewController(PodcastReviewService podcastReviewService,
      AiModerationService aiModerationService, PodcastTranscriptService transcriptService) {
    this.podcastReviewService = podcastReviewService;
    this.aiModerationService = aiModerationService;
    this.transcriptService = transcriptService;
  }

  @GetMapping("/{podcastId}/transcript")
  @Operation(summary = "Xem transcript của audio/video hiện tại")
  public PodcastTranscriptItem transcript(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
    return transcriptService.current(userId(jwt), podcastId);
  }

  @PostMapping("/{podcastId}/transcript")
  @Operation(summary = "Thử phiên âm lại audio/video hiện tại")
  public PodcastTranscriptItem retryTranscript(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
    return transcriptService.retry(userId(jwt), podcastId);
  }

  @GetMapping("/{podcastId}/ai-moderation")
  @Operation(summary = "Lịch sử AI kiểm duyệt podcast; current cho biết kết quả còn khớp nội dung")
  public org.springframework.data.domain.Page<AiModerationItem> aiModeration(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId,
      @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
    return aiModerationService.history(userId(jwt), podcastId, page, size);
  }

  @PostMapping("/{podcastId}/ai-moderation")
  @Operation(summary = "Chạy lại AI kiểm duyệt cho podcast đang chờ Admin")
  public AiModerationItem retryAiModeration(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
    return aiModerationService.retry(userId(jwt), podcastId);
  }

  @GetMapping("/page")
  @Operation(summary = "Danh sách podcast có phân trang")
  public org.springframework.data.domain.Page<PodcastReviewItem> page(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return podcastReviewService.page(userId(jwt), status, page, size);
  }

  @GetMapping("/{podcastId}")
  @Operation(summary = "Chi tiết podcast và 20 quyết định gần nhất")
  public com.prmteam7.podcasthistory.dto.response.AdminResponses.PodcastDetail detail(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
    return podcastReviewService.detail(userId(jwt), podcastId);
  }

  @GetMapping("/{podcastId}/preview")
  @Operation(summary = "Lấy signed video URL để duyệt, hiệu lực 5 phút")
  public com.prmteam7.podcasthistory.dto.response.AdminResponses.Preview preview(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
    return podcastReviewService.preview(userId(jwt), podcastId);
  }

  @GetMapping("/{podcastId}/reviews")
  @Operation(summary = "Lịch sử xét duyệt có phân trang")
  public org.springframework.data.domain.Page<
          com.prmteam7.podcasthistory.dto.response.AdminResponses.ReviewItem>
      reviews(
          @AuthenticationPrincipal Jwt jwt,
          @PathVariable UUID podcastId,
          @RequestParam(defaultValue = "0") int page,
          @RequestParam(defaultValue = "20") int size) {
    return podcastReviewService.history(userId(jwt), podcastId, page, size);
  }

  @GetMapping
  @Operation(
      summary = "Tất cả podcast hoặc lọc theo trạng thái",
      description =
          "Bỏ status để lấy tất cả. Hỗ trợ DRAFT, PENDING_REVIEW, APPROVED, REJECTED, PUBLISHED,"
              + " DELETED.")
  public List<PodcastReviewItem> listPodcasts(@RequestParam(required = false) String status) {
    return podcastReviewService.listPodcasts(status);
  }

  @GetMapping("/pending-review")
  @Operation(summary = "Danh sách podcast chờ Admin duyệt")
  public List<PodcastReviewItem> pendingReview() {
    return podcastReviewService.pendingReview();
  }

  @PostMapping("/{podcastId}/approve")
  @Operation(summary = "Duyệt podcast")
  public PodcastReviewResult approve(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID podcastId,
      @Valid @RequestBody(required = false) ReviewNote request) {
    return podcastReviewService.approve(
        userId(jwt), podcastId, request == null ? null : request.note());
  }

  @PostMapping("/{podcastId}/reject")
  @Operation(summary = "Từ chối podcast; Creator có thể chỉnh sửa và gửi lại")
  public PodcastReviewResult reject(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID podcastId,
      @Valid @RequestBody ReviewNote request) {
    return podcastReviewService.reject(userId(jwt), podcastId, request.note());
  }

  private UUID userId(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
