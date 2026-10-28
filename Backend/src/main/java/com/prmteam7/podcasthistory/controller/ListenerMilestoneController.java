package com.prmteam7.podcasthistory.controller;

import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.request.MilestoneRevisionRequest;
import com.prmteam7.podcasthistory.dto.response.MilestoneApprovalResponse;
import com.prmteam7.podcasthistory.service.PodcastRequestService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/listener/milestones")
@Tag(name = "Listener - milestones")
@SecurityRequirement(name = "bearerAuth")
public class ListenerMilestoneController {

    private final PodcastRequestService podcastRequestService;

    public ListenerMilestoneController(PodcastRequestService podcastRequestService) {
        this.podcastRequestService = podcastRequestService;
    }

    @PostMapping("/{milestoneId}/approve")
    @Operation(summary = "Listener nghiệm thu đợt; hợp đồng escrow giải ngân ví và ghi Payment PAID")
    public MilestoneApprovalResponse approve(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId) {
        return podcastRequestService.approveMilestone(userId(jwt), milestoneId);
    }

    @PostMapping("/{milestoneId}/revision")
    @Operation(summary = "Listener yêu cầu Creator chỉnh sửa mốc")
    public ResponseEntity<Void> requestRevision(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId,
            @Valid @RequestBody MilestoneRevisionRequest request) {
        podcastRequestService.requestMilestoneRevision(userId(jwt), milestoneId, request.reason());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{milestoneId}/reject")
    @Operation(summary = "Listener từ chối lần bàn giao hiện tại, yêu cầu Creator làm lại (tối đa 3 lượt mỗi đợt)")
    public ResponseEntity<Void> rejectSubmission(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId,
            @Valid @RequestBody MilestoneRevisionRequest request) {
        podcastRequestService.requestMilestoneRevision(userId(jwt), milestoneId, request.reason());
        return ResponseEntity.noContent().build();
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
