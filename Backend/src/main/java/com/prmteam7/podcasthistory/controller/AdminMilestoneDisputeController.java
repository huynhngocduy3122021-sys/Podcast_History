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

import com.prmteam7.podcasthistory.dto.request.ResolveDisputeRequest;
import com.prmteam7.podcasthistory.dto.response.DisputeResponse;
import com.prmteam7.podcasthistory.service.PodcastRequestService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/admin/milestone-disputes")
@Tag(name = "Staff/Admin - podcast milestone disputes")
@SecurityRequirement(name = "bearerAuth")
public class AdminMilestoneDisputeController {

    private final PodcastRequestService podcastRequestService;

    public AdminMilestoneDisputeController(PodcastRequestService podcastRequestService) {
        this.podcastRequestService = podcastRequestService;
    }

    @GetMapping("/open")
    @Operation(summary = "Staff/Admin xem các tranh chấp đợt đang chờ")
    public List<DisputeResponse> getOpen(@AuthenticationPrincipal Jwt jwt) {
        return podcastRequestService.getOpenDisputes(userId(jwt));
    }

    @PostMapping("/{disputeId}/resolve")
    @Operation(summary = "Staff/Admin duyệt đợt hoặc yêu cầu Creator chỉnh sửa")
    public DisputeResponse resolve(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID disputeId,
            @Valid @RequestBody ResolveDisputeRequest request) {
        return podcastRequestService.resolveDispute(userId(jwt), disputeId, request);
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
