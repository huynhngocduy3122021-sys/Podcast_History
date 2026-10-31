package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.request.CreateDisputeRequest;
import com.prmteam7.podcasthistory.dto.request.ConfirmDisputeRequest;
import com.prmteam7.podcasthistory.dto.response.DisputeResponse;
import com.prmteam7.podcasthistory.dto.response.MilestoneSubmissionResponse;
import com.prmteam7.podcasthistory.dto.response.ContractWorkflowResponses;
import com.prmteam7.podcasthistory.service.PodcastRequestService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/milestones")
@Tag(name = "Podcast milestone collaboration")
@SecurityRequirement(name = "bearerAuth")
public class MilestoneDisputeController {

    private final PodcastRequestService podcastRequestService;

    public MilestoneDisputeController(PodcastRequestService podcastRequestService) {
        this.podcastRequestService = podcastRequestService;
    }

    @GetMapping("/{milestoneId}/submissions")
    @Operation(summary = "Hai bên hoặc Staff/Admin xem lịch sử bàn giao")
    public List<MilestoneSubmissionResponse> getSubmissions(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId) {
        return podcastRequestService.getMilestoneSubmissions(userId(jwt), milestoneId);
    }

    @GetMapping("/{milestoneId}/submissions/{submissionId}/media")
    @Operation(summary = "Cấp URL xem file bàn giao riêng tư trong 5 phút cho hai bên hoặc Staff/Admin")
    public ContractWorkflowResponses.MediaUrl media(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId,
            @PathVariable UUID submissionId) {
        return podcastRequestService.getMilestoneMediaUrl(userId(jwt), milestoneId, submissionId);
    }

    @PostMapping("/{milestoneId}/disputes")
    @Operation(summary = "Listener hoặc Creator mở tranh chấp để Staff xử lý")
    public ResponseEntity<DisputeResponse> raiseDispute(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId,
            @Valid @RequestBody CreateDisputeRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(podcastRequestService.raiseDispute(userId(jwt), milestoneId, request.reason(), request.listenerWinAction()));
    }

    @PostMapping("/{milestoneId}/disputes/{disputeId}/confirm")
    @Operation(summary = "Bên còn lại xác nhận tranh chấp trong 3 ngày")
    public DisputeResponse confirm(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID milestoneId,
            @PathVariable UUID disputeId, @RequestBody(required = false) ConfirmDisputeRequest request) {
        return podcastRequestService.confirmMilestoneDispute(userId(jwt), milestoneId, disputeId,
                request == null ? null : request.listenerWinAction());
    }

    @PostMapping("/{milestoneId}/disputes/{disputeId}/withdraw")
    @Operation(summary = "Người mở rút tranh chấp đợt trước khi bên kia xác nhận")
    public DisputeResponse withdraw(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID milestoneId,
            @PathVariable UUID disputeId) {
        return podcastRequestService.withdrawMilestoneDispute(userId(jwt), milestoneId, disputeId);
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
