package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.Note;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.service.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/creator/podcasts/{podcastId}")
@Tag(name = "Content Creator - reviews and appeals")
@SecurityRequirement(name = "bearerAuth")
public class CreatorAppealController {
  private final AdminContentService content;
  private final PodcastReviewService reviews;

  public CreatorAppealController(AdminContentService content, PodcastReviewService reviews) {
    this.content = content;
    this.reviews = reviews;
  }

  @GetMapping("/reviews")
  @Operation(summary = "Creator xem lịch sử duyệt và lý do reject của mình")
  public Page<ReviewItem> reviews(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID podcastId,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return reviews.creatorHistory(id(jwt), podcastId, page, size);
  }

  @PostMapping("/appeals")
  @ResponseStatus(HttpStatus.CREATED)
  @Operation(summary = "Gửi khiếu nại podcast HIDDEN/REJECTED, note là lý do")
  public AppealItem create(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID podcastId,
      @Valid @RequestBody Note body) {
    return content.createAppeal(id(jwt), podcastId, body.note());
  }

  @GetMapping("/appeals")
  @Operation(summary = "Lịch sử khiếu nại của podcast mình sở hữu")
  public Page<AppealItem> list(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID podcastId,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return content.myAppeals(id(jwt), podcastId, page, size);
  }

  private UUID id(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
