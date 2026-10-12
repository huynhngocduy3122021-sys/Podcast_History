package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.request.CreatorRequests.ReviewNote;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastReviewItem;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastReviewResult;
import com.prmteam7.podcasthistory.service.PodcastReviewService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/admin/podcasts")
@Tag(name = "Admin - podcast moderation", description = "Duyệt podcast do Content Creator gửi")
@SecurityRequirement(name = "bearerAuth")
public class AdminPodcastReviewController {

    private final PodcastReviewService podcastReviewService;

    public AdminPodcastReviewController(PodcastReviewService podcastReviewService) {
        this.podcastReviewService = podcastReviewService;
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
        return podcastReviewService.approve(userId(jwt), podcastId, request == null ? null : request.note());
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
